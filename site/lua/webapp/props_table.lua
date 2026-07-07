-- A presentational props/opts table: given rows of { name, type, desc }, lay
-- them out as aligned columns — name (Function-coloured) and type (Type) padded
-- to the widest in the set, then a wrapping description that grows. Shared by
-- the Components and API reference pages. `title` defaults to "Props".

local ui = require("fibrous.inline.components")

local M = {}

--- Pad `s` with spaces on the right to `width` display columns.
--- @param s string
--- @param width integer
--- @return string
local function pad(s, width)
	return s .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(s)))
end

--- @param _ table ctx (unused)
--- @param props { title?: string, rows: { [1]: string, [2]: string, [3]: string }[] }
function M.table(_, props)
	local name_w, type_w = 0, 0
	for _, r in ipairs(props.rows) do
		name_w = math.max(name_w, vim.fn.strdisplaywidth(r[1]))
		type_w = math.max(type_w, vim.fn.strdisplaywidth(r[2]))
	end

	local children = {
		{ comp = ui.label, props = { text = props.title or "Props", style = { text_hl = "Title" } } },
	}
	for _, r in ipairs(props.rows) do
		children[#children + 1] = {
			comp = ui.row,
			props = { gap = 2 },
			children = {
				{ comp = ui.label, props = { text = pad(r[1], name_w), style = { text_hl = "Function" } } },
				{ comp = ui.label, props = { text = pad(r[2], type_w), style = { text_hl = "Type" } } },
				{ comp = ui.paragraph, props = { text = r[3] or "", grow = 1 } },
			},
		}
	end

	return { comp = ui.col, props = { gap = 0 }, children = children }
end

return M
