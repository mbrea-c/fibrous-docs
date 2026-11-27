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

Widget mode is on by default. Press `<leader>w` in Normal mode in a focused
Fibrous window to toggle it for every view in the session, including views
opened later. The shortcut works in the root, containers, prompts and
raw-buffer editors. Ordinary windows keep their bindings. An existing buffer-local
mapping for the same chord takes precedence. With Space as leader, Space
alone activates after the mapping timeout and Space followed by `w` toggles.

Use `:FibrousToggleWidgetMode` for the same action from a command or a dotfile
mapping. Set `vim.g.fibrous_widget_mode_key` to another chord to customize
the local binding, or to `false` to use just the command.

A green `WIDGET` label marks the focused canvas, even when it has no controls.
It sits at the right of the nearest available top border. A scrolling list
inside a bordered popup uses the popup's frame. If every enclosing frame is
borderless or already has a title, the label uses the canvas's upper-right
corner. Customize its color with the `FibrousWidgetMode` highlight group.
For statuslines, `vim.w[winid].fibrous_widget_mode` is `true` on the
navigating window and `nil` elsewhere.

`h`, `j`, `k`, and `l` choose the nearest control in the chosen direction.
The cursor lands at the top left of the control's visible content, skipping
button borders and padding. A wrapped link uses the start of its first visible
fragment. Vertical moves remember the column you aimed at, even when a wide
control's label starts farther left. Counts repeat the move, and the cursor
holds at an edge. Other motions run first. For example, `<C-u>`
scrolls up, then snaps within the new viewport if it contains a control.

From a parent, navigation can reach controls visible inside a container.
`<Space>` activates a control in place. `<CR>` runs the view's Return action
and can transfer focus. Inside a focused container, navigation uses its own
scroll position and rendered controls. Editable children keep their usual
editing keys. Normal-mode `<Esc>` returns to the parent. Switching modes or
working in another buffer pauses navigation until focus returns to a Fibrous
canvas in Normal mode.

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
