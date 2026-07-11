fibrous is two layers. A host-agnostic **reactive core** (React in miniature:
components, fibers, hooks, reconciliation) decides *what* the UI is; a concrete
**inline host** renders that into Neovim buffers. They meet at one seam, an
injected `HostConfig`, so the core never touches Neovim and is pure, fast Lua
you can unit-test outside an editor.

There is *one* fiber tree for the whole app: it owns all state, hooks and
reconciliation. The inline host then splits it at every `container` boundary
into a **tree of flush targets**. Each target (the root, plus one per
`container`) is what maps to a single layout tree, a single painted canvas, and
a single buffer shown in its own float. So the shape is one fiber tree, N
buffers, not one buffer.

```
ONE fiber tree            state, hooks, reconciliation
     |
     |  split at `container` boundaries
     v
tree of flush targets     root + one per container
     |
     |  each target, parent-first:
     v
build -> layout -> paint -> splice -> its OWN buffer (+ float)
                                          |
                                          v  on_flush(damage)
                              window + interaction layer
                              (mount, subwin, interact)
```

Think of it as two clocks. **Renders** are driven by state: a `use_state` write
re-renders just that component's subtree. The **window and interaction layer**
is driven by flushes and user events: after each commit the host emits *damage*,
and mount / subwin / interact react to it, repositioning floats, re-mirroring,
re-anchoring the cursor, re-evaluating hover. The two never call into each other
directly; the `HostConfig` and the `on_flush` damage are the only boundaries
between them.
