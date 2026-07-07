-- The Components reference page: master/detail. A left side-nav lists every
-- builtin (webapp.components_ref); the content pane shows the selected entry's
-- summary, its props table, a cross-reference to the shared layout/style props
-- (documented on the API ▸ Styling tab), and a live editor/preview playground.
-- Only the selected entry's playground is mounted, so the page stays cheap.

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

return function(ctx)
	local active = ctx.use_state(items[1].id)
	local entry = by_id[active.get()]

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
	-- The live playground for this component (same widget as the Home examples).
	content[#content + 1] = { comp = playground.section, props = { example = entry.example } }

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
			{ comp = ui.col, props = { grow = 1, gap = 1 }, children = content },
		},
	}
end
