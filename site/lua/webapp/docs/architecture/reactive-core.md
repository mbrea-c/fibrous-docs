A component is a plain function `(ctx, props) -> node`, where a node is a table
`{ comp, props, children }`. There is no class and no lifecycle object, just
functions returning tables, re-invoked when their state changes. Composition is
nesting nodes.

## Fibers

Every component *instance* is a fiber: a persistent record holding the
component's hook state and its place in the tree. The fiber tree survives across
renders, which is what lets hook state persist while the returned node tree is
thrown away and rebuilt each render.

## Hooks

Hooks are positionally-stable per-fiber slots (call them unconditionally, in
order, every render). `use_state` is a value slot whose setter schedules a
re-render of *this fiber only*. `use_effect` runs a side effect after commit and
re-runs (with cleanup) when its deps change. `use_ref` is a mutable box that
persists *without* triggering a render.

## Reconciliation

After a fiber renders, its returned children are diffed against the previous
render's child fibers. A child carrying a `key` is matched by key (so it keeps
its fiber, and hook state, across insert / remove / reorder); a keyless child
falls back to positional matching by index and component type. A matched fiber
is reused; an unmatched old one is unmounted (its effects clean up). `memo` bails
a function component out of re-rendering while its props are shallow-equal to the
last render.

## The HostConfig boundary

Host primitives (`ui.col`, `ui.text`, `ui.container` ...) are `{ __host = <tag> }`
descriptors, the leaves where the virtual tree meets the real UI. The reconciler
is renderer-agnostic: it never touches a buffer, it just drives the injected
`HostConfig` at create / update / destroy time (React's HostConfig pattern). That
is the seam: the reactive suite runs reconciliation against a *mock* host, and
the inline host is only one possible implementation of that interface.
