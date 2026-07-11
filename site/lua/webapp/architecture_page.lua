-- The Architecture page: master/detail, same shape as the API and Components
-- pages. A left side-nav lists the sections (webapp.architecture_ref); the
-- content pane renders that section's prose, which lives as a markdown file
-- (docs/architecture/*.md) rendered by ui.markdown. Static explanation only, no
-- live editors: this explains how fibrous works internally.

local ui = require("fibrous.inline.components")
local nav = require("webapp.nav")
local architecture_ref = require("webapp.architecture_ref")
local md_docs = require("webapp.md_docs")

local by_id, items = {}, {}
for _, section in ipairs(architecture_ref) do
	by_id[section.id] = section
	items[#items + 1] = { id = section.id, label = section.name }
end

return function(ctx)
	local active = ctx.use_state(items[1].id)
	local section = by_id[active.get()]

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
			{
				comp = ui.col,
				props = { grow = 1, gap = 1 },
				children = {
					{ comp = ui.label, props = { text = section.name, style = { text_hl = "Title" } } },
					{ comp = ui.markdown, props = { text = md_docs.load(section.md) } },
				},
			},
		},
	}
end
