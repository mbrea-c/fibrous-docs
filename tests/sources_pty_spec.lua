local termdraw = require("fibrous.bench.termdraw")

describe("source mapping documentation in a terminal", function()
  it("renders the new API and architecture prose through the real docs shell", function()
    local root = vim.fn.fnamemodify(debug.getinfo(require("fibrous.inline.mount").floating, "S").source:sub(2), ":p:h:h:h:h")
    local path = vim.fn.tempname()
    termdraw.drive({ cols = 150, rows = 48, rtp = { root, vim.fn.getcwd() .. "/site" },
      steps = { { lua = "FRAME(1)", wait_ms = 250 }, { lua = "FRAME(2)", wait_ms = 250 },
        { lua = "FRAME(3)", wait_ms = 250 }, { lua = "FRAME(4)", wait_ms = 250 } },
      init = ([[
        local app = require("fibrous.inline.mount").floating(require("webapp"), {},
          { width = 144, height = 42, row = 1, col = 1, mode = "scroll" })
        local result = {}
        local function press(needle)
          for row, line in ipairs(vim.api.nvim_buf_get_lines(app.bufnr, 0, -1, false)) do
            local col = line:find(needle, 1, true)
            if col then
              vim.api.nvim_set_current_win(app.winid)
              vim.api.nvim_win_set_cursor(app.winid, { row, col - 1 })
              vim.api.nvim_exec_autocmds("CursorMoved", { buffer = app.bufnr })
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "xt", false)
              return
            end
          end
          error("missing docs control " .. needle)
        end
        _G.FRAME = function(i)
          if i == 1 then press("API")
          elseif i == 2 then press("Source mapping")
          elseif i == 3 then
            vim.cmd("redraw")
            local lines = {}
            for row = 1, vim.o.lines do
              local line = {}
              for col = 1, vim.o.columns do line[#line + 1] = vim.fn.screenstring(row, col) end
              lines[#lines + 1] = table.concat(line)
            end
            result.screen = table.concat(lines, "\n")
            result.api = table.concat(vim.api.nvim_buf_get_lines(app.bufnr, 0, -1, false), "\n")
            press("Architecture")
            press("Source mapping")
          elseif i == 4 then
            result.architecture = table.concat(vim.api.nvim_buf_get_lines(app.bufnr, 0, -1, false), "\n")
            app.unmount()
            result.finished = true
          end
          vim.fn.writefile({ vim.json.encode(result) }, %q)
        end
      ]]):format(path),
    })
    local result = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    vim.fn.delete(path)
    if vim.env.FIBROUS_DOCS_CAPTURE then io.write(result.screen .. "\n") end
    assert.is_true(result.finished)
    assert.truthy(result.screen:find("Logical document sources", 1, true))
    assert.truthy(result.api:find("sources.resolve", 1, true))
    assert.truthy(result.architecture:find("Buffer rows are a rendering artifact", 1, true))
    assert.falsy(result.api:find("Error", 1, true))
  end)
end)
