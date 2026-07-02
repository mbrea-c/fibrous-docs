# fibrous-docs

The [fibrous.nvim](../nui-reactive) playground site: **real, upstream Neovim —
compiled to WebAssembly — running entirely client-side in the browser**, with
fibrous loaded as a plugin and a fibrous-rendered landing UI. Tier 3 of the
fibrous playground stack, built on
[nvim-wasm-core](../nvim-wasm-core)'s `mkNvimWasmWeb` API.

Everything is static files: no server-side compute, no SharedArrayBuffer, no
COOP/COEP headers — it hosts on GitHub Pages as-is.

## Run locally

```sh
nix run        # serve at http://127.0.0.1:8410/
```

Interactive editing needs JSPI: Chromium 137+ or Firefox 152+ out of the box
(Firefox 139–151: set `javascript.options.wasm_js_promise_integration` in
`about:config` and fully restart). Browsers without JSPI get an explanation
page instead.

Inside the editor: the welcome panel is a fibrous component; `:Examples`
lists the demos (`:Example counter`, `hello`, `form`, `sidebar`, `panel`).

## Build

```sh
nix build .#site   # → ./result, the complete static webroot
```

The site is assembled by `mkNvimWasmWeb` in `flake.nix`: the fibrous repo
(with its vendored nui) ships as a `pack/*/start` plugin inside the in-browser
Neovim's XDG tree, and [`site/init.lua`](site/init.lua) becomes its
`init.lua`.

## Deploy (GitHub Pages)

`.github/workflows/pages.yml` builds with Nix and publishes via
`actions/deploy-pages` on every push to `main` (repo setting: Pages → Source →
"GitHub Actions").

**Before CI can build**: the flake inputs currently point at sibling checkouts
(`path:../nvim-wasm-core`, `path:../nui-reactive`) for local development.
Publish those repos and switch the inputs to `github:` URLs (see the TODO in
`flake.nix`).
