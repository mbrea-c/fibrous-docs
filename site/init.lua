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
		local ui = require("fibrous.inline.components")

		local LOREM = "The quick brown fox jumps over the lazy dog while the five boxing "
			.. "wizards jump quickly, and pack my box with five dozen liquor jugs."

		local function section(i)
			return {
				comp = ui.paragraph,
				props = { text = ("Section %d\n\n%s"):format(i, LOREM), border = "single", padding = { x = 1 } },
			}
		end

		local function App(ctx)
			local clicks = ctx.use_state(0)
			local opts = ctx.use_state({ a = false, b = true })

			local function toggle(key)
				return function(v)
					local cur = vim.tbl_extend("force", {}, opts.get())
					cur[key] = v
					opts.set(cur)
				end
			end

			local children = {
				{ comp = ui.label, props = { text = "Inline host — interactive scroll spike", hl = "Title" } },
				{
					comp = ui.label,
					props = { text = "j/k <C-d>/<C-u> scroll · <CR>/<Space> activate · q closes", hl = "Comment" },
				},
				section(1),
				{
					comp = ui.button,
					props = {
						label = ("clicked %d times"):format(clicks.get()),
						on_press = function()
							clicks.set(clicks.get() + 1)
						end,
					},
				},
				{ comp = ui.checkbox, props = { label = "option a", checked = opts.get().a, on_toggle = toggle("a") } },
				{ comp = ui.checkbox, props = { label = "option b", checked = opts.get().b, on_toggle = toggle("b") } },
				section(2),
				{
					comp = ui.text_input,
					props = { border = "rounded", value = "single-line input — edit me" },
				},
			}
			for i = 3, 5 do
				children[#children + 1] = section(i)
			end
			children[#children + 1] = {
				comp = ui.text_input,
				props = { border = "double", height = 5, value = "multi\nline\ninput" },
			}
			for i = 6, 8 do
				children[#children + 1] = section(i)
			end
			return { comp = ui.col, props = { gap = 1, padding = 1 }, children = children }
		end

		local handle = mount.window(App, {}, { winid = vim.api.nvim_get_current_win() })
		handle.focus()
		vim.keymap.set("n", "q", function()
			if handle then
				pcall(handle.unmount)
				handle = nil
				vim.keymap.del("n", "q")
			end
		end, { desc = "close welcome panel" })
	end,
})
