-- Benchmark of the REAL homepage — the closest thing to a production
-- workload fibrous has (banner + pitch + five playground sections, each an
-- editor float pair over a live example). Invoked from the repo root:
--
--   nvim --headless -u NONE -i NONE -l tests/bench.lua
--
-- or `nix run .#bench`, which pins DOCS_ROOT/FIBROUS_PATH to the flake's
-- store paths (FIBROUS_PATH in the environment still wins, so a local
-- fibrous tree can be benched without a lock bump). Knobs, all env vars:
-- BENCH_COLS/BENCH_LINES (grid, default 160x45), BENCH_N (samples, 30).
--
-- Native numbers are the baseline for "is the wasm build slow, or is the
-- page slow": run this, then compare against the same interactions in the
-- browser build by feel (there is no in-browser twin yet).

local root = vim.env.DOCS_ROOT or vim.fn.getcwd()
local fibrous = vim.env.FIBROUS_PATH or (root .. "/../nui-reactive")
fibrous = vim.fn.fnamemodify(fibrous, ":p"):gsub("/$", "")

package.path = table.concat({
  root .. "/site/lua/?.lua",
  root .. "/site/lua/?/init.lua",
  fibrous .. "/lua/?.lua",
  fibrous .. "/lua/?/init.lua",
  package.path,
}, ";")

local COLS = tonumber(vim.env.BENCH_COLS) or 160
local LINES = tonumber(vim.env.BENCH_LINES) or 45
local N = tonumber(vim.env.BENCH_N) or 30
vim.o.columns = COLS
vim.o.lines = LINES
-- headless, the sole window doesn't follow the grid options on its own
vim.cmd("wincmd =")
vim.api.nvim_win_set_height(0, LINES - 2)
vim.o.swapfile = false
-- -u NONE leaves syntax highlighting off; the site runs with it on, and the
-- focus-policy transcriber's synID sampling is a major cost — keep parity.
vim.cmd("syntax enable")

local mount = require("fibrous.inline.mount")
local webapp = require("webapp")

local hr = vim.uv.hrtime

local function stats(samples)
  table.sort(samples)
  local sum = 0
  for _, s in ipairs(samples) do
    sum = sum + s
  end
  local function ms(ns)
    return ("%7.2f"):format(ns / 1e6)
  end
  return ("min %s  p50 %s  avg %s  max %s ms"):format(
    ms(samples[1]),
    ms(samples[math.ceil(#samples / 2)]),
    ms(sum / #samples),
    ms(samples[#samples])
  )
end

local function bench(label, fn)
  local samples = {}
  for i = 1, N do
    local t0 = hr()
    fn(i)
    samples[#samples + 1] = hr() - t0
  end
  io.write(("%-30s %s\n"):format(label, stats(samples)))
end

io.write(("homepage bench: %dx%d grid, N=%d\n  fibrous: %s\n"):format(COLS, LINES, N, fibrous))

local t0 = hr()
local handle = mount.window(webapp, {}, { winid = 0, mode = "scroll", mouse = { follow = true } })
io.write(("%-30s %7.2f ms\n"):format("mount + first paint", (hr() - t0) / 1e6))
vim.wait(100, function()
  return false
end) -- settle post-commit effects (the clock example arms its timer here)

local page_h = vim.api.nvim_buf_line_count(handle.bufnr)
local view_h = vim.api.nvim_win_get_height(handle.winid)
io.write(("page: %d buffer lines through a %d-row viewport\n\n"):format(page_h, view_h))

-- Full pipeline: root component render + reconcile + layout + paint + buffer
-- flush + subwindow sync. The worst-case frame a state change can cost.
bench("root re-render (set_props)", function()
  handle.set_props({})
end)

-- Geometry + paint without re-rendering components (window resize path).
bench("relayout (geometry + paint)", function()
  handle.relayout()
end)

-- The j/k + wheel path: reposition every subwindow float against the new
-- topline (and rewrite mirrors/transcriptions of unfocused focus-policy
-- widgets). This is the hottest interaction on the site.
local max_top = math.max(page_h - view_h, 1)
bench("scroll resync (WinScrolled)", function(i)
  local topline = 1 + (i * 7) % max_top
  vim.api.nvim_win_call(handle.winid, function()
    vim.fn.winrestview({ topline = topline, lnum = topline, col = 0 })
  end)
  vim.api.nvim_exec_autocmds("WinScrolled", { pattern = tostring(handle.winid) })
end)

-- Hover/interaction hit-testing on cursor motion (also the follow-mouse path,
-- which turns pointer motion into exactly these cursor moves).
vim.api.nvim_win_call(handle.winid, function()
  vim.fn.winrestview({ topline = 1, lnum = 1, col = 0 })
end)
vim.api.nvim_exec_autocmds("WinScrolled", { pattern = tostring(handle.winid) })
vim.api.nvim_set_current_win(handle.winid)
bench("cursor hover step", function(i)
  local row = 1 + (i * 3) % math.min(view_h, page_h)
  vim.api.nvim_win_set_cursor(handle.winid, { row, 2 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = handle.bufnr })
end)

handle.unmount()
vim.wait(50, function()
  return false
end)
io.write("\ndone\n")
