-- The docs shell (site/lua/webapp): a top nav bar (Home | Components | API)
-- swaps the active page via use_state. Home is the existing playground page;
-- Components and API are master/detail reference pages — a left side-nav
-- selects which entry's doc shows in the content pane. Every builtin component
-- gets a props table + a live editor/preview playground; the API page
-- documents the mount APIs, hooks and the style vocabulary.

local mount = require("fibrous.inline.mount")

local BANNER_F_ROW = "888888 888 88888b." -- the figlet "fibrous", Home only

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function page_text(handle)
  return table.concat(lines_of(handle.bufnr), "\n")
end

-- Row/col (0-based) of the first canvas cell containing `needle`, or nil.
local function find_at(handle, needle)
  for i, l in ipairs(lines_of(handle.bufnr)) do
    local col = l:find(needle, 1, true)
    if col then
      return i - 1, col - 1
    end
  end
  return nil
end

local function find_row(handle, needle)
  local row = find_at(handle, needle)
  return row
end

-- Activate the interactive node under `needle` the way a user would: park the
-- cursor on it and hit <CR>.
local function press(handle, needle)
  local row0, col0 = find_at(handle, needle)
  assert(row0, "nothing to press matching: " .. needle)
  vim.api.nvim_set_current_win(handle.winid)
  vim.api.nvim_win_set_cursor(handle.winid, { row0 + 1, col0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = handle.bufnr })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "xt", false)
end

local function mount_docs()
  vim.o.columns = 200
  vim.o.lines = 60
  return mount.floating(require("webapp"), {}, { width = 180, height = 50, row = 0, col = 0, mode = "scroll" })
end

describe("webapp docs shell", function()
  it("shows a nav bar and defaults to the Home page", function()
    local handle = mount_docs()
    local text = page_text(handle)

    for _, tab in ipairs({ "Home", "Components", "API" }) do
      assert.truthy(text:find(tab, 1, true), "missing nav tab: " .. tab)
    end
    -- Home is the default page: its banner is on screen
    assert.truthy(find_row(handle, BANNER_F_ROW), "home banner not shown by default")

    handle.unmount()
  end)

  it("the Components tab opens a side-nav of every builtin and the first doc", function()
    local handle = mount_docs()

    press(handle, "Components")
    local text = page_text(handle)

    -- the banner is a Home-only thing
    assert.falsy(find_row(handle, BANNER_F_ROW), "banner leaked onto the Components page")
    -- the side-nav lists every builtin component
    for _, name in ipairs({ "col", "row", "text", "text_input", "raw_buffer", "container", "label", "paragraph", "animation", "button", "checkbox" }) do
      assert.truthy(text:find(name, 1, true), "side-nav missing component: " .. name)
    end
    -- the first entry's doc is shown: a Props heading + a live playground editor
    assert.truthy(text:find("Props", 1, true), "no props table on the first component doc")
    assert.truthy(text:find("Reload preview", 1, true), "no live playground on the component doc")

    handle.unmount()
  end)

  it("the side-nav swaps which component's doc is shown", function()
    local handle = mount_docs()
    press(handle, "Components")

    -- pick a component that is NOT the default first entry
    press(handle, "checkbox")
    local text = page_text(handle)
    -- the checkbox doc mentions its on_toggle prop
    assert.truthy(text:find("on_toggle", 1, true), "checkbox doc not shown after selecting it")

    handle.unmount()
  end)

  it("every component's playground example compiles to a component function", function()
    local components_ref = require("webapp.components_ref")
    for _, entry in ipairs(components_ref) do
      local chunk, load_err = loadstring(entry.example.code, entry.id)
      assert(chunk, ("%s example fails to load: %s"):format(entry.id, load_err))
      local ok, comp = pcall(chunk)
      assert(ok, ("%s example errored on run: %s"):format(entry.id, tostring(comp)))
      assert.equal("function", type(comp), entry.id .. " example must return a component function")
    end
  end)

  it("every component's example renders without an error boundary", function()
    vim.o.columns = 200
    vim.o.lines = 60
    local components_ref = require("webapp.components_ref")
    for _, entry in ipairs(components_ref) do
      local comp = assert(loadstring(entry.example.code, entry.id))()
      local handle = mount.floating(comp, {}, { width = 120, height = 40, row = 0, col = 0, mode = "scroll" })
      local text = table.concat(vim.api.nvim_buf_get_lines(handle.bufnr, 0, -1, false), "\n")
      assert.falsy(text:lower():find("error", 1, true), entry.id .. " example rendered an error: " .. text)
      handle.unmount()
    end
  end)

  it("the API tab documents the mount APIs, hooks and styling", function()
    local handle = mount_docs()

    press(handle, "API")
    local text = page_text(handle)

    for _, section in ipairs({ "Mounting", "Hooks", "Styling" }) do
      assert.truthy(text:find(section, 1, true), "API side-nav missing section: " .. section)
    end
    -- the default (Mounting) section documents the real entry points
    assert.truthy(text:find("mount.window", 1, true) or text:find("mount.floating", 1, true), "mount API not documented")

    handle.unmount()
  end)
end)
