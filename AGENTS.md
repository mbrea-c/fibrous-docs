# AGENTS.md

Working agreement for changes to **fibrous-docs**, the fibrous playground and
documentation site. The site is itself built in fibrous and runs a real Neovim
compiled to wasm in the browser, so it is also the largest dogfood of the
framework. Every change completes the checklist below before it is considered
done.

## Read DEVELOPMENT.md first

Before writing any code, read [DEVELOPMENT.md](DEVELOPMENT.md). It is the source
of truth for how the site is built, tested, and served, how it consumes fibrous
and nvim-wasm-core, and the one footgun that trips everyone: the difference
between the native test run (uses a local fibrous) and the wasm site build (uses
the pinned one).

## Use red-green TDD, always

The webapp modules under `site/lua/webapp/` have specs (`tests/*_spec.lua`).
Behavior in those modules is developed red-green: write the spec, watch it fail,
make it pass, refactor. A spec that passes before you touch the code is not
testing your change.

> **Snapshot caveat (read first).** `nix run .#test` / `nix flake check` build
> from the flake's own snapshot of the source, which is what is **committed or
> staged**, not your dirty working tree. `git add` your changes before a sign-off
> run.

## 1. Run the docs suite

```sh
nix run .#test                                # the whole suite
nix run .#test -- tests/home_spec.lua         # a single spec, while narrowing
```

`nix flake check` runs the same suite sandboxed against the **pinned** fibrous.
When your change depends on unreleased fibrous behavior, point the suite at your
checkout (working tree, untracked files included):

```sh
FIBROUS_PATH="$HOME/src/nui-reactive" nix run .#test
```

## 2. This repo IS fibrous' documentation, so keep it true

- Prose that explains the framework lives in **Markdown** under
  `site/lua/webapp/docs/**/*.md`, rendered by `ui.markdown`, so a human can edit
  it without touching Lua. Put explanatory content there, not in string
  literals.
- The reference modules (`components_ref.lua`, `api_ref.lua`, the architecture
  pages) must stay accurate to the current fibrous. When you notice anything
  wrong while you are in them (stale example, wrong signature, broken
  cross-reference), fix it if it is in scope and low-risk, otherwise raise it
  with the user. Never silently walk past a docs problem.
- A fibrous change that is API-visible or behavioral is mirrored here in the same
  breath (this is the other half of fibrous' own "update the docs" step).

## 3. Eyeball it

The suite runs in native Neovim; it cannot catch a wasm-only or a visual
regression. Before sign-off, look at the change:

```sh
nix run .#native      # the same site in a real terminal Neovim (fast to iterate)
nix run             # build and serve the real wasm site, open the printed URL
```

`native` also honors `FIBROUS_PATH`, so it is the quickest way to see a fibrous
change through the real homepage.

---

### Notes

- Indentation: **match the file you are editing.** `site/lua/` is not uniform
  (some webapp modules are tabs, some are 2 spaces), and there is no stylua or
  editorconfig, so don't run a bare `stylua` across the tree.
- Two inputs carry the heavy lifting, both pinned in `flake.lock`: `fibrous`
  (source, `flake = false`) and `nvim-wasm-core` (the Neovim-to-wasm engine). To
  build or serve the site against a WIP tree of either, override the input with a
  `path:` ref, which brings untracked files along:
  `nix build .#site --override-input fibrous path:../nui-reactive`.
- The native entry points (`test`, `native`, `bench`) resolve fibrous at runtime
  from `FIBROUS_PATH` and never touch the wasm toolchain, so they are the fast
  loop. The wasm **site build** bakes the pinned inputs; see DEVELOPMENT.md.
