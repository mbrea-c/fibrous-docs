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
content box, children painted over their parent). While the width holds and the
canvas does not shrink, it repaints only the changed subtrees, growing new blank
rows in place when needed. A width change or shrinking canvas starts a full
paint.

Characters occupy a dense row grid. Width metadata is sparse: only wide-character
heads and continuation cells need entries; ordinary cells have implicit width
one. This avoids allocating and filling a second dense grid on every repaint.
ASCII painting and blanking bypass per-cell width access on rows with no wide
heads or continuations. It does not virtualize offscreen content or change the
buffer's text, highlights, or native scrolling.

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

## Measuring resize work

In a Fibrous source checkout, `nix run .#bench-resize-profile` compares ordinary
warm resizing with a benchmark-only phase breakdown. It separates layout
(including wrapping and source attribution), canvas allocation, painting,
text/highlight extraction, buffer text and highlight updates, and source updates.
The source phase is not the cost of all provenance handling: wrapped-run
attribution belongs to layout, and unrequested lazy source queries do not run.
The benchmark checks that profiling preserves output and buffer-write counts.
Normal UI rendering has no timers.

The phase means are exclusive: nested work is counted once, and uninstrumented
work is reported as `other`. The slowest frame has its own breakdown; individual
phase p95s cannot be added together. Instrumentation can disturb timings, so use
the unprofiled run to judge performance.

`BENCH_PROFILE=1 nix run .#bench-resize-term` adds phase measurements and synchronous
Neovim redraw timing in a real terminal session. Neither benchmark measures the
terminal emulator's painting time. See Fibrous' `DEVELOPMENT.md` for repeated-run
ordering and measurement caveats.
