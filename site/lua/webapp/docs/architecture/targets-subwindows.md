A `container` / `text_input` / `raw_buffer` leaf is laid out inline like anything
else, its border and background even paint in the *parent* buffer, but its
content box is covered by a real float, so the user gets a native buffer. A
container's children build into a *separate* flush target (its own layout tree,
canvas and buffer). Targets flush *parent-first*, so a child's width constraint
comes from its parent's freshly laid-out boundary rect; `subwin.lua` anchors each
target's float to its parent's window, recursively.

## The mirror

When a sub-buffer's float is hidden, subwin transcribes the buffer's visible
slice, the real characters *and* transcribed highlights, into the parent canvas
cells after every flush. That keeps the page honest flat text under a gliding
cursor: real characters in yanks and selections, an honest block cursor, complete
visual-selection highlights, no `guicursor` shim. It re-mirrors exactly when a
flush's damage reaches the widget's rows.

## render policy

`props.render` chooses *when* the real float shows versus when the mirror stands
in. `"focus"` (the default) hides the float until the widget is focused, the
mirror *is* the widget on the flat page, and focusing reveals the live float.
`"always"` shows the float at all times (live, down to treesitter fidelity), so
the mirror underneath is never seen. A container is always `"always"`: the float
*is* its content, and a mirror could not carry the container's own nested floats.

```
container / text_input / raw_buffer  ->  flush target: own buffer + float

  render = "focus"  (default)   float hidden; MIRROR (cells + hls) in the page;
                                float revealed on focus
  render = "always"             float always shown (live, treesitter fidelity)
  container                     forced "always" (float is the content; nests floats)
```

## Occlusion and scroll

Because `relative=win` floats anchor to the window grid, not its scrolled
content, the manager subtracts the parent's own scroll offsets itself, topline
*and* leftcol (the root is nowrap, so it can scroll sideways), and resyncs on
`WinScrolled`. When a widget is partly off-screen it is clipped: *partial*, resize
the float to its visible rows and re-anchor its own viewport so the right slice
shows; *full*, hide the float outright.

## Focus traversal

Subwindows never capture the cursor, the root cursor glides across their region
like any other cells. Focus is explicit: *enter* a widget with `<CR>`, a click, an
insert key (`i` / `a` / `o` ...), or a visual key (`v` / `V` / `<C-v>`, which
focuses *and* starts the selection inside so you select real sub-buffer text); an
edit operator (`dd` / `cw` / `ce` / `x` ...) over an *editable* subwindow focuses
it and finishes the edit there. *Leave* with an edge motion (`hjkl` at the
buffer's edge steps into the adjacent root cells) or `<Esc>` in normal mode (pops
back to the parent without moving). Across nesting levels the same rules apply one
hop at a time.
