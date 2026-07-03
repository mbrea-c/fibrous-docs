-- fibrous-docs entrypoint. Runs inside nvim.wasm in the browser: fibrous
-- (with its vendored nui) is a pack/start plugin on the packpath.
--
-- Everything below is deferred to VimEnter because init.lua is sourced
-- *before* pack/*/start plugins land on the runtimepath (:h load-plugins).

vim.opt.shortmess:append("I") -- welcome panel replaces the intro screen
vim.o.swapfile = false

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
			local handle = mount.window(
				require("webapp"),
				{},
				{ winid = vim.api.nvim_get_current_win(), mode = "scroll" }
			)
			handle.focus()
		end)
	end,
})
