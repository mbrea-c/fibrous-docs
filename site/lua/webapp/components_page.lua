-- The Components reference page: master/detail. A left side-nav lists every
-- builtin (webapp.components_ref); the content pane shows the selected entry's
-- summary, its props table, a cross-reference to the shared layout/style props
-- (documented on the API ▸ Styling tab), and a live editor/preview playground.
--
-- Each entry's doc is its OWN memoized component. Reconciliation is positional
-- and matches by component identity, so giving the content pane a DISTINCT comp
-- per entry makes a side-nav switch fully REMOUNT the doc — the playground's
-- editor buffer and preview state reset to the selected component instead of
-- clinging to the previously shown one (a single reused section fiber would).

local ui = require("fibrous.inline.components")
local nav = require("webapp.nav")
local props_table = require("webapp.props_table")
local playground = require("webapp.playground")
local components_ref = require("webapp.components_ref")

-- The side-nav is grouped: PRIMITIVES (host leaves the reconciler/layout/flush
-- machinery operate on directly) then BUILTINS (ordinary function components
-- that desugar to primitives). Each group is a header row followed by its
-- entries, in components_ref order.
local GROUPS = {
	{ key = "primitive", header = "Primitives" },
	{ key = "builtin", header = "Builtins" },
}

-- id -> entry (for lookup); nav_items (with header rows) for the side-nav;
-- first_id is the default-selected doc.
local by_id = {}
for _, entry in ipairs(components_ref) do
	by_id[entry.id] = entry
end

local nav_items, first_id = {}, nil
for _, group in ipairs(GROUPS) do
	nav_items[#nav_items + 1] = { header = group.header }
	for _, entry in ipairs(components_ref) do
		if entry.group == group.key then
			nav_items[#nav_items + 1] = { id = entry.id, label = entry.name }
			first_id = first_id or entry.id
		end
	end
end

-- Shown once above the master/detail, explaining what the two groups mean.
local INTRO = "Components come in two kinds. PRIMITIVES are the leaves the host itself "
	.. "understands — the reconciler, layout and flush machinery operate only on these, and no "
	.. "primitive can be reproduced from another just by changing props. BUILTINS are ordinary "
	.. "function components that ship in the box: most desugar to a primitive by remapping props, "
	.. "and a few are stateful — owning hooks and effects of their own. Nothing about the builtins "
	.. "is privileged; you write your own the exact same way."

-- id -> a stable per-entry doc component (distinct identity ⇒ remount on switch).
local doc_comps = {}
local function doc_comp(entry)
	if not doc_comps[entry.id] then
		doc_comps[entry.id] = function()
			-- A dim tag beside the title says which group the entry is in (and, for
			-- a stateful builtin, that it owns state rather than being a pure remap).
			local tag = entry.group == "primitive" and "primitive"
				or (entry.stateful and "builtin · stateful wrapper" or "builtin")
			local content = {
				{
					comp = ui.row,
					props = { gap = 1 },
					children = {
						{ comp = ui.label, props = { text = entry.name, style = { text_hl = "Title" } } },
						{ comp = ui.label, props = { text = "· " .. tag, style = { text_hl = "@comment" } } },
					},
				},
				{ comp = ui.paragraph, props = { text = entry.summary, style = { text_hl = "@comment" } } },
			}
			-- A stateful builtin gets an explicit callout: it is NOT a pure prop
			-- remap like the other builtins — it holds hooks/effects of its own.
			if entry.stateful then
				content[#content + 1] = {
					comp = ui.paragraph,
					props = {
						text = "⚡ Stateful wrapper: unlike the other builtins (pure prop-remaps over a "
							.. "primitive), this one owns hook state and side effects — here a uv timer that "
							.. "drives the frames and tears itself down on unmount.",
						style = { text_hl = "WarningMsg" },
					},
				}
			end
			content[#content + 1] = { comp = props_table.table, props = { rows = entry.props } }
			if entry.layout or entry.style then
				content[#content + 1] = {
					comp = ui.paragraph,
					props = {
						text = "Also accepts all layout props (width, grow, align, justify, gap…) and the "
							.. "style vocabulary (text_hl, hl, border, padding, _hover…) — see the API ▸ Styling tab.",
						style = { text_hl = "@comment" },
					},
				}
			end
			content[#content + 1] = { comp = playground.section, props = { example = entry.example } }
			return { comp = ui.col, props = { grow = 1, gap = 1 }, children = content }
		end
	end
	return doc_comps[entry.id]
end

return function(ctx)
	local active = ctx.use_state(first_id)
	local entry = by_id[active.get()]

	return {
		comp = ui.col,
		props = { grow = 1, gap = 1, style = { padding = { x = 2, y = 1 } } },
		children = {
			{ comp = ui.paragraph, props = { text = INTRO, style = { text_hl = "@comment" } } },
			{
				comp = ui.row,
				props = { grow = 1, gap = 2 },
				children = {
					{
						comp = nav.sidenav,
						props = {
							items = nav_items,
							active = active.get(),
							on_select = function(id)
								active.set(id)
							end,
						},
					},
					{ comp = doc_comp(entry), props = {} },
				},
			},
		},
	}
end
