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

-- id -> entry, and the side-nav item list, built once.
local by_id, items = {}, {}
for _, entry in ipairs(components_ref) do
	by_id[entry.id] = entry
	items[#items + 1] = { id = entry.id, label = entry.name }
end

-- id -> a stable per-entry doc component (distinct identity ⇒ remount on switch).
local doc_comps = {}
local function doc_comp(entry)
	if not doc_comps[entry.id] then
		doc_comps[entry.id] = function()
			local content = {
				{ comp = ui.label, props = { text = entry.name, style = { text_hl = "Title" } } },
				{ comp = ui.paragraph, props = { text = entry.summary, style = { text_hl = "@comment" } } },
				{ comp = props_table.table, props = { rows = entry.props } },
			}
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
	local active = ctx.use_state(items[1].id)
	local entry = by_id[active.get()]

	return {
		comp = ui.row,
		props = { gap = 2, style = { padding = { x = 2, y = 1 } } },
		children = {
			{
				comp = nav.sidenav,
				props = {
					items = items,
					active = active.get(),
					on_select = function(id)
						active.set(id)
					end,
				},
			},
			{ comp = doc_comp(entry), props = {} },
		},
	}
end
