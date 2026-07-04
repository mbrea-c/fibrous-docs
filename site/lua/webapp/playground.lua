-- A live playground section: intro paragraph, then a lua editor (a raw_buffer
-- over a real buffer, so all of vim works in it) beside the component its code
-- evaluates to, reload button + <C-CR> below the editor, and a longer
-- explanation underneath. The pair shares the row responsively: the editor
-- takes up to 80 cols, the preview at least PREVIEW_MIN_COLS — on a narrow
-- (mobile) viewport the editor is what shrinks, not the preview.
--
-- The editor buffer is the source of truth; reload = read it, compile it,
-- swap the preview. Compile errors keep the last good preview and show the
-- message; render-time errors are caught by an error boundary around the user
-- component, so a playground mistake can never take the page down.

local ui = require("fibrous.inline.components")

local M = {}

local EDITOR_COLS = 80 -- the editor's max width; it shrinks on narrow viewports
local PREVIEW_MIN_COLS = 30 -- the preview never gets squeezed below this

-- One editor buffer (+ its reload closure and initial compile) per example,
-- created lazily and kept for the session — remounts reuse the user's edits.
local registry = {}

-- Wrap the user's component so its render runs under pcall. The wrapper uses
-- no hooks of its own, so the user component's hook slots stay positionally
-- stable across failing and succeeding renders.
local function boundary(user_comp)
  return function(ctx, props)
    local ok, tree = pcall(user_comp, ctx, props)
    if ok then
      return tree
    end
    return {
      comp = ui.paragraph,
      props = { text = "render error:\n" .. tostring(tree), style = { text_hl = "ErrorMsg" } },
    }
  end
end

-- code string -> boundary-wrapped component | nil, error message
local function compile(code)
  local chunk, err = loadstring(code, "playground")
  if not chunk then
    return nil, err
  end
  local ok, comp = pcall(chunk)
  if not ok then
    return nil, tostring(comp)
  end
  if type(comp) ~= "function" then
    return nil, "the chunk must return a component function"
  end
  return boundary(comp), nil
end

local function ensure(example)
  local entry = registry[example.name]
  if entry then
    return entry
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  local code_lines = vim.split(example.code, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, code_lines)
  vim.bo[bufnr].bufhidden = "hide"
  -- syntax, NOT filetype: filetype fires the runtime lua ftplugin, whose
  -- first line is an unguarded vim.treesitter.start() — fatal in nvim.wasm,
  -- which has no loadable parsers (bundled ones are dlopen'd .so files).
  -- Pre-setting b:did_ftplugin doesn't help: the ftplugin loader unlets it
  -- before sourcing. 'syntax' loads regex syntax/lua.vim directly, with the
  -- bonus that the editors look identical in the browser and a terminal.
  vim.bo[bufnr].syntax = "lua"
  local comp, err = compile(example.code)
  entry = {
    bufnr = bufnr,
    -- editor height fits the example: content + the two border rows
    rows = #code_lines + 2,
    initial = { comp = comp, err = err },
    reload = function() end, -- replaced with the live setter every render
  }
  for _, mode in ipairs({ "n", "i" }) do
    vim.keymap.set(mode, "<C-CR>", function()
      entry.reload()
    end, { buffer = bufnr, desc = "playground: reload the preview" })
  end
  registry[example.name] = entry
  return entry
end

-- The editor buffer behind an example, nil before its first render — for
-- tooling (and the specs), which shouldn't have to fish buffers by content.
---@param name string
---@return integer|nil
function M.editor_of(name)
  local entry = registry[name]
  return entry and entry.bufnr or nil
end

-- props: { example = { name, title, intro, code, details } }
function M.section(ctx, props)
  local ex = props.example
  local entry = ensure(ex)
  local state = ctx.use_state(entry.initial)

  entry.reload = function()
    local code = table.concat(vim.api.nvim_buf_get_lines(entry.bufnr, 0, -1, false), "\n")
    local comp, err = compile(code)
    if comp then
      state.set({ comp = comp })
    else
      -- keep the last good preview under the error message
      state.set({ comp = state.get().comp, err = err })
    end
  end

  local s = state.get()
  local preview = {}
  if s.err then
    preview[#preview + 1] = {
      comp = ui.paragraph,
      props = { text = "error: " .. s.err, style = { text_hl = "ErrorMsg" } },
    }
  end
  if s.comp then
    preview[#preview + 1] = { comp = s.comp, props = {} }
  end

  return {
    comp = ui.col,
    props = { gap = 1 },
    children = {
      { comp = ui.label, props = { text = ex.title, style = { text_hl = "Title" } } },
      { comp = ui.paragraph, props = { text = ex.intro } },
      {
        comp = ui.row,
        props = { gap = 2 },
        children = {
          {
            comp = ui.col,
            props = { gap = 0, grow = 3, max_width = EDITOR_COLS },
            children = {
              {
                -- no explicit width: stretches to the (clamped) column.
                -- insert_on_click: raw_buffers default to normal-mode clicks,
                -- but this one is an editor — tapping it should start typing
                -- (on mobile that's also what summons the keyboard)
                comp = ui.raw_buffer,
                props = {
                  bufnr = entry.bufnr,
                  height = entry.rows,
                  insert_on_click = true,
                  style = { border = true },
                },
              },
              {
                comp = ui.row,
                props = { gap = 1 },
                children = {
                  {
                    comp = ui.button,
                    props = {
                      label = "Reload preview",
                      on_press = function()
                        entry.reload()
                      end,
                    },
                  },
                  { comp = ui.label, props = { text = "or <C-CR> inside the editor", style = { text_hl = "Comment" } } },
                },
              },
            },
          },
          {
            comp = ui.col,
            props = {
              grow = 1,
              min_width = PREVIEW_MIN_COLS,
              style = { border = "rounded", padding = { x = 2, y = 1 } },
              gap = 1,
            },
            children = preview,
          },
        },
      },
      { comp = ui.paragraph, props = { text = ex.details, style = { text_hl = "Comment" } } },
    },
  }
end

return M
