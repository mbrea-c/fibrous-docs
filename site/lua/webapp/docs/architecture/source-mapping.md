# Source mapping

Buffer rows are a rendering artifact. Reflow, clipping, Markdown concealment,
and windowing can all move or remove them without changing the document.
Persistent annotations therefore need application-owned document IDs and source
ranges, not long-lived extmarks in the host buffer.

When a Markdown component has a `source` descriptor, the block and inline
parsers propagate original byte positions through their transformations. The
document renderer attaches these maps to text spans. Rich-text flattening and
wrapping retain them on the resulting line runs alongside styling and interaction
metadata. The normal unmapped parser and render path remains unchanged.

After paint, `fibrous.sources` registers the current laid-out host tree. Selection
resolution walks painted text clusters, checks clipping and actual buffer text,
and translates buffer coordinates into logical byte ranges. Projection walks
the same metadata in the opposite direction. It never guesses between repeated
copies of a quote. Application-owned raw buffers can register identity mapping
separately.

Rendered-tree queries filter unselected rows, unrelated source IDs, and
unrequested source bytes before reading and checking buffer text. They still
validate complete visible clusters against the actual paint. Whole-entry lookup
uses the enclosing box geometry instead of walking the entry's text.

Contiguous identity maps inside the Markdown parser use private offset/length
ranges, including in-bounds slices. Maps published on the document AST remain
ordinary byte arrays; neither descriptors nor the public projection API change.

Generated elements are not automatically source text. A surrounding
`source_entry` descriptor supplies an explicitly coarse entry fallback when an
exact mapping is unavailable, including mixed selections containing rendered
math. A hidden or unmounted entry simply has no current projection.

Applications keep anchors, captured quotes, conversation identity, revisions,
and authorization. They validate anchors against current canonical content,
then subscribe to source updates to repaint their own overlays. Fibrous neither
persists annotations nor silently reattaches them to similar-looking content.
See **API / Source mapping** for descriptors, coordinate conventions, and calls.
