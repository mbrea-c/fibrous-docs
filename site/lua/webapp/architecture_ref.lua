-- Reference data for the Architecture page: how fibrous works internally, stage
-- by stage. Same block vocabulary as api_ref (rendered by architecture_page):
--   { kind = "p",    text = ... }                a paragraph
--   { kind = "h",    text = ... }                a subheading
--   { kind = "code", lines = {...} }             a static code / diagram block
--   { kind = "table", title = ..., rows = {...} } a small table
--
-- Prose deliberately avoids unicode em-dashes and arrows (ASCII "--" and "->").

return {
	{
		id = "overview",
		name = "Overview",
		blocks = {
			{
				kind = "p",
				text = "fibrous is two layers. A host-agnostic REACTIVE CORE (React in miniature: "
					.. "components, fibers, hooks, reconciliation) decides WHAT the UI is; a concrete "
					.. "INLINE HOST renders that into Neovim buffers. They meet at one seam -- an injected "
					.. "HostConfig -- so the core never touches Neovim and is pure, fast Lua you can unit-test "
					.. "outside an editor.",
			},
			{
				kind = "p",
				text = "There is ONE fiber tree for the whole app: it owns all state, hooks and "
					.. "reconciliation. The inline host then splits it at every `container` boundary into a "
					.. "TREE OF FLUSH TARGETS. Each target -- the root, plus one per container -- is what maps "
					.. "to a single layout tree, a single painted canvas, and a single buffer shown in its own "
					.. "float. So the shape is one fiber tree, N buffers, not one buffer.",
			},
			{
				kind = "code",
				lines = {
					"ONE fiber tree            state, hooks, reconciliation",
					"     |",
					"     |  split at `container` boundaries",
					"     v",
					"tree of flush targets     root + one per container",
					"     |",
					"     |  each target, parent-first:",
					"     v",
					"build -> layout -> paint -> splice -> its OWN buffer (+ float)",
					"                                          |",
					"                                          v  on_flush(damage)",
					"                              window + interaction layer",
					"                              (mount, subwin, interact)",
				},
			},
			{
				kind = "p",
				text = "Think of it as two clocks. RENDERS are driven by state: a use_state write "
					.. "re-renders just that component's subtree. The WINDOW AND INTERACTION LAYER is driven "
					.. "by flushes and user events: after each commit the host emits DAMAGE, and mount / "
					.. "subwin / interact react to it -- repositioning floats, re-mirroring, re-anchoring the "
					.. "cursor, re-evaluating hover. The two never call into each other directly; the HostConfig "
					.. "and the on_flush damage are the only boundaries between them.",
			},
		},
	},

	{
		id = "reactive-core",
		name = "Reactive core",
		blocks = {
			{
				kind = "p",
				text = "A component is a plain function (ctx, props) -> node, where a node is a table "
					.. "{ comp, props, children }. There is no class and no lifecycle object -- just functions "
					.. "returning tables, re-invoked when their state changes. Composition is nesting nodes.",
			},
			{ kind = "h", text = "Fibers" },
			{
				kind = "p",
				text = "Every component INSTANCE is a fiber: a persistent record holding the component's "
					.. "hook state and its place in the tree. The fiber tree survives across renders -- that is "
					.. "what lets hook state persist while the returned node tree is thrown away and rebuilt "
					.. "each render.",
			},
			{ kind = "h", text = "Hooks" },
			{
				kind = "p",
				text = "Hooks are positionally-stable per-fiber slots (call them unconditionally, in order, "
					.. "every render). use_state is a value slot whose setter schedules a re-render of THIS "
					.. "fiber only. use_effect runs a side effect after commit and re-runs (with cleanup) when "
					.. "its deps change. use_ref is a mutable box that persists WITHOUT triggering a render.",
			},
			{ kind = "h", text = "Reconciliation" },
			{
				kind = "p",
				text = "After a fiber renders, its returned children are diffed against the previous "
					.. "render's child fibers. A child carrying a `key` is matched by key (so it keeps its "
					.. "fiber -- and hook state -- across insert / remove / reorder); a keyless child falls "
					.. "back to positional matching by index and component type. A matched fiber is reused; an "
					.. "unmatched old one is unmounted (its effects clean up). `memo` bails a function "
					.. "component out of re-rendering while its props are shallow-equal to the last render.",
			},
			{ kind = "h", text = "The HostConfig boundary" },
			{
				kind = "p",
				text = "Host primitives (ui.col, ui.text, ui.container ...) are `{ __host = <tag> }` "
					.. "descriptors -- the leaves where the virtual tree meets the real UI. The reconciler is "
					.. "renderer-agnostic: it never touches a buffer, it just drives the injected HostConfig at "
					.. "create / update / destroy time (React's HostConfig pattern). That is the seam: the "
					.. "reactive suite runs reconciliation against a MOCK host, and the inline host is only one "
					.. "possible implementation of that interface.",
			},
		},
	},

	{
		id = "commit-pipeline",
		name = "Commit pipeline",
		blocks = {
			{
				kind = "p",
				text = "A commit is a pure function of (fiber tree, size). The inline host turns the "
					.. "committed tree into buffer content in four stages -- build, layout, paint, splice -- "
					.. "each MEMOIZED on what actually changed, and emits DAMAGE describing what moved. Every "
					.. "memoized path falls back to a full rebuild when its precondition breaks, so the result "
					.. "is always byte-identical to a fresh paint (the memo specs pin that against fresh-mount "
					.. "oracles).",
			},
			{ kind = "h", text = "build" },
			{
				kind = "p",
				text = "The fiber tree becomes a node tree ready for layout. Untouched fiber subtrees keep "
					.. "their node OBJECTS (fiber._node), tracked by dirtiness ticks, so only the subtrees that "
					.. "actually re-rendered are rebuilt.",
			},
			{ kind = "h", text = "layout" },
			{
				kind = "p",
				text = "A two-pass flexbox over the node tree assigns every node a rect (see the Layout "
					.. "section). Reused nodes skip the measure pass under the same width constraint and skip "
					.. "positioning under the same box.",
			},
			{ kind = "h", text = "paint" },
			{
				kind = "p",
				text = "render.update walks the laid-out tree onto a PERSISTENT canvas: per node, background "
					.. "(hl over the border box), border, then content (text clipped to the content box, "
					.. "children painted over their parent). While the size holds it repaints only the changed "
					.. "subtrees.",
			},
			{ kind = "h", text = "splice" },
			{
				kind = "p",
				text = "The buffer gets the minimal head / tail diff against the previous frame's lines and "
					.. "highlight spans: a set_lines over just the changed run, plus extmark spans. Marks are "
					.. "cleared BEFORE the write, while they are still where they were put. A fully clean frame "
					.. "at the same size skips the write entirely.",
			},
			{ kind = "h", text = "damage" },
			{
				kind = "p",
				text = "splice returns the damage the flush caused: nil when the canvas did not change; "
					.. "otherwise { top, bot }, the 0-based inclusive row range of the new frame that moved "
					.. "(bot < top means a pure deletion at `top`). Damage is the currency the window and "
					.. "interaction layer spend to decide what to re-extract, reposition, or leave alone -- so "
					.. "an animation in one corner does not force every widget to re-sync.",
			},
		},
	},

	{
		id = "layout",
		name = "Layout",
		blocks = {
			{
				kind = "p",
				text = "The layout engine is pure Lua over plain node tables -- no buffers, no windows -- so "
					.. "it unit-tests fast and the host can run it on every commit. It is two passes: a "
					.. "bottom-up MEASURE under a width constraint (each node's intrinsic margin-box size), "
					.. "then a top-down POSITION assigning absolute rects.",
			},
			{ kind = "h", text = "What each node gets" },
			{
				kind = "table",
				title = "annotations",
				rows = {
					{ "size", "{ w, h }", "measured margin-box (intrinsic under the constraint)" },
					{ "rect", "{ x, y, w, h }", "assigned border-box, absolute, 0-indexed" },
					{ "content", "{ x, y, w, h }", "rect inset by border + padding (where children go)" },
					{ "lines", "string[]", "text nodes: final display lines, wrapped to the final width" },
				},
			},
			{ kind = "h", text = "Constraint modes" },
			{
				kind = "p",
				text = "Width always comes from the target's boundary (the window, or a container's laid-out "
					.. "content box). Height picks the mode: a nil height is SCROLL mode -- the root's height "
					.. "is its content height and the buffer scrolls natively under a viewport window; a fixed "
					.. "number is APP mode -- the canvas is exactly the window height. The mount chooses this "
					.. "per target and the host reads it from get_size at every flush.",
			},
		},
	},

	{
		id = "targets-subwindows",
		name = "Subwindows",
		blocks = {
			{
				kind = "p",
				text = "A container / text_input / raw_buffer leaf is laid out inline like anything else -- "
					.. "its border and background even paint in the PARENT buffer -- but its content box is "
					.. "covered by a real float, so the user gets a native buffer. A container's children build "
					.. "into a SEPARATE flush target (its own layout tree, canvas and buffer). Targets flush "
					.. "PARENT-FIRST, so a child's width constraint comes from its parent's freshly laid-out "
					.. "boundary rect; subwin.lua anchors each target's float to its parent's window, "
					.. "recursively.",
			},
			{ kind = "h", text = "The mirror" },
			{
				kind = "p",
				text = "When a sub-buffer's float is hidden, subwin transcribes the buffer's visible slice -- "
					.. "the real characters AND transcribed highlights -- into the parent canvas cells after "
					.. "every flush. That keeps the page honest flat text under a gliding cursor: real "
					.. "characters in yanks and selections, an honest block cursor, complete visual-selection "
					.. "highlights, no guicursor shim. It re-mirrors exactly when a flush's damage reaches the "
					.. "widget's rows.",
			},
			{ kind = "h", text = "render policy" },
			{
				kind = "p",
				text = "props.render chooses WHEN the real float shows versus when the mirror stands in. "
					.. "\"focus\" (the default) hides the float until the widget is focused -- the mirror IS the "
					.. "widget on the flat page, and focusing reveals the live float. \"always\" shows the float "
					.. "at all times (live, down to treesitter fidelity), so the mirror underneath is never "
					.. "seen. A container is always \"always\": the float IS its content, and a mirror could not "
					.. "carry the container's own nested floats.",
			},
			{
				kind = "code",
				lines = {
					"container / text_input / raw_buffer  ->  flush target: own buffer + float",
					"",
					"  render = \"focus\"  (default)   float hidden; MIRROR (cells + hls) in the page;",
					"                                float revealed on focus",
					"  render = \"always\"             float always shown (live, treesitter fidelity)",
					"  container                     forced \"always\" (float is the content; nests floats)",
				},
			},
			{ kind = "h", text = "Occlusion & scroll" },
			{
				kind = "p",
				text = "Because relative=win floats anchor to the window grid, not its scrolled content, the "
					.. "manager subtracts the parent's own scroll offsets itself -- topline AND leftcol (the "
					.. "root is nowrap, so it can scroll sideways) -- and resyncs on WinScrolled. When a "
					.. "widget is partly off-screen it is clipped: PARTIAL, resize the float to its visible "
					.. "rows and re-anchor its own viewport so the right slice shows; FULL, hide the float "
					.. "outright.",
			},
			{ kind = "h", text = "Focus traversal" },
			{
				kind = "p",
				text = "Subwindows never capture the cursor -- the root cursor glides across their region "
					.. "like any other cells. Focus is explicit: ENTER a widget with <CR>, a click, an insert "
					.. "key (i/a/o ...), or a visual key (v/V/<C-v>, which focuses AND starts the selection "
					.. "inside so you select real sub-buffer text); an edit operator (dd/cw/ce/x ...) over an "
					.. "EDITABLE subwindow focuses it and finishes the edit there. LEAVE with an edge motion "
					.. "(hjkl at the buffer's edge steps into the adjacent root cells) or <Esc> in normal mode "
					.. "(pops back to the parent without moving). Across nesting levels the same rules apply "
					.. "one hop at a time.",
			},
		},
	},

	{
		id = "mount-lifecycle",
		name = "Mount & resize",
		blocks = {
			{
				kind = "p",
				text = "A mount ALWAYS puts the host buffer in a ROOT FLOAT. Rendering straight into a real "
					.. "window would let a resize clobber widgets before relayout, and subwindows need resize "
					.. "sync anyway, so the float is the single drawing surface the host owns and the host "
					.. "itself never touches windows.",
			},
			{
				kind = "code",
				lines = {
					"floating   the float IS the app window (editor-relative, centered)",
					"split      a native pane gives geometry; a relative=win float covers it",
					"window     mount over an existing window; pane = geometry, float = draw",
				},
			},
			{
				kind = "p",
				text = "Sizing is INJECTED via opts.get_size and read at every flush, so the mount window is "
					.. "the single source of truth for size. opts.mode picks the constraint: \"fixed\" "
					.. "(default) lays out at the window height for app UIs; \"scroll\" lays out at nil height "
					.. "so the buffer grows with content and the window is a natively-scrolling viewport.",
			},
			{
				kind = "p",
				text = "A resize (WinResized / VimResized) schedules ONE relayout per event-loop tick: "
					.. "re-apply the window geometry, then host.relayout() re-runs layout + paint from the LAST "
					.. "COMMITTED tree without re-rendering any component. Closing the root (or the split pane) "
					.. "tears the whole app down: attachments teardown, effects clean up, buffers and windows "
					.. "close. A fixed-mode root is pinned (topline 1, leftcol 0) so it never scrolls the "
					.. "canvas out from under the widgets.",
			},
		},
	},

	{
		id = "interaction",
		name = "The cursor",
		blocks = {
			{
				kind = "p",
				text = "Interaction lives OUTSIDE the render pipeline. It reads the laid-out tree the host "
					.. "keeps (host.tree, rects in buffer-cell coordinates) and drives the cursor -- the vim "
					.. "cursor IS the pointer, so whatever interactive node it sits in is hovered, and no "
					.. "per-commit hit-map bookkeeping is needed.",
			},
			{ kind = "h", text = "hover" },
			{
				kind = "p",
				text = "The deepest role-carrying node under the cursor takes its hover style. An hl-only "
					.. "override paints as overlay extmarks in a dedicated namespace -- no relayout. A "
					.. "structural override (one that changes layout) records hover on the host and relayouts, "
					.. "baking the style into the canvas. Hover is re-evaluated on CursorMoved and after every "
					.. "flush (rects may have moved).",
			},
			{ kind = "h", text = "activation & tab" },
			{
				kind = "p",
				text = "<CR> / <Space> / click activate the node under the cursor (button -> on_press, "
					.. "checkbox -> on_toggle); <Tab> / <S-Tab> cycle the cursor through the target's "
					.. "interactive stops in document order. Subwindows are always entered explicitly, never "
					.. "by traversal. Each container's own interaction layer cycles ITS stops.",
			},
			{ kind = "h", text = "cursor anchor" },
			{
				kind = "p",
				text = "A relayout (a width resize rewraps every line; an insert shifts the tail) would "
					.. "otherwise leave the cursor on its old absolute row, now holding different content. The "
					.. "anchor tracks the entry at a REFERENCE ROW -- the cursor's entry when the cursor is "
					.. "on-screen, else the top of the viewport -- by key or fiber, and after the flush "
					.. "restores it, holding its screen row so the view does not jump. A focused surface also "
					.. "moves the cursor onto its entry; an unfocused one holds only the view, leaving the "
					.. "cursor to the app's own logic.",
			},
			{ kind = "h", text = "selection guard" },
			{
				kind = "p",
				text = "Canvas lines fill the window width, and Visual-mode $ puts the cursor on the trailing "
					.. "newline -- one cell past the last char, off-screen for a full-width line, which forces "
					.. "a one-cell right scroll that a leftcol pin cannot win. So fibrous sets selection=old "
					.. "(the cursor cannot go past end-of-line) while Visual mode is active in a canvas buffer. "
					.. "Because selection is a GLOBAL option, it is maintained as an invariant by an idempotent "
					.. "reconciler keyed on the mode AND the current buffer, reconciled on both mode and "
					.. "focus / buffer transitions, so it can never leak into the user's other buffers.",
			},
		},
	},

	{
		id = "interactions",
		name = "Trigger graph",
		blocks = {
			{
				kind = "p",
				text = "The pipeline stages are one-directional (build -> layout -> paint -> splice), but "
					.. "SEVERAL things can kick it off, and one flush fans back out into the window and "
					.. "interaction layer. This is the trigger graph -- which stage can set which other in "
					.. "motion.",
			},
			{
				kind = "code",
				lines = {
					"TRIGGER            EFFECT",
					"",
					"use_state.set      render this fiber's subtree -> reconcile -> splice",
					"set_props          re-render the root with new props -> commit",
					"resize             mount.sync -> host.relayout -> commit (no re-render)",
					"structural hover   host.set_state + relayout -> re-enters via on_flush",
					"any flush          per target: subwin.sync + interact.reanchor + update",
					"WinScrolled        subwin re-anchors floats; interact re-captures anchor",
				},
			},
			{ kind = "h", text = "state change -> targeted render" },
			{
				kind = "p",
				text = "use_state.set marks its fiber dirty and schedules a render of THAT subtree only. "
					.. "Reconcile diffs just those children; the commit's memoized stages touch only what "
					.. "changed, so a busy leaf under a stable parent costs a one-line splice, not a full "
					.. "repaint.",
			},
			{ kind = "h", text = "resize -> relayout (no render)" },
			{
				kind = "p",
				text = "A resize never re-runs component functions. mount.sync re-applies geometry and calls "
					.. "host.relayout, which re-runs layout + paint from the last committed fiber tree at the "
					.. "new size. Only geometry changed, so state and effects are untouched.",
			},
			{ kind = "h", text = "structural hover -> relayout cycle" },
			{
				kind = "p",
				text = "A structural hover is the one place interaction reaches back INTO the pipeline: it "
					.. "calls host.set_state and relayout, which re-enters interaction through on_flush. A "
					.. "`syncing` guard breaks that cycle, and a capped settle loop re-evaluates hover against "
					.. "the moved rects (a structural hover can shift layout out from under the cursor).",
			},
			{ kind = "h", text = "every flush -> subwin + interact" },
			{
				kind = "p",
				text = "on_flush(damage) drives the window layer. For each container target it runs "
					.. "subwin.sync (reposition and re-mirror that target's floats, using that target's own "
					.. "damage) then interact.reanchor (put the cursor back on its entry) and interact.update "
					.. "(re-evaluate hover). A clean frame (damage false) does nothing -- which is why an "
					.. "animation in one widget does not churn an idle one elsewhere.",
			},
		},
	},
}
