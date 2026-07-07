-- The API reference page: master/detail, same shape as components_page. A left
-- side-nav lists the sections (webapp.api_ref); the content pane renders that
-- section's blocks — paragraphs, subheadings, props/opts tables and static code
-- blocks. No live editors: the mount APIs can't run inside the page.

local ui = require("fibrous.inline.components")
local nav = require("webapp.nav")
local props_table = require("webapp.props_table")
local api_ref = require("webapp.api_ref")

local by_id, items = {}, {}
for _, section in ipairs(api_ref) do
	by_id[section.id] = section
	items[#items + 1] = { id = section.id, label = section.name }
end

-- A static (non-editable) code block: a bordered col of monospace lines.
local function code_block(lines)
	local rows = {}
	for _, line in ipairs(lines) do
		-- a blank line still needs a node with height; a space keeps the row
		rows[#rows + 1] = { comp = ui.label, props = { text = line == "" and " " or line, style = { text_hl = "String" } } }
	end
	return {
		comp = ui.col,
		props = { gap = 0, style = { border = "rounded", padding = { x = 2 }, hl = "CursorLine" } },
		children = rows,
	}
end

-- One block -> one node.
local function render_block(block)
	if block.kind == "p" then
		return { comp = ui.paragraph, props = { text = block.text } }
	elseif block.kind == "h" then
		return { comp = ui.label, props = { text = block.text, style = { text_hl = "Title" } } }
	elseif block.kind == "table" then
		return { comp = props_table.table, props = { title = block.title, rows = block.rows } }
	elseif block.kind == "code" then
		return code_block(block.lines)
	end
	return { comp = ui.col, props = {} }
end

return function(ctx)
	local active = ctx.use_state(items[1].id)
	local section = by_id[active.get()]

	local content = { { comp = ui.label, props = { text = section.name, style = { text_hl = "Title" } } } }
	for _, block in ipairs(section.blocks) do
		content[#content + 1] = render_block(block)
	end

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
