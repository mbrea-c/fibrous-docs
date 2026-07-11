-- Reference data for the API page: the mount entry points, the hooks, the
-- style/layout vocabulary and the component model. Rendered by api_page as
-- master/detail (webapp.nav side-nav + a block renderer). Content is prose,
-- props/opts tables and STATIC code snippets — mount APIs can't run live inside
-- the page, so there are no editors here.
--
-- Each section is { id, name, blocks }. A block is one of:
--   { kind = "p",     text = ... }                 a paragraph
--   { kind = "h",     text = ... }                 a subheading
--   { kind = "table", title = ..., rows = {...} }  a props/opts table
--   { kind = "code",  lines = {...} }              a static code block

local components_ref = require("webapp.components_ref")

return {
	{
		id = "mounting",
		name = "Mounting",
		blocks = {
			{
				kind = "p",
				text = "A fibrous app is a component mounted onto a window. Every mount target puts the "
					.. "host buffer in a ROOT FLOAT (so a resize can never clobber widgets before "
					.. "relayout). opts.mode picks the constraint: \"fixed\" (default) lays out at the "
					.. "window height for app-style UIs; \"scroll\" grows the buffer with content and "
					.. "makes the window a natively-scrolling viewport for website-style UIs — this "
					.. "docs site runs in \"scroll\".",
			},
			{ kind = "h", text = "mount.window(component, props, opts)" },
			{
				kind = "p",
				text = "Mount over an existing window (opts.winid) — the pane provides geometry, a float "
					.. "does the drawing. The workhorse for embedding an app in your own layout.",
			},
			{
				kind = "table",
				title = "opts",
				rows = {
					{ "winid", "integer", "the window to mount on (0 = current)" },
					{ "mode", "string", "\"fixed\" (default) | \"scroll\"" },
					{ "mouse", "table|false", "{ activate, follow }; false disables mouse maps" },
					{ "keys", "string[]", "normal-mode keys routed to the hovered component's on_key" },
					{ "anchor", "boolean", "keep your place across relayout (cursor when focused, view when not); default true (false opts out)" },
					{ "zindex", "integer", "root float z-index; default 10 (below nvim's float default)" },
				},
			},
			{ kind = "h", text = "mount.floating(component, props, opts)" },
			{
				kind = "p",
				text = "Mount as a standalone editor-relative float — the float IS the app window. "
					.. "Geometry defaults to 60% of the editor, centered, and tracks resizes.",
			},
			{
				kind = "table",
				title = "opts",
				rows = {
					{ "width/height", "integer", "size; default 60% of columns/lines" },
					{ "row/col", "integer", "position; default centered" },
					{ "mode", "string", "\"fixed\" (default) | \"scroll\"" },
					{ "mouse", "table|false", "{ activate, follow }; false disables mouse maps" },
					{ "border", "string|string[]", "nvim_open_win border for the root float" },
					{ "backdrop", "bool|integer", "dim the editor behind the app (modal effect)" },
					{ "anchor", "boolean", "keep your place across relayout (cursor when focused, view when not); default true (false opts out)" },
					{ "zindex", "integer", "root float z-index; default 50" },
				},
			},
			{ kind = "h", text = "mount.split(component, props, opts)" },
			{
				kind = "p",
				text = "Open a native split pane and mount over it; closing the pane tears the app down. "
					.. "opts.split = { direction, position, size } picks the pane, plus the shared "
					.. "mode/mouse/keys/anchor/zindex.",
			},
			{
				kind = "h",
				text = "The handle",
			},
			{
				kind = "table",
				title = "returns",
				rows = {
					{ "winid", "integer", "the root float" },
					{ "bufnr", "integer", "the host buffer it displays" },
					{ "set_props", "fun(props)", "re-render the root with new props" },
					{ "relayout", "fun()", "resync geometry + re-flush at the current size" },
					{ "focus", "fun()", "focus the app window" },
					{ "unmount", "fun()", "tear the app + its windows/buffers down" },
				},
			},
			{
				kind = "code",
				lines = {
					'local mount = require("fibrous.inline.mount")',
					"",
					"local handle = mount.window(App, {}, { mode = \"scroll\" })",
					"handle.focus()",
					"-- later:",
					"handle.unmount()",
				},
			},
		},
	},

	{
		id = "hooks",
		name = "Hooks",
		blocks = {
			{
				kind = "p",
				text = "Components are functions of state. The ctx passed to a component gives it "
					.. "persistent, positionally-stable slots — the same contract as React's hooks: "
					.. "call them unconditionally, in the same order, every render.",
			},
			{ kind = "h", text = "ctx.use_state(initial) -> { get, set }" },
			{
				kind = "p",
				text = "A persistent value slot. set(v) schedules a re-render of THIS component only; "
					.. "the reconciler diffs the returned tree and patches just the cells that changed.",
			},
			{
				kind = "code",
				lines = {
					"local count = ctx.use_state(0)",
					"-- read:  count.get()",
					"-- write: count.set(count.get() + 1)",
				},
			},
			{ kind = "h", text = "ctx.use_effect(fn, deps) " },
			{
				kind = "p",
				text = "Run a side effect after commit; fn may return a cleanup. It re-runs when a value "
					.. "in the deps array changes, and the cleanup runs on unmount (or before a re-run) "
					.. "— so timers, autocmds and keymaps armed in an effect die with the component.",
			},
			{
				kind = "code",
				lines = {
					"ctx.use_effect(function()",
					"  local t = vim.uv.new_timer()",
					"  t:start(1000, 1000, vim.schedule_wrap(tick))",
					"  return function() t:stop(); t:close() end",
					"end, {})",
				},
			},
			{ kind = "h", text = "ctx.use_ref(initial) -> { current }" },
			{
				kind = "p",
				text = "A mutable box that persists across renders WITHOUT triggering one — for holding "
					.. "onto buffers, handles or any imperative value between renders.",
			},
		},
	},

	{
		id = "styling",
		name = "Styling",
		blocks = {
			{
				kind = "p",
				text = "All styling lives in props.style, in ONE vocabulary. text_hl colours the text, hl "
					.. "fills the node rect, and _hover / _focus override any key while that state holds "
					.. "(hover rides the same hit-map that routes clicks and <CR>). Borders come from a "
					.. "theme (rounded, double, single) and restyle per instance.",
			},
			{ kind = "table", title = "style props", rows = components_ref.STYLE_PROPS },
			{
				kind = "p",
				text = "A border can be a theme name for the quick case, or a table to customise it — "
					.. "per-side toggles, a recolour, and an EMBEDDED TITLE painted into the edge. The "
					.. "title is a bare string, or { text, align = left|center|right, pos = top|bottom, hl }.",
			},
			{
				kind = "code",
				lines = {
					"-- a titled panel: title centered on the top edge",
					"{ comp = ui.col, props = { style = {",
					'  border = { "rounded", title = { text = " Details ", align = "center" } },',
					"  padding = { x = 1 },",
					"} }, children = { ... } }",
					"",
					'-- shorthand: a bare string titles the top-left',
					'-- style = { border = { "single", title = "Log" } }',
				},
			},
			{
				kind = "p",
				text = "Layout is a flexbox pass over the component tree. Every node — containers and "
					.. "leaves alike — accepts these; gap only applies to containers (col/row/container).",
			},
			{ kind = "table", title = "layout props", rows = components_ref.LAYOUT_PROPS },
		},
	},

	{
		id = "interaction",
		name = "Interaction",
		blocks = {
			{
				kind = "p",
				text = "The whole app is ONE unmodifiable buffer; interactivity rides the cursor. A "
					.. "node opts in with node-level props (NOT under `style`). `role` marks it a button "
					.. "or checkbox: the deepest role-carrying node under the cursor takes the hover cue, "
					.. "and <CR>/<Space>/click activates it. button/checkbox/text_input/raw_buffer set these "
					.. "for you — reach for the raw props to make any node interactive.",
			},
			{ kind = "table", title = "props", rows = components_ref.INTERACTION_PROPS },
			{ kind = "h", text = "on_key: app-defined keys" },
			{
				kind = "p",
				text = "on_key routes a normal-mode key to whatever component sits under the cursor — a "
					.. "generic hook for component-specific keybindings (no role required, so it draws no "
					.. "hover). Each key MUST be declared in the mount `keys` opt so the host maps it; the "
					.. "handler receives the cursor's column within the node, like on_press.",
			},
			{
				kind = "code",
				lines = {
					"-- mount with the keys the app wants routed:",
					'mount.window(App, {}, { keys = { "x", "<Tab>" } })',
					"",
					"-- a component handles them when the cursor is on it:",
					"{ comp = ui.label, props = { text = row.title, on_key = {",
					"  x = function() delete(row.id) end,",
					'  ["<Tab>"] = function() cycle(row.id) end,',
					"} } }",
				},
			},
			{
				kind = "p",
				text = "Focus follows the cursor too: gliding hjkl over an embedded editor (text_input / "
					.. "raw_buffer) passes straight over it; <CR>, i, a visual key (v/V/<C-v>), or a click "
					.. "ENTERS it (an edit operator like dd/cw over an editable one enters AND edits), and an "
					.. "edge motion or <Esc> steps back out. _focus style keys apply while a node or its "
					.. "subwindow holds focus. See the Home page's \"Two focus policies\" example.",
			},
			{ kind = "h", text = "cursor anchor" },
			{
				kind = "p",
				text = "A relayout — a width resize rewraps every line, an insert shifts the tail — would "
					.. "otherwise leave the view on its old absolute rows, now holding different content "
					.. "(\"swimming\"). fibrous instead keeps the reader's place across the relayout: it tracks "
					.. "the entry at a REFERENCE ROW — the cursor's entry when the cursor is on-screen, else "
					.. "the top of the viewport — by `key` (reorder-stable) or, for keyless UIs, by the node's "
					.. "fiber (resize-stable), and holds its screen row so nothing jumps. A FOCUSED surface "
					.. "also moves the cursor back onto its entry; an UNFOCUSED one holds only the view, leaving "
					.. "the cursor to the app's own logic (e.g. a follow-to-bottom). It follows your own cursor "
					.. "moves AND scrolling, so it only ever corrects a relayout — it never fights the wheel. On "
					.. "by default; pass `anchor = false` to the mount (or a container) to opt out.",
			},
			{ kind = "h", text = "fibrous.targets: jump-to-widget" },
			{
				kind = "p",
				text = "`require(\"fibrous.targets\").targets(opts?)` returns every interactive element "
					.. "currently ON SCREEN, across ALL live mounts and their windows/floats, as pure "
					.. "geometry. Because the cursor IS the pointer, \"jump to a widget\" is just \"move the "
					.. "cursor to a cell\", so this composes directly with flash.nvim (or any label-jump "
					.. "plugin): each entry is shaped like a flash match. Every mount auto-registers on "
					.. "creation and deregisters on teardown; elements resolve to whichever window shows them "
					.. "now — a live container float in its own coords, an unfocused (mirrored) input as a "
					.. "parent cell — and off-screen ones are filtered out.",
			},
			{
				kind = "p",
				text = "Because the registry is GLOBAL, this is a keymap the USER sets once, not something "
					.. "an app wires up: bind the recipe below to a global key and EVERY fibrous UI — this "
					.. "one, weave, any third-party plugin — becomes flash-navigable for free, with no "
					.. "cooperation from the app. Apps just render widgets; navigation comes along for the ride.",
			},
			{
				kind = "table",
				title = "each target",
				rows = {
					{ "winid", "integer", "the window currently displaying the element" },
					{ "pos", "{ row, col }", "the widget's top-left: 1-based row, 0-based byte col (nvim/flash convention)" },
					{ "end_pos", "{ row, col }", "same row as pos, at the widget's right edge (a single-line span; flash is line-oriented, so a match straddling rows mislabels)" },
					{ "kind", "string", "\"button\" | \"checkbox\" | \"text_input\" | \"raw_buffer\" | …" },
					{ "role", "string?", "the fibrous role, when the element has one" },
				},
			},
			{
				kind = "p",
				text = "`opts` filters: `winid` (scope to one window — flash's matcher is per-window), "
					.. "`kinds` (a list of kinds to keep), and `predicate` (an arbitrary fun(t) -> boolean).",
			},
			{
				kind = "code",
				lines = {
					"-- flash.nvim recipe: label + jump to every fibrous widget on screen.",
					"-- wrap=true labels matches BEFORE the cursor too (else forward-only in",
					"-- the current window); let flash's default labeler assign labels (don't",
					"-- set them here, or they collide across windows).",
					"require(\"flash\").jump({",
					"  search  = { multi_window = true, wrap = true, incremental = false, max_length = 0 },",
					"  matcher = function(win)",
					"    local Pos = require(\"flash.search.pos\")",
					"    local out = {}",
					"    for _, t in ipairs(require(\"fibrous.targets\").targets({ winid = win })) do",
					"      out[#out + 1] = { win = win, pos = Pos(t.pos), end_pos = Pos(t.end_pos) }",
					"    end",
					"    return out",
					"  end,",
					"})",
					"-- flash jumps the cursor to the chosen widget; <CR> then activates it",
					"-- through the ordinary interaction layer (hover follows the cursor).",
					"-- NB bind this to a <C-...> key, NOT a <Space>-leader chord: fibrous",
					"-- maps <Space>/<CR>/<Tab>/i/a/d/c/v… buffer-locally, so a <Space> leader",
					"-- is swallowed inside a fibrous window.",
				},
			},
		},
	},

	{
		id = "model",
		name = "Component model",
		blocks = {
			{
				kind = "p",
				text = "A component is a plain function (ctx, props) -> node. A node is a table "
					.. "{ comp, props, children }: comp is either a builtin host (ui.col, ui.text…) or "
					.. "another function component; children nest more nodes. There is no class, no "
					.. "lifecycle object — just functions returning tables, re-invoked on state change.",
			},
			{
				kind = "code",
				lines = {
					'local ui = require("fibrous.inline.components")',
					"",
					"local function Greeting(ctx, props)",
					"  return {",
					"    comp = ui.label,",
					'    props = { text = "hi, " .. props.name },',
					"  }",
					"end",
					"",
					"-- use it: { comp = Greeting, props = { name = \"fibrous\" } }",
				},
			},
			{
				kind = "p",
				text = "Props flow down; state (use_state) and refs (use_ref) are per-component. "
					.. "Composition is just nesting nodes — the same model React popularised, rendered "
					.. "entirely as text into a Neovim buffer.",
			},
			{ kind = "h", text = "memo" },
			{
				kind = "p",
				text = "Add `memo = true` to a function-component node and it bails out of re-rendering "
					.. "while its props are shallow-equal to the last render (React.memo) — the fast path "
					.. "for a stable subtree under a busy parent. It only ever SKIPS work; the fiber's own "
					.. "state updates re-render it directly, past the bailout.",
			},
			{ kind = "h", text = "key" },
			{
				kind = "p",
				text = "Reconciliation matches a parent's children to the previous render's fibers. A child "
					.. "carrying a `key` is matched BY KEY (React-style), so it keeps its fiber — and its "
					.. "hook state — even when siblings are inserted, removed, or reordered around it. A "
					.. "child WITHOUT a key falls back to positional (index) matching. Use any stable value "
					.. "(a reference-stable object is ideal); it also gives the cursor anchor a logical "
					.. "identity to hold the reader's place across a relayout. See the row example below.",
			},
			{
				kind = "code",
				lines = {
					"-- keyed list: inserting `new` keeps each row's fiber + state,",
					"-- and paints the move rather than re-rendering everything below it",
					"local children = {}",
					"for _, item in ipairs(items) do",
					"  children[#children + 1] =",
					"    { comp = Row, key = item.id, props = { item = item } }",
					"end",
					"return { comp = ui.col, props = {}, children = children }",
				},
			},
		},
	},
}
