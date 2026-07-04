-- The homepage (site/lua/webapp): ascii banner, then live playground sections
-- — intro paragraph, an 80-col lua code editor beside the component it
-- evaluates to, reload via button (or <C-CR> in the editor), a detailed
-- paragraph below. Compile/render errors surface in the preview panel and
-- never take the page down (error boundary around the user component).

local mount = require("fibrous.inline.mount")
local playground = require("webapp.playground")
local examples = require("webapp.examples")

local TITLES = {
  "Reactive state",
  "Cursor-native widgets",
  "A CSS-like box model",
  "Effects & timers",
  "Animations",
  "Two focus policies",
}

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function page_text(handle)
  return table.concat(lines_of(handle.bufnr), "\n")
end

-- Row index (0-based) of the first canvas line containing `needle`.
local function find_row(handle, needle)
  for i, l in ipairs(lines_of(handle.bufnr)) do
    if l:find(needle, 1, true) then
      return i - 1
    end
  end
  return nil
end

-- The counter example's editor buffer, reset to its original code (editor
-- buffers persist across mounts by design, so earlier edits would leak).
local function counter_buf()
  local buf = playground.editor_of("counter")
  assert(buf, "counter editor buffer not created")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(examples[1].code, "\n", { plain = true }))
  return buf
end

-- Activate the interactive node under canvas cell (row0, col0), the way a
-- user would: park the cursor there and hit <CR>.
local function press_at(handle, row0, col0)
  vim.api.nvim_set_current_win(handle.winid)
  vim.api.nvim_win_set_cursor(handle.winid, { row0 + 1, col0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = handle.bufnr })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "xt", false)
end

local function mount_home()
  -- wide enough for editor (80 + border) + preview side by side
  vim.o.columns = 200
  vim.o.lines = 60
  return mount.floating(require("webapp"), {}, { width = 180, height = 50, row = 0, col = 0, mode = "scroll" })
end

-- Press the i-th "Reload preview" button on the page.
local function reload_via_button(handle, i)
  local seen = 0
  for row0, l in ipairs(lines_of(handle.bufnr)) do
    local col = l:find("Reload preview", 1, true)
    if col then
      seen = seen + 1
      if seen == i then
        press_at(handle, row0 - 1, col + 1)
        return true
      end
    end
  end
  return false
end

describe("webapp home", function()
  it("renders the banner and every example section", function()
    local handle = mount_home()
    local text = page_text(handle)

    -- the colossal figlet art (the F-row of "fibrous")
    assert.truthy(find_row(handle, "888888 888 88888b."))
    for _, title in ipairs(TITLES) do
      assert.truthy(find_row(handle, title), "missing section: " .. title)
    end
    -- each section carries an editor and its reload button
    local _, buttons = text:gsub("Reload preview", "")
    assert.equal(#TITLES, buttons)

    -- requiring the app applied the site theme
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    assert.equal(0x1a1b26, normal.bg)

    handle.unmount()
  end)

  it("section separators span the full page width", function()
    local handle = mount_home()

    -- a separator row is nothing but spaces and ─ (border rows always carry
    -- corner/side chars too, so they never match)
    local width
    for _, l in ipairs(lines_of(handle.bufnr)) do
      if l:find("─") and not l:find("[^%s─]") then
        local _, n = l:gsub("─", "")
        width = n
        break
      end
    end
    assert.equal(180 - 4, width) -- page width minus the x = 2 padding

    handle.unmount()
  end)

  it("a narrow viewport shrinks the editor, not the preview", function()
    vim.o.columns = 110
    vim.o.lines = 60
    local handle = mount.floating(require("webapp"), {}, { width = 100, height = 50, row = 0, col = 0, mode = "scroll" })

    -- the preview keeps its minimum width, so the counter renders unclipped...
    local row = find_row(handle, "Count: 0")
    assert.truthy(row, "preview squeezed to nothing")
    -- ...because the editor is what gave up the width: the preview's content
    -- now starts left of where the fixed 80-col editor used to end
    local line = lines_of(handle.bufnr)[row + 1]
    local prefix = line:sub(1, line:find("Count: 0", 1, true) - 1)
    assert.is_true(vim.fn.strdisplaywidth(prefix) < 80)

    handle.unmount()
  end)

  it("editors are real lua buffers seeded with code that already previews", function()
    local handle = mount_home()

    local buf = counter_buf()
    -- syntax, not filetype — filetype would fire the runtime ftplugin, whose
    -- unguarded vim.treesitter.start() is fatal in the parser-less nvim.wasm
    assert.equal("lua", vim.bo[buf].syntax)
    assert.equal("", vim.bo[buf].filetype)
    -- the initial preview is compiled from that same code
    assert(find_row(handle, "Count: 0"))

    handle.unmount()
  end)

  it("the reload button re-renders the preview from the edited code", function()
    local handle = mount_home()

    local buf = counter_buf()
    local code = table.concat(lines_of(buf), "\n"):gsub("Count:", "Tally:")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(code, "\n", { plain = true }))

    assert.is_true(reload_via_button(handle, 1))
    assert(find_row(handle, "Tally: 0"))
    assert.falsy(find_row(handle, "Count: 0"))

    handle.unmount()
  end)

  it("compile errors show in the preview and keep the page alive", function()
    local handle = mount_home()

    local buf = counter_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "return function( -- unfinished" })
    assert.is_true(reload_via_button(handle, 1))
    assert(find_row(handle, "error"), "compile error not surfaced")

    -- a chunk that runs but does not return a component is reported too
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "return 42" })
    assert.is_true(reload_via_button(handle, 1))
    assert(find_row(handle, "component function"))

    -- the rest of the page is untouched
    assert.truthy(find_row(handle, TITLES[4]))

    handle.unmount()
  end)

  it("render-time errors are caught by the boundary, page survives", function()
    local handle = mount_home()

    local buf = counter_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'return function() error("boom") end' })
    assert.is_true(reload_via_button(handle, 1))
    assert(find_row(handle, "boom"), "render error not surfaced")
    assert(find_row(handle, TITLES[4]), "page died with the component")

    handle.unmount()
  end)
end)
