A scrolling column can opt into viewport rendering. Create one
`fibrous.inline.visibility` model per target, then build only the inclusive
range returned by `model:use_range(ctx, count, revision)`.

```lua
local model = require("fibrous.inline.visibility").new({
  estimate = 3, gap = 1, tail = true,
})
-- Inside a component:
local first, last = model:use_range(ctx, #items, filter_revision)
local children, sequences = {}, {}
for i = first, last do
  if visible(items[i]) then
    children[#children + 1] = render_item(items[i])
    sequences[#sequences + 1] = i
  end
end
return {
  comp = ui.col,
  props = {
    gap = 1, content_visibility = "auto",
    visibility = model, sequences = sequences,
  },
  children = children,
}
```

Bind the model to its container window with `model:bind(winid)` in the creation
callback. Call `model:close()` on teardown. The column must be the root of a
scroll target, optionally inside the target's single unstyled wrapper column.

The owner provides stable one-based canonical indices and a revision that changes
when filtering changes. Missing children in the requested range are zero-height.
`estimate` is the estimated content height, excluding `gap`; both must agree
with the actual list. `model:reveal(index)` materializes an entry before source
navigation. The default overscan is two viewport heights on each side.

Only mounted entries have fibers, layout, cell grids and source geometry.
Unvisited heights are estimates, and native buffer rows for offscreen content
are blank. Native search and multi-page yanks therefore cannot read the whole
document; use canonical application data for whole-history operations. A single
large entry is still rendered in full. Reflow preserves the entry and row offset,
not the exact word inside rewrapped prose.

This is independent of the optional retained Rust Markdown renderer.
