-- fibrous-docs entrypoint. Runs inside nvim.wasm in the browser: fibrous
-- (with its vendored nui) is a pack/start plugin on the packpath.
--
-- Everything below is deferred to VimEnter because init.lua is sourced
-- *before* pack/*/start plugins land on the runtimepath (:h load-plugins).

vim.opt.shortmess:append("I") -- the homepage replaces the intro screen
vim.o.swapfile = false
vim.o.laststatus = 0 -- no statusline under the fullscreen page

-- nvim.wasm has no loadable treesitter parsers (bundled ones are dlopen'd
-- .so files), but runtime ftplugins (lua, markdown, ...) call
-- vim.treesitter.start() unguarded — any :e foo.lua would error. Soften it
-- browser-wide: no parser simply means no treesitter highlighting.
do
	local ts_start = vim.treesitter.start
	---@diagnostic disable-next-line: duplicate-set-field
	vim.treesitter.start = function(...)
		pcall(ts_start, ...)
	end
end

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		-- The examples bootstrap (package.path for `examples.*`, :Example /
		-- :Examples commands) lives at the plugin root, outside lua/.
		local bootstrap = vim.api.nvim_get_runtime_file("examples/init.lua", false)[1]
		if bootstrap then
			dofile(bootstrap)
		end

		local mount = require("fibrous.inline.mount")

		vim.schedule(function()
			-- Mouse: clicks activate (the default); focus-follows-mouse is OFF —
			-- streaming pointer motion as cursor moves yanked the view around, so
			-- the cursor is driven by clicks and the keyboard, not hover.
			local handle = mount.window(
				require("webapp"),
				{},
				{ winid = vim.api.nvim_get_current_win(), mode = "scroll", mouse = { follow = false } }
			)
			handle.focus()
		end)
	end,
})
