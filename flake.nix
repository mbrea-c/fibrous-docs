{
  description = "fibrous-docs — the fibrous playground: real Neovim + fibrous running client-side in the browser";

  inputs = {
    # TODO(publish): once these repos live on GitHub, switch to
    #   nvim-wasm-core.url = "github:<owner>/nvim-wasm-core";
    #   fibrous.url = "github:<owner>/fibrous.nvim";
    # so CI (GitHub Pages workflow) can fetch them. Absolute path inputs are
    # local-development only (relative ones cannot escape the flake root).
    nvim-wasm-core.url = "github:mbrea-c/nvim-wasm-core";
    fibrous = {
      url = "github:mbrea-c/fibrous.nvim";
      flake = false;
    };
    nixpkgs.follows = "nvim-wasm-core/nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nvim-wasm-core,
      fibrous,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f system (import nixpkgs { inherit system; }));
    in
    {
      packages = forAllSystems (
        system: pkgs: rec {
          # The static site: plain files, host anywhere (GitHub Pages).
          # fibrous (with its vendored nui) rides along as a pack/start plugin
          # inside the in-browser Neovim; site/init.lua mounts the landing UI.
          site = nvim-wasm-core.lib.${system}.mkNvimWasmWeb {
            plugins = [ fibrous ];
            initLua = ./site/init.lua;
            extraLuaDirs = [ ./site/lua ];
            font = {
              family = "monospace";
              px = 17;
            };
          };
          default = site;
        }
      );

      # `nix run` — serve the site locally.
      # `nix run .#native` — the same homepage in a real terminal Neovim.
      # `nix run .#bench`  — headless benchmark of the homepage.
      apps = forAllSystems (
        system: pkgs:
        let
          serve = pkgs.writeShellApplication {
            name = "fibrous-docs-serve";
            runtimeInputs = [ pkgs.python3 ];
            text = ''
              site=${self.packages.${system}.site}
              port="''${PORT:-8410}"
              echo "fibrous-docs"
              echo "  site: $site"
              echo "  url:  http://127.0.0.1:$port/"
              echo "Interactive nvim needs JSPI: Chromium 137+ / Firefox 152+ (151: about:config javascript.options.wasm_js_promise_integration)."
              # no-store: nix store mtimes are 1970 and heuristic caching would
              # pin a stale copy for years.
              python3 - "$site" "$port" <<'PY'
              import functools, http.server, sys
              class Handler(http.server.SimpleHTTPRequestHandler):
                  def end_headers(self):
                      self.send_header("Cache-Control", "no-store")
                      super().end_headers()
              http.server.test(
                  HandlerClass=functools.partial(Handler, directory=sys.argv[1]),
                  port=int(sys.argv[2]),
                  bind="127.0.0.1",
              )
              PY
            '';
          };

          # The homepage in NATIVE Neovim — same site/init.lua, same webapp
          # modules, fibrous as a pack/start plugin — so "is it slow, or is
          # it slow *in wasm*" has a one-command answer. fibrous defaults to
          # the flake input (the pinned rev the built site ships); export
          # FIBROUS_PATH=/path/to/checkout to debug a local tree without a
          # lock bump.
          native = pkgs.writeShellApplication {
            name = "fibrous-docs-native";
            runtimeInputs = [ pkgs.neovim ];
            text = ''
              fib="''${FIBROUS_PATH:-${fibrous}}"
              docs=${self}
              pack="$(mktemp -d)"
              trap 'rm -rf "$pack"' EXIT
              mkdir -p "$pack/pack/fibrous/start"
              ln -s "$fib" "$pack/pack/fibrous/start/fibrous"
              echo "fibrous-docs native (fibrous: $fib) — :qa! to exit"
              nvim -i NONE \
                --cmd "set packpath^=$pack" \
                --cmd "lua package.path = '$docs/site/lua/?.lua;$docs/site/lua/?/init.lua;' .. package.path" \
                -u "$docs/site/init.lua"
            '';
          };

          # Headless benchmark of the real homepage (tests/bench.lua): mount,
          # re-render, relayout, scroll resync, hover — printed ms stats.
          # Same FIBROUS_PATH override; BENCH_COLS/BENCH_LINES/BENCH_N knobs.
          bench = pkgs.writeShellApplication {
            name = "fibrous-docs-bench";
            runtimeInputs = [ pkgs.neovim ];
            text = ''
              export DOCS_ROOT=${self}
              export FIBROUS_PATH="''${FIBROUS_PATH:-${fibrous}}"
              exec nvim --headless -u NONE -i NONE -l ${self}/tests/bench.lua "$@"
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${serve}/bin/fibrous-docs-serve";
          };
          native = {
            type = "app";
            program = "${native}/bin/fibrous-docs-native";
          };
          bench = {
            type = "app";
            program = "${bench}/bin/fibrous-docs-bench";
          };
        }
      );
    };
}
