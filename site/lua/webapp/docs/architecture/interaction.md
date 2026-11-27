Interaction lives *outside* the render pipeline. It reads the laid-out tree the
host keeps (`host.tree`, rects in buffer-cell coordinates) and drives the cursor,
the vim cursor *is* the pointer, so whatever interactive node it sits in is
hovered, and no per-commit hit-map bookkeeping is needed.

## hover

The deepest role-carrying node under the cursor takes its hover style. An hl-only
override paints as overlay extmarks in a dedicated namespace, no relayout. A
structural override (one that changes layout) records hover on the host and
relayouts, baking the style into the canvas. Hover is re-evaluated on
`CursorMoved` and after every flush (rects may have moved).

## activation and tab

`<CR>` / `<Space>` / click activate the node under the cursor (button ->
`on_press`, checkbox -> `on_toggle`); `<Tab>` / `<S-Tab>` cycle the cursor through
the target's interactive stops in document order. Subwindows are always entered
explicitly, never by traversal. Each container's own interaction layer cycles
*its* stops.

## widget mode

Every toplevel view starts in Normal mode. Press `<Esc>` to enter widget mode
at the nearest visible control. A cursor already on a control stays in place.
Links, buttons, editable fields, and controls displayed inside a container
are all reachable from the root cursor.

`h`, `j`, `k`, and `l` choose the closest target in the requested direction,
measured in display cells. Vertical moves remember the preferred column. Counts
repeat the move, and the cursor holds at an edge. `<Tab>` keeps its document
order. Other Normal-mode motions run first. For example, `<C-u>` scrolls up
and then snaps within the resulting viewport. If it contains no target, the
cursor stays where the motion landed.

`<Space>` activates a button, checkbox, or link and keeps widget mode active.
`<CR>` leaves widget mode and runs the view's Return binding. A second
`<Esc>` leaves at the current cell. Leaving the view or entering another Vim
mode, including a search with `/`, also ends widget mode. Normal-mode `<Esc>`
inside a focused child window returns to its parent.

## cursor anchor

A relayout (a width resize rewraps every line; an insert shifts the tail) would
otherwise leave the cursor on its old absolute row, now holding different content.
The anchor tracks the entry at a *reference row*, the cursor's entry when the
cursor is on-screen, else the top of the viewport, by key or fiber, and after the
flush restores it, holding its screen row so the view does not jump. A focused
surface also moves the cursor onto its entry; an unfocused one holds only the
view, leaving the cursor to the app's own logic.

## selection guard

Canvas lines fill the window width, and Visual-mode `$` puts the cursor on the
trailing newline, one cell past the last char, off-screen for a full-width line,
which forces a one-cell right scroll that a leftcol pin cannot win. So fibrous
sets `selection=old` (the cursor cannot go past end-of-line) while Visual mode is
active in a canvas buffer. Because `selection` is a *global* option, it is
maintained as an invariant by an idempotent reconciler keyed on the mode *and* the
current buffer, reconciled on both mode and focus / buffer transitions, so it can
never leak into the user's other buffers.
