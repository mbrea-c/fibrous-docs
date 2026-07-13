## Development

fibrous-docs is the fibrous playground and documentation site: a static site that
boots a real Neovim in the browser and mounts a fibrous UI (`site/init.lua`) as
the landing page and interactive docs. It sits on top of two independent
libraries, both pinned as flake inputs:

- **fibrous** (`../nui-reactive`), the UI framework the site is built with.
- **nvim-wasm-core** (`../nvim-wasm-core`), upstream Neovim compiled to
  wasm32-wasi. It is a general-purpose library, agnostic of fibrous; this site is
  just one of its consumers.

The site is produced by `nvim-wasm-core.lib.mkNvimWasmWeb`, with fibrous and
flash riding along as pack/start plugins inside the in-browser Neovim.

### The one footgun: native suite vs wasm build

Two very different things load fibrous, and they load DIFFERENT copies:

- **Native entry points** (`test`, `native`, `bench`) run a normal headless or
  interactive Neovim on your machine and resolve fibrous at runtime from
  `FIBROUS_PATH`. The flake apps default it to the pinned `fibrous` input; set it
  to a checkout to use a working tree (uncommitted and untracked files included):

  ```sh
  FIBROUS_PATH="$HOME/src/nui-reactive" nix run .#test
  FIBROUS_PATH="$HOME/src/nui-reactive" nix run .#native
  ```

- **The wasm site build** (`nix run` to serve, `nix build .#site`) bakes the
  `fibrous` and `nvim-wasm-core` flake inputs from `flake.lock`. `FIBROUS_PATH`
  does nothing here. To build or serve against a WIP tree, override the input
  with a `path:` reference. A `path:` ref copies the directory verbatim, so
  uncommitted AND untracked files come along (a plain or `git+file` ref would
  drop untracked files):

  ```sh
  nix build .#site --override-input fibrous path:../nui-reactive
  nix build .#site --override-input nvim-wasm-core path:../nvim-wasm-core
  ```

So: iterate against your fibrous tree with `nix run .#test` / `.#native` and
`FIBROUS_PATH`; only reach for `--override-input` when you actually need the
change to show up in the built wasm site.

### Requirements

`nix` (the entry points wrap neovim and the local server). `nix develop` gives
you neovim and python3 directly.

### Entry points

| command                 | what it does                                                                                 |
| ----------------------- | -------------------------------------------------------------------------------------------- |
| `nix run`               | build the wasm site and serve it locally (prints the URL). Interactive nvim needs JSPI (recent Firefox/Chromium). |
| `nix run .#test [-- spec]` | the docs suite (`tests/*_spec.lua`) in isolated headless Neovim.                          |
| `nix run .#native`      | the homepage in a REAL terminal Neovim (same `site/init.lua` and webapp modules), to answer "is it slow, or slow in wasm". |
| `nix run .#bench`       | headless benchmark of the real homepage (mount, re-render, relayout, scroll, hover).         |
| `nix build .#site`      | the static webroot (plain files, host anywhere).                                              |
| `nix flake check`       | runs the docs suite sandboxed against the pinned fibrous.                                     |

### Running tests

The suite runs in a **fully isolated** headless Neovim (`-u NONE`). `tests/run.lua`
puts `site/lua` and the resolved fibrous on `package.path` itself, then runs
`tests/**/*_spec.lua` with fibrous' busted-flavored harness. Prefer `nix run
.#test` (staged snapshot); `git add` your edits first.

### Content model

The site is data-driven, and prose is content, not code:

- Explanatory prose lives in Markdown under `site/lua/webapp/docs/**/*.md` and is
  rendered by `ui.markdown` (the same widget the site documents). Edit the `.md`
  file, not a Lua string, when changing wording.
- The reference modules (`site/lua/webapp/components_ref.lua`, `api_ref.lua`, the
  architecture pages) describe the current fibrous surface. `tests/docs_spec.lua`
  and `tests/home_spec.lua` guard their shape.

### Fonts

`packages.webfont` subsets the Iosevka Nerd Font Mono faces (regular, bold,
italic) to the codepoint ranges the site can render and ships them as woff2, so
the grid never depends on the visitor's fonts. Swap the faces there to change the
look.

### Deployment

`.github/workflows/pages.yml` builds `packages.site` and publishes the webroot to
GitHub Pages. The build uses the locked inputs, so a fibrous change reaches the
published site only after fibrous is committed and pushed and this repo's
`flake.lock` is updated (`nix flake update fibrous`).
