A commit is a pure function of `(fiber tree, size)`. The inline host turns the
committed tree into buffer content in four stages, **build**, **layout**,
**paint**, **splice**, each *memoized* on what actually changed, and emits
*damage* describing what moved. Every memoized path falls back to a full rebuild
when its precondition breaks, so the result is always byte-identical to a fresh
paint (the memo specs pin that against fresh-mount oracles).

## build

The fiber tree becomes a node tree ready for layout. Untouched fiber subtrees
keep their node *objects* (`fiber._node`), tracked by dirtiness ticks, so only
the subtrees that actually re-rendered are rebuilt.

## layout

A two-pass flexbox over the node tree assigns every node a rect (see the Layout
section). Reused nodes skip the measure pass under the same width constraint and
skip positioning under the same box.

## paint

`render.update` walks the laid-out tree onto a *persistent* canvas: per node,
background (hl over the border box), border, then content (text clipped to the
content box, children painted over their parent). While the size holds it
repaints only the changed subtrees.

## splice

The buffer gets the minimal head / tail diff against the previous frame's lines
and highlight spans: a `set_lines` over just the changed run, plus extmark spans.
Marks are cleared *before* the write, while they are still where they were put. A
fully clean frame at the same size skips the write entirely.

## damage

`splice` returns the damage the flush caused: nil when the canvas did not change;
otherwise `{ top, bot }`, the 0-based inclusive row range of the new frame that
moved (`bot < top` means a pure deletion at `top`). Damage is the currency the
window and interaction layer spend to decide what to re-extract, reposition, or
leave alone, so an animation in one corner does not force every widget to
re-sync.
