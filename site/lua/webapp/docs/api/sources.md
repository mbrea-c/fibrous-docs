# Logical document sources

Source mapping lets an application attach comments to logical content instead of
ephemeral buffer rows. It is opt-in: documents without `source` keep their normal
parser shapes and rendering behavior. Applications own IDs, revisions, storage,
authorization, and whether changed content still matches an anchor.

## Attach provenance

`ui.text`, `ui.label`, and `ui.paragraph` accept a `source` descriptor:

```lua
local document = { id = "message-42/text", text = "original text", data = { entry_id = "message-42" } }
return { comp = ui.paragraph, props = { text = document.text, source = document } }
```

The descriptor has an application-defined stable `id`, original `text` (a string
or getter), optional opaque `data`, and optional zero-based byte `offset` for a
fragment of a larger document. A rich-text span may have its own `source`.
An optional `map` maps each one-based displayed byte index to a zero-based
original byte offset; `offset` is added to mapped positions too.

`ui.markdown` accepts the same descriptor and tracks original positions through
Markdown parsing. It maps prose, headings, emphasis, links, lists, blockquotes,
tables, escapes, inline code, fenced code, UTF-8, and CRLF normalization.
It caches the mapped AST across resize. Direct parser consumers use
`markdown.parse(text, { source = true })` and pass `source` to
`fibrous.doc.render.render(doc, opts)`. Public AST source maps remain ordinary
byte arrays; the parser's compact intermediate representation is private.

For a coarse fallback, put `source_entry = descriptor` on an enclosing node.
Generated content such as rendered math has no exact byte mapping. A selection
containing unmapped non-whitespace text falls back to that whole entry, rather
than silently dropping the unsupported portion. Synthetic padding and gutters
are not themselves exact source text.

## Resolve selections

```lua
local sources = require("fibrous.sources")
local spans = sources.resolve(bufnr, {
  lnum = 12, end_lnum = 13, col = 4, end_col = 18,
})
```

Selection rows and optional byte columns are **one-based and inclusive**, like
Neovim visual marks. The first column limits only the first row; the ending
column limits only the last. Each result contains `source`, `start_byte`,
`end_byte`, the displayed `quote`, and `precision` (`"exact"` or `"entry"`).
Logical source offsets are **zero-based UTF-8 bytes**, with an exclusive end.
An entry fallback intentionally makes no exact-range claim.

Only fully painted, unclipped text clusters are resolved. Selections can return
multiple source spans. Repeated words and hidden Markdown destinations are
resolved from parser provenance, not by searching the original text for a quote.

## Reproject overlays

```lua
local locations = sources.project("message-42/text", start_byte, end_byte)
local unsubscribe = sources.subscribe(function(bufnr)
  -- Clear and replace application-owned extmarks from the current projection.
end)
```

Projection locations contain `bufnr`, zero-based `row` and `start_col`, and
exclusive `end_col`. They describe the current rendered buffer, not whether a
native viewport is scrolled onto that row. Unmounted or windowed-out content has
no locations. `sources.entry_locations(entry_id)` locates fallback entry headers;
it matches the application's `source.data.entry_id`.

For an application-owned raw buffer, call `sources.raw(bufnr, descriptor)` after
updating its content; mapping is identity over the current text. Call
`sources.clear(bufnr)` when detaching. Buffer wipeout clears registrations
automatically. Fibrous updates ordinary host/container registrations after
painting. `sources.owns(bufnr)` reports whether a registration exists.

Fibrous does not retain comment objects or fuzzy-reattach quotes. A projection is
disposable. Keep the logical anchor and original quote in your application,
validate it against the current document, and reproject after source updates.
