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
        in
        {
          default = {
            type = "app";
            program = "${serve}/bin/fibrous-docs-serve";
          };
        }
      );
    };
}
