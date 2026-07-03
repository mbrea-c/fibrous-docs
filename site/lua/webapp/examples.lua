-- The homepage's live examples. Each entry: a title, a short intro shown
-- above the editor/preview pair, the editor's initial code (a chunk that
-- returns a component function), and a longer explanation shown below.

return {
  {
    name = "counter",
    title = "Reactive state",
    intro = "Components are plain functions of state. Change the state, and fibrous "
      .. "re-renders just that subtree — press the buttons (mouse or <CR>) and watch. "
      .. "Then make it your own: edit the code on the left and reload.",
    details = "ctx.use_state gives a component a persistent slot, like React's useState: "
      .. "set() schedules a re-render of that component only, and the reconciler diffs the "
      .. "returned tree against the previous one, patching just the text cells that changed "
      .. "in the underlying buffer. No manual redraws, no window juggling — the cursor even "
      .. "stays where it was.",
    code = [==[
local ui = require("fibrous.inline.components")

return function(ctx)
  local count = ctx.use_state(0)
  local function bump(d)
    return function()
      count.set(count.get() + d)
    end
  end
  return {
    comp = ui.col,
    props = { gap = 1 },
    children = {
      {
        comp = ui.label,
        props = { text = ("Count: %d"):format(count.get()), hl = "Title" },
      },
      {
        comp = ui.row,
        props = { gap = 1 },
        children = {
          { comp = ui.button, props = { label = "-1", on_press = bump(-1) } },
          { comp = ui.button, props = { label = "+1", on_press = bump(1) } },
        },
      },
    },
  }
end
]==],
  },

  {
    name = "todo",
    title = "Cursor-native widgets",
    intro = "Lists, checkboxes and text inputs, all driven by the Neovim cursor: "
      .. "hover with normal motions, toggle with <Space>, and type into the input "
      .. "like any buffer — <CR> submits a new item.",
    details = "The whole page is ONE unmodifiable buffer; widgets are just cells in it, "
      .. "so hjkl, search, counts — everything you know — works for navigation. The text "
      .. "input is the exception: a tiny editable float spliced seamlessly into the layout. "
      .. "Move the cursor into it and it focuses; edit like any buffer; on_submit hands the "
      .. "value back to your component.",
    code = [==[
local ui = require("fibrous.inline.components")

return function(ctx)
  local items = ctx.use_state({
    { text = "ship fibrous", done = true },
    { text = "write the docs", done = false },
  })
  local function update(fn)
    local next = vim.deepcopy(items.get())
    fn(next)
    items.set(next)
  end

  local children = {
    { comp = ui.label, props = { text = "things to do", hl = "Title" } },
  }
  for i, item in ipairs(items.get()) do
    children[#children + 1] = {
      comp = ui.checkbox,
      props = {
        label = item.text,
        checked = item.done,
        on_toggle = function(v)
          update(function(next)
            next[i].done = v
          end)
        end,
      },
    }
  end
  children[#children + 1] = {
    comp = ui.text_input,
    props = {
      border = true,
      on_submit = function(value)
        update(function(next)
          next[#next + 1] = { text = value, done = false }
        end)
      end,
    },
  }
  return { comp = ui.col, props = { gap = 1 }, children = children }
end
]==],
  },

  {
    name = "boxes",
    title = "A CSS-like box model",
    intro = "Rows, columns, borders, padding, gap, grow, align, justify — layout "
      .. "speaks flexbox, rendered entirely as text. Move the cursor over the "
      .. "hoverable chip to see state-driven styling.",
    details = "Every node has margin, border, padding and a content box, laid out by a "
      .. "flex pass over the component tree. Styles are highlight groups: `hl` colors text, "
      .. "`bg` fills rects, `hover_hl` applies while the cursor is inside — the same hit-map "
      .. "that routes clicks and <CR>. Borders come from a theme (rounded, double, single) "
      .. "and restyle per instance.",
    code = [==[
local ui = require("fibrous.inline.components")

return function()
  return {
    comp = ui.col,
    props = { gap = 1 },
    children = {
      {
        comp = ui.row,
        props = { gap = 2 },
        children = {
          {
            comp = ui.label,
            props = { text = "padded", border = true, padding = { x = 3, y = 1 } },
          },
          {
            comp = ui.label,
            props = { text = "double", border = "double", padding = { x = 1 } },
          },
          {
            comp = ui.col,
            props = { border = true, grow = 1, align = "center", justify = "center" },
            children = {
              { comp = ui.label, props = { text = "grow + center" } },
            },
          },
        },
      },
      {
        comp = ui.label,
        props = {
          text = " hover me ",
          role = "button",
          hover_hl = "IncSearch",
          border = "rounded",
        },
      },
    },
  }
end
]==],
  },

  {
    name = "clock",
    title = "Effects & timers",
    intro = "use_effect runs after commit and can return a cleanup — here it arms "
      .. "a libuv timer that ticks state once a second. Yes, the event loop is "
      .. "running; this really is Neovim.",
    details = "Effects follow React's contract: they run after the tree is committed, "
      .. "re-run when their deps change, and their cleanup runs on unmount — so the timer "
      .. "below dies with the component (reload and the old one is gone). vim.uv, autocmds, "
      .. "keymaps: anything in the Neovim API is fair game inside an effect.",
    code = [==[
local ui = require("fibrous.inline.components")

return function(ctx)
  local now = ctx.use_state(os.date("%H:%M:%S"))

  ctx.use_effect(function()
    local timer = vim.uv.new_timer()
    timer:start(1000, 1000, vim.schedule_wrap(function()
      now.set(os.date("%H:%M:%S"))
    end))
    return function()
      timer:stop()
      timer:close()
    end
  end, {})

  return {
    comp = ui.col,
    props = { border = "double", padding = { x = 2, y = 1 } },
    children = {
      { comp = ui.label, props = { text = "it is currently", hl = "Comment" } },
      { comp = ui.label, props = { text = now.get(), hl = "Title" } },
    },
  }
end
]==],
  },
}
