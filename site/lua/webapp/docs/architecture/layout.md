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
