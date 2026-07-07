-- Navigation widgets, cursor-driven like everything else on the page: a
-- horizontal tab bar for the top-level pages (Home | Components | API) and a
-- vertical side-nav for the master/detail reference pages. Both are lists of
-- selectable items over ONE shared item renderer — a label with role="button"
-- so hover + <CR>/click ride the existing hit-map. The active item is painted
-- in Title; the rest hover-highlight.

local ui = require("fibrous.inline.components")

local M = {}

-- One selectable entry. `active` items are bold-Title and inert (no handler);
-- the rest carry the press handler and a hover cue.
--- @param item { id: string, label: string }
--- @param active boolean
--- @param on_select fun(id: string)
--- @return table node
local function item(item, active, on_select)
	local style = active and { text_hl = "Title" } or { text_hl = "@comment", _hover = { text_hl = "Title" } }
	return {
		comp = ui.label,
		props = {
			text = item.label,
			role = not active and "button" or nil,
			style = style,
			on_press = not active and function()
				on_select(item.id)
			end or nil,
		},
	}
end

-- The top page tabs, a horizontal row with a rule under it that spans the page.
--- @param _ table ctx (unused)
--- @param props { pages: table[], active: string, on_select: fun(id: string) }
function M.tabs(_, props)
	local tabs = {}
	for _, page in ipairs(props.pages) do
		tabs[#tabs + 1] = item(page, page.id == props.active, props.on_select)
	end
	return {
		comp = ui.col,
		props = { style = { border = { bottom = true, hl = "NonText" }, padding = { x = 2 } } },
		children = {
			{ comp = ui.row, props = { gap = 3 }, children = tabs },
		},
	}
end

-- The docs pages' left column: a vertical list of entries, one per doc.
--- @param _ table ctx (unused)
--- @param props { items: table[], active: string, on_select: fun(id: string), width?: integer }
function M.sidenav(_, props)
	local rows = {}
	for _, entry in ipairs(props.items) do
		rows[#rows + 1] = item(entry, entry.id == props.active, props.on_select)
	end
	return {
		comp = ui.col,
		props = {
			width = props.width or 18,
			gap = 0,
			style = { border = { right = true, hl = "NonText" }, padding = { right = 2 } },
		},
		children = rows,
	}
end

return M
