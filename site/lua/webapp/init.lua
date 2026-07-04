-- The fibrous-docs homepage: masthead, a one-paragraph pitch, then the live
-- playground sections (webapp.playground) — one per entry in webapp.examples.
-- Mounted fullscreen in scroll mode by site/init.lua; this page IS a fibrous
-- app running inside the browser's Neovim.

local ui = require("fibrous.inline.components")
local banner = require("webapp.banner")
local playground = require("webapp.playground")
local examples = require("webapp.examples")

-- The site owns its look; applying at require time keeps every entry point
-- (browser, local preview, specs) on the same palette.
require("webapp.theme").apply()

local PITCH = "A React-style declarative UI framework for Neovim. This page is itself a "
  .. "fibrous app, rendered by a real Neovim compiled to WebAssembly — scroll with j/k or "
  .. "the mouse wheel, press things with <CR> or a click, and edit the examples live."

return function()
  local children = {
    { comp = banner, props = {} },
    { comp = ui.paragraph, props = { text = PITCH } },
  }
  for _, ex in ipairs(examples) do
    -- Full-width separator: an empty col stretches to the page width (default
    -- cross-axis align), and its top border draws the rule — no hardcoded rep
    -- count to fall short on wide screens.
    children[#children + 1] = {
      comp = ui.col,
      props = { style = { border = { top = true, hl = "NonText" } } },
    }
    children[#children + 1] = { comp = playground.section, props = { example = ex } }
  end
  return {
    comp = ui.col,
    props = { gap = 2, style = { padding = { x = 2, y = 1 } } },
    children = children,
  }
end
