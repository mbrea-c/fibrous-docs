The layout engine is pure Lua over plain node tables, no buffers, no windows, so
it unit-tests fast and the host can run it on every commit. It is two passes: a
bottom-up *measure* under a width constraint (each node's intrinsic margin-box
size), then a top-down *position* assigning absolute rects.

## What each node gets

| field     | shape            | meaning                                                     |
| :-------- | :--------------- | :--------------------------------------------------------- |
| `size`    | `{ w, h }`       | measured margin-box (intrinsic under the constraint)       |
| `rect`    | `{ x, y, w, h }` | assigned border-box, absolute, 0-indexed                   |
| `content` | `{ x, y, w, h }` | rect inset by border + padding (where children go)         |
| `lines`   | `string[]`       | text nodes: final display lines, wrapped to the final width |

## Constraint modes

Width always comes from the target's boundary (the window, or a container's
laid-out content box). Height picks the mode: a nil height is **scroll** mode,
the root's height is its content height and the buffer scrolls natively under a
viewport window; a fixed number is **app** mode, the canvas is exactly the window
height. The mount chooses this per target and the host reads it from `get_size`
at every flush.

## Text preparation and resize

Host-built text nodes keep flattened text and span metadata across width-only
changes. When wrapping is needed, logical lines and word tokens are scanned
again rather than retaining token tables or cached word widths between reflows.
This keeps the cache limited to text/span preparation and reusable output.

Wrapping is recomputed for a new content width. If a parent's resize leaves the
text width unchanged, for example inside a fixed-width or max-width-clamped
component, ASCII-only wrapped lines and attributed runs are reused. Non-ASCII
wrapped text still goes through normal width measurement. Nowrap lines and
their attributed runs are width-independent and can also be reused; non-ASCII
nowrap text has its display dimensions remeasured without rebuilding those lines.

Preparation belongs to the immutable host node, not a global cache of every
previous width. Changed text, styling, handlers, or source descriptors rebuild
the node and invalidate it. Mutable raw layout trees do not opt into this cache
and are recomputed normally; width-generated fill content is also regenerated.

Span attribution seeks the relevant ordered range and advances between its
boundaries, rather than looking up the covering span at every byte. Highlight,
interaction identity, and original source positions stay attached to each run.

## Inline overflow and fixed footers

A row or column accepts `overflow = "hidden"` to clip its descendants to its
content box. The default is `"visible"`. Nested clips intersect, including
padding and borders. Measurement still uses the full content; clipping changes
what is visible and interactive.

For an always-visible footer, use a fixed-height mount and this structure:

```lua
{
  comp = ui.col,
  children = {
    {
      comp = ui.col,
      props = { grow = 1, overflow = "hidden" },
      children = sidebar_sections,
    },
    {
      comp = ui.button,
      props = { label = "Overview", height = 1, on_press = open_overview },
    },
  },
}
```

The layout reserves the footer height and gives the remaining rows to the body.
It allocates no additional buffer or window. A scrolling popup can expose the
complete content when the inline body is too short.

The position pass propagates an ancestor `clip` rectangle to each descendant.
Paint, damage clearing, hover, mouse/keyboard activation, Tab stops and jump
targets use the same rectangle. Embedded inputs and their mirrors also respect
the clip. Dropdown popups may extend beyond it while their anchor is visible.

This is clipping, not an independent scrolling viewport. Use `ui.container`
when content must scroll in place.
