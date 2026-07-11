-- The fibrous-docs app shell. A top nav bar (Home | Components | API) swaps the
-- active page via use_state — the site is one Neovim compiled to WebAssembly,
-- so this is in-app routing, not separate HTML pages (and it dogfoods fibrous
-- navigation). Home is the live playground landing page; Components and API are
-- master/detail reference pages with their own left side-nav.
--
-- Mounted fullscreen in scroll mode by site/init.lua; this module IS the fibrous
-- app running inside the browser's Neovim.

local ui = require("fibrous.inline.components")
local nav = require("webapp.nav")

-- The site owns its look; applying at require time keeps every entry point
-- (browser, local preview, specs) on the same palette.
require("webapp.theme").apply()

local PAGES = {
	{ id = "home", label = "Home", comp = require("webapp.home") },
	{ id = "components", label = "Components", comp = require("webapp.components_page") },
	{ id = "api", label = "API", comp = require("webapp.api_page") },
	{ id = "architecture", label = "Architecture", comp = require("webapp.architecture_page") },
}

local by_id = {}
for _, page in ipairs(PAGES) do
	by_id[page.id] = page.comp
end

return function(ctx)
	local page = ctx.use_state("home")
	return {
		comp = ui.col,
		props = { gap = 1 },
		children = {
			{
				comp = nav.tabs,
				props = {
					pages = PAGES,
					active = page.get(),
					on_select = function(id)
						page.set(id)
					end,
				},
			},
			{ comp = by_id[page.get()], props = {} },
		},
	}
end
