A mount *always* puts the host buffer in a **root float**. Rendering straight
into a real window would let a resize clobber widgets before relayout, and
subwindows need resize sync anyway, so the float is the single drawing surface
the host owns and the host itself never touches windows.

```
floating   the float IS the app window (editor-relative, centered)
split      a native pane gives geometry; a relative=win float covers it
window     mount over an existing window; pane = geometry, float = draw
```

Sizing is *injected* via `opts.get_size` and read at every flush, so the mount
window is the single source of truth for size. `opts.mode` picks the constraint:
`"fixed"` (default) lays out at the window height for app UIs; `"scroll"` lays out
at nil height so the buffer grows with content and the window is a
natively-scrolling viewport.

A resize (`WinResized` / `VimResized`) schedules *one* relayout per event-loop
tick: re-apply the window geometry, then `host.relayout()` re-runs layout + paint
from the *last committed* tree without re-rendering any component. Closing the
root (or the split pane) tears the whole app down: attachments teardown, effects
clean up, buffers and windows close. A fixed-mode root is pinned (topline 1,
leftcol 0) so it never scrolls the canvas out from under the widgets.
