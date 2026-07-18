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

		-- In the browser (nvim.wasm, flagged by the build via NVIM_WASM=1)
		-- there is no terminal to probe, but the canvas renderer implements
		-- kitty Unicode placeholders, so force the image provider on. The
		-- clipboard escapes have no host-side support there; keep them off.
		-- pcall-guarded so a pinned fibrous without fibrous.image still boots.
		if vim.env.NVIM_WASM == "1" then
			pcall(function()
				local image = require("fibrous.image")
				image.config.provider = "kitty"
				image.config.clipboard = "off"
			end)
		end

		local mount = require("fibrous.inline.mount")

		-- flash.nvim jump-to-widget: <C-.> labels every interactive fibrous
		-- element on screen (via the global fibrous.targets registry) and jumps
		-- the cursor to the one you pick, so you can reach any button/input/link
		-- without hjkl. This is a plain user keybind; the page does nothing to
		-- enable it. flash is a pack/start plugin, so require it lazily here.
		pcall(function()
			require("flash").setup()
		end)
		vim.keymap.set({ "n", "x" }, "<C-.>", function()
			require("flash").jump({
				-- wrap=true labels matches before the cursor too (else forward-only
				-- in the current window); let flash's default labeler assign labels.
				search = { multi_window = true, wrap = true, incremental = false, max_length = 0 },
				matcher = function(win)
					local Pos = require("flash.search.pos")
					local out = {}
					for _, t in ipairs(require("fibrous.targets").targets({ winid = win })) do
						out[#out + 1] = { win = win, pos = Pos(t.pos), end_pos = Pos(t.end_pos) }
					end
					return out
				end,
			})
		end, { desc = "Flash to fibrous widget" })

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
