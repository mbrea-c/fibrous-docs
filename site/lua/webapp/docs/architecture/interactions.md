The pipeline stages are one-directional (build -> layout -> paint -> splice), but
*several* things can kick it off, and one flush fans back out into the window and
interaction layer. This is the trigger graph, which stage can set which other in
motion.

```
TRIGGER            EFFECT

use_state.set      render this fiber's subtree -> reconcile -> splice
set_props          re-render the root with new props -> commit
resize             mount.sync -> host.relayout -> commit (no re-render)
structural hover   host.set_state + relayout -> re-enters via on_flush
any flush          per target: subwin.sync + interact.reanchor + update
WinScrolled        subwin re-anchors floats; interact re-captures anchor
```

## state change to targeted render

`use_state.set` marks its fiber dirty and schedules a render of *that subtree
only*. Reconcile diffs just those children; the commit's memoized stages touch
only what changed, so a busy leaf under a stable parent costs a one-line splice,
not a full repaint.

## resize to relayout (no render)

A resize never re-runs component functions. `mount.sync` re-applies geometry and
calls `host.relayout`, which re-runs layout + paint from the last committed fiber
tree at the new size. Only geometry changed, so state and effects are untouched.

## structural hover to relayout cycle

A structural hover is the one place interaction reaches back *into* the pipeline:
it calls `host.set_state` and relayout, which re-enters interaction through
`on_flush`. A `syncing` guard breaks that cycle, and a capped settle loop
re-evaluates hover against the moved rects (a structural hover can shift layout
out from under the cursor).

## every flush to subwin + interact

`on_flush(damage)` drives the window layer. For each container target it runs
`subwin.sync` (reposition and re-mirror that target's floats, using that target's
own damage) then `interact.reanchor` (put the cursor back on its entry) and
`interact.update` (re-evaluate hover). A clean frame (damage false) does nothing,
which is why an animation in one widget does not churn an idle one elsewhere.
