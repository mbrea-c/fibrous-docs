-- The homepage masthead: "fibrous" / ".nvim" in figlet colossal (kerned).
-- Static art embedded verbatim — regenerate with `figlet -f colossal -k`.

local ui = require("fibrous.inline.components")

local FIBROUS = vim.split([[
 .d888 d8b 888
d88P"  Y8P 888
888        888
888888 888 88888b.  888d888  .d88b.  888  888 .d8888b
888    888 888 "88b 888P"   d88""88b 888  888 88K
888    888 888  888 888     888  888 888  888 "Y8888b.
888    888 888 d88P 888     Y88..88P Y88b 888      X88
888    888 88888P"  888      "Y88P"   "Y88888  88888P']], "\n")

local NVIM = vim.split([[
                      d8b
                      Y8P

    88888b.  888  888 888 88888b.d88b.
    888 "88b 888  888 888 888 "888 "88b
    888  888 Y88  88P 888 888  888  888
d8b 888  888  Y8bd8P  888 888  888  888
Y8P 888  888   Y88P   888 888  888  888]], "\n")

return function()
  local children = {}
  for _, line in ipairs(FIBROUS) do
    children[#children + 1] = { comp = ui.label, props = { text = line, hl = "Function" } }
  end
  for _, line in ipairs(NVIM) do
    children[#children + 1] = { comp = ui.label, props = { text = line, hl = "Comment" } }
  end
  -- align_self: center the art block as a unit within the page column —
  -- centering the labels individually would shear the figlet art apart.
  return { comp = ui.col, props = { padding = { y = 1 }, align_self = "center" }, children = children }
end
