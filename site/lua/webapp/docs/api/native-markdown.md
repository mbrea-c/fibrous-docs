The optional Rust Markdown renderer is **off by default**. Source installs,
the normal Nix package and browser/Wasm builds continue to use pure Lua.

```lua
require("fibrous").setup({ native_markdown = true })
```

Call setup before creating mounts. A mount's `native_markdown = false` option
opts out; `true` opts in independently of the configured default.

With Nix, select
`fibrous.packages.${system}.default.override { withRustMarkdown = true; }`,
or `fibrous-rust-markdown`. This builds the locked Cargo module, installs it
inside the plugin and enables its default. No manual library path is required.
`setup({ native_markdown = false })` can turn it off again.

## Scope and fallback

Only a root, scroll-mode `ui.markdown` document uses the native path. Lua still
parses source revisions, executes components and computes syntax highlighting.
Rust retains the styled layout input and reflows on width changes, returning
text, highlight, source and link geometry to the existing host.

Whole-entry provenance anchors (`source_entry`) also stay on Lua to preserve
coarse comments; precise `source` mappings are supported by the native path.
Edits and structural interaction changes return to Lua; the next eligible width
change compiles the new revision. Unsupported styling, controls, general UI
trees, fixed-height views and unavailable/incompatible modules fall back to Lua.
Nested Markdown and viewport-virtualized transcripts are not accelerated by this
renderer. It is not a Rust Markdown parser or a general replacement layout engine.

Retention has a setup and memory cost. Large stable documents with repeated
resizes are the target; short or constantly edited documents can be slower.
Use Fibrous' `test-native`, `bench-native-markdown`,
`bench-native-markdown-term` and `bench-native-markdown-features` Nix apps
to verify behavior, CPU cost and real terminal output. Benchmarks require a
writable `--out` directory and never overwrite the archived results.
