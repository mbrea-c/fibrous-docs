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
    # flash.nvim rides along as a pack/start plugin so the site can demo
    # jump-to-widget navigation (site/init.lua binds <C-.> to a flash matcher
    # fed by fibrous.targets). Just plugin source, so flake = false.
    flash = {
      url = "github:folke/flash.nvim";
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
      flash,
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
          # The site's bundled font, so the grid never depends on the
          # visitor's system fonts. We ship the Nerd Font Iosevka MONO faces
          # (single-cell advances — the right thing for a grid renderer — and
          # they carry the powerline glyphs). Each face is subset to what the
          # site can actually show — Latin, punctuation, arrows, math, box
          # drawing/blocks/shapes (fibrous borders + the figlet banner),
          # powerline — and recompressed as woff2. Glyphs outside the subset
          # fall back per-glyph to the renderer's monospace stack.
          # (Swap nerd-fonts.iosevka / the faces here to change the face.)
          webfont =
            let
              src = "${pkgs.nerd-fonts.iosevka}/share/fonts/truetype/NerdFonts/Iosevka";
              ranges = "U+0000-00FF,U+0100-017F,U+2000-206F,U+2190-21FF,U+2200-22FF,U+2500-257F,U+2580-259F,U+25A0-25FF,U+E0A0-E0B3";
              faces = [
                "IosevkaNerdFontMono-Regular"
                "IosevkaNerdFontMono-Bold"
                "IosevkaNerdFontMono-Italic"
              ];
            in
            pkgs.runCommandLocal "iosevka-webfont"
              {
                nativeBuildInputs = [
                  (pkgs.python3.withPackages (ps: [
                    ps.fonttools
                    ps.brotli
                  ]))
                ];
              }
              ''
                mkdir -p $out
                ${pkgs.lib.concatMapStrings (face: ''
                  pyftsubset ${src}/${face}.ttf \
                    --unicodes="${ranges}" \
                    --layout-features='*' \
                    --flavor=woff2 \
                    --output-file=$out/${face}.woff2
                '') faces}
              '';

          # The static site: plain files, host anywhere (GitHub Pages).
          # fibrous (with its vendored nui) rides along as a pack/start plugin
          # inside the in-browser Neovim; site/init.lua mounts the landing UI.
          site = nvim-wasm-core.lib.${system}.mkNvimWasmWeb {
            plugins = [
              fibrous
              flash
            ];
            initLua = ./site/init.lua;
            extraLuaDirs = [ ./site/lua ];
            # site/init.lua keys wasm-only behavior off this (forcing the
            # image provider: the web renderer speaks kitty placeholders,
            # but there is no terminal to auto-detect)
            env = {
              NVIM_WASM = "1";
            };
            font = {
              family = "Iosevka Nerd Font Mono";
              px = 17;
              faces = [
                { file = "${webfont}/IosevkaNerdFontMono-Regular.woff2"; }
                {
                  file = "${webfont}/IosevkaNerdFontMono-Bold.woff2";
                  weight = "bold";
                }
                {
                  file = "${webfont}/IosevkaNerdFontMono-Italic.woff2";
                  style = "italic";
                }
              ];
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
              ln -s "${flash}" "$pack/pack/fibrous/start/flash"
              echo "fibrous-docs native (fibrous: $fib); :qa! to exit"
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

          # The docs suite (site/lua modules + the .md content) in a fully
          # isolated headless Neovim. fibrous defaults to the pinned flake input;
          # point FIBROUS_PATH at a checkout to run the docs against a WIP fibrous
          # tree (working tree, uncommitted and untracked files included):
          #   FIBROUS_PATH=/abs/path/to/nui-reactive nix run .#test
          # Pass a spec path to narrow: nix run .#test -- tests/home_spec.lua
          test = pkgs.writeShellApplication {
            name = "fibrous-docs-test";
            runtimeInputs = [ pkgs.neovim ];
            text = ''
              export FIBROUS_PATH="''${FIBROUS_PATH:-${fibrous}}"
              cd ${self}
              exec nvim --headless -u NONE -i NONE -l tests/run.lua "$@"
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${serve}/bin/fibrous-docs-serve";
          };
          test = {
            type = "app";
            program = "${test}/bin/fibrous-docs-test";
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

      # `nix develop` drops you into a shell with the tools the entry points use:
      # neovim (the test host and the native target) and python3 (the local
      # static server behind `nix run`).
      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              pkgs.neovim
              pkgs.python3
            ];
          };
        }
      );

      # `nix flake check` runs the docs suite in the build sandbox, in a fully
      # isolated headless Neovim (no user config, no plugins), against the PINNED
      # fibrous. To gate against a WIP fibrous instead, add
      # `--override-input fibrous path:../nui-reactive`.
      checks = forAllSystems (
        system: pkgs: {
          tests =
            pkgs.runCommandLocal "fibrous-docs-tests"
              {
                nativeBuildInputs = [ pkgs.neovim ];
              }
              ''
                cp -r ${self}/. work && chmod -R +w work && cd work
                export HOME="$TMPDIR"
                export FIBROUS_PATH=${fibrous}
                nvim --headless -u NONE -i NONE -l tests/run.lua
                touch "$out"
              '';
        }
      );
    };
}
