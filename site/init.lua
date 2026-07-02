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

    local nr = require("fibrous")
    local el = require("fibrous.components")

    local function Welcome()
      return {
        comp = el.col,
        props = {},
        children = {
          {
            comp = el.text,
            props = {
              border = "rounded",
              lines = {
                "",
                "   fibrous.nvim",
                "   a React-like reactive UI framework for Neovim",
                "",
                "   This is real, upstream Neovim — compiled to",
                "   WebAssembly, running entirely in your browser.",
                "   This panel is rendered by fibrous itself.",
                "",
                "   :Examples          list the demos",
                "   :Example counter   hooks + state (also: hello,",
                "                      form, sidebar, panel)",
                "",
                "   q closes this panel — the editor is yours.",
                "",
              },
            },
          },
        },
      }
    end

    local handle = nr.mount(Welcome, {}, { size = { width = 56, height = 16 } })
    vim.keymap.set("n", "q", function()
      if handle then
        pcall(handle.unmount)
        handle = nil
        vim.keymap.del("n", "q")
      end
    end, { desc = "close welcome panel" })
  end,
})
