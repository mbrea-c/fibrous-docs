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
					{ "zindex", "integer", "root float z-index; default 50" },
				},
			},
			{ kind = "h", text = "mount.split(component, props, opts)" },
			{
				kind = "p",
				text = "Open a native split pane and mount over it; closing the pane tears the app down. "
					.. "opts.split = { direction, position, size } picks the pane, plus the shared "
					.. "mode/mouse/keys/zindex.",
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
				text = "Layout is a flexbox pass over the component tree. Every node — containers and "
					.. "leaves alike — accepts these; gap only applies to containers (col/row/container).",
			},
			{ kind = "table", title = "layout props", rows = components_ref.LAYOUT_PROPS },
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
		},
	},
}
