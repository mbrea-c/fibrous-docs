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
        props = { text = ("Count: %d"):format(count.get()), style = { text_hl = "Title" } },
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
    { comp = ui.label, props = { text = "things to do", style = { text_hl = "Title" } } },
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
      style = { border = true },
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
      .. "flex pass over the component tree. All styling lives in the `style` prop, in one "
      .. "vocabulary: `text_hl` colors text, `hl` fills the rect, and `_hover`/`_focus` "
      .. "override any key while the state holds — hover rides the same hit-map that routes "
      .. "clicks and <CR>. Borders come from a theme (rounded, double, single) and restyle "
      .. "per instance.",
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
            props = { text = "padded", style = { border = true, padding = { x = 3, y = 1 } } },
          },
          {
            comp = ui.label,
            props = { text = "double", style = { border = "double", padding = { x = 1 } } },
          },
          {
            comp = ui.col,
            props = { style = { border = true }, grow = 1, align = "center", justify = "center" },
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
          style = { border = "rounded", _hover = { hl = "IncSearch" } },
        },
      },
    },
  }
end
]==],
  },

  {
    name = "markdown",
    title = "Markdown, rendered live",
    intro = "ui.markdown parses markdown in pure Lua — no treesitter, which is why it runs "
      .. "right here in the browser — and renders it as fibrous blocks. The link is a real "
      .. "interactive span: move onto it and press <CR>, or click it. Edit the source and reload.",
    details = "A two-stage pipeline: a pure-Lua parser turns the source into a format-neutral "
      .. "document AST, and the shared renderer lowers that into the same primitives every other "
      .. "component uses. Inline marks map onto Neovim's standard @markup.* groups, and links "
      .. "ride the interactive-span machinery (hover, click, flash-jump), so they compose with "
      .. "the rest of fibrous instead of being a special case. A future format only needs to emit "
      .. "the same AST to reuse all of this.",
    code = [==[
local ui = require("fibrous.inline.components")

return function()
  local src = table.concat({
    "# Markdown, rendered live",
    "",
    "This block is **markdown** *parsed in pure Lua* and rendered as",
    "fibrous blocks, with `inline code` and a",
    "[clickable link](https://example.com).",
    "",
    "- a bullet with `code`",
    "- [x] a finished task",
    "- [ ] a pending task",
    "",
    "| feature | works |",
    "| :------ | :---: |",
    "| tables  | yes   |",
    "| links   | yes   |",
    "",
    "> Blockquotes and fenced code render too:",
    "",
    "```lua",
    "return 41 + 1",
    "```",
    "",
    "And LaTeX math, inline $a^2 + b^2 = c^2$ and display, which nests:",
    "",
    "$$",
    "\\phi = \\frac{1 + \\sqrt{5}}{2}",
    "$$",
    "",
    "$$",
    "\\frac{1}{1 + \\frac{1}{1 + \\frac{1}{x}}}",
    "$$",
    "",
    "Big operators grow with their limits stacked:",
    "",
    "$$",
    "\\sum_{k=1}^{n} \\frac{1}{k^2} = \\frac{\\pi^2}{6}",
    "$$",
    "",
    "Environments lay out as grids, with brackets grown to fit and a",
    "piecewise brace that spans its rows:",
    "",
    "$$",
    "M = \\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}, \\quad \\det M = ad - bc",
    "$$",
    "",
    "$$",
    "|x| = \\begin{cases} x & x \\ge 0 \\\\ -x & x < 0 \\end{cases}",
    "$$",
    "",
    "A limit stacks below, the binomial theorem sums a coefficient, and",
    "vectors carry wide arrows over blackboard and fraktur alphabets:",
    "",
    "$$",
    "f'(x) = \\lim_{h \\to 0} \\frac{f(x + h) - f(x)}{h}",
    "$$",
    "",
    "$$",
    "(x + y)^n = \\sum_{k=0}^{n} \\binom{n}{k} x^k y^{n-k}",
    "$$",
    "",
    "$$",
    "\\overrightarrow{AB} \\in \\mathbb{R}^3, \\quad \\mathfrak{g} = \\mathcal{L}(G)",
    "$$",
  }, "\n")
  return { comp = ui.markdown, props = { text = src } }
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
    props = { style = { border = "double", padding = { x = 2, y = 1 } } },
    children = {
      { comp = ui.label, props = { text = "it is currently", style = { text_hl = "Comment" } } },
      { comp = ui.label, props = { text = now.get(), style = { text_hl = "Title" } } },
    },
  }
end
]==],
  },

  {
    name = "animation",
    title = "Animations",
    intro = "ui.animation maps a looping progress value onto text: give it a duration and a "
      .. "value(progress) function, and it handles the timer, the frame diffing and the "
      .. "teardown. Edit the wave, the width, the glyphs — and reload.",
    details = "value(progress) receives progress in [0, 1) — elapsed time modulo duration — "
      .. "and returns the text or spans to show; the bounce is just a triangle wave inside it. "
      .. "A frame only touches the buffer when the rendered value actually changes, and each "
      .. "commit re-renders only the animation leaf (the memoized fast path), so a 30fps timer "
      .. "costs almost nothing while the dot sits still between cells. This is the same "
      .. "machinery as the clock above: state + effects, packaged.",
    code = [==[
local ui = require("fibrous.inline.components")

local WIDTH = 30

local function bounce(progress)
  -- triangle wave: out and back once per loop
  local t = progress < 0.5 and progress * 2 or 2 - progress * 2
  local pos = math.floor(t * (WIDTH - 1) + 0.5)
  return {
    string.rep(".", pos),
    { "o", hl = "Title" },
    string.rep(".", WIDTH - 1 - pos),
  }
end

return function()
  return {
    comp = ui.col,
    props = { gap = 1 },
    children = {
      {
        comp = ui.animation,
        props = { duration = 1.3, value = bounce },
      },
      {
        comp = ui.animation,
        props = {
          duration = 10,
          fps = 4,
          style = { text_hl = "Comment" },
          value = function(p)
            return ("%3d%% of a 10s loop"):format(math.floor(p * 100))
          end,
        },
      },
    },
  }
end
]==],
  },

  {
    name = "policies",
    title = "Two focus policies",
    intro = "Embedded editors never capture your cursor: hjkl glides straight over them, "
      .. "and <CR> (or i, or a click) is what enters one — the focused widget's border "
      .. "brightens. Below, the same wrapping lua buffer twice: the left widget keeps its "
      .. "live float always visible; the right one shows a highlight-transcribed mirror "
      .. "until you actually enter it. Try gliding, entering, editing, and leaving "
      .. "(hjkl at an edge steps back out).",
    details = "Every subwindow paints a text mirror of its visible slice into the page — "
      .. "wrapped lines, tabs and horizontal scroll reproduced — so the gliding cursor "
      .. "always sits on real characters and yanks copy real text. "
      .. 'render = "focus" (the default) hides the float until you enter the widget and '
      .. "transcribes the buffer's queryable highlights (regex syntax, diagnostics, any "
      .. 'persistent extmarks) onto the mirror; render = "always" keeps the editable '
      .. "float on top at all times. The trade: \"always\" is live down to treesitter "
      .. "fidelity but sits above the page (selections highlight around it), \"focus\" "
      .. "is flat page text until entered. Per-component props — pick per widget.",
    code = [==[
local ui = require("fibrous.inline.components")

local LINES = {
  "-- a real lua buffer, shown twice; this comment wraps in the box",
  "local function greet(name)",
  "  return ('hi, %s!'):format(name)",
  "end",
  "return greet('fibrous')",
}

return function(ctx)
  local bufs = ctx.use_ref(nil)
  if not bufs.current then
    local function make()
      local b = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(b, 0, -1, false, LINES)
      vim.bo[b].syntax = "lua"
      return b
    end
    bufs.current = { make(), make() }
  end
  ctx.use_effect(function()
    local a, b = bufs.current[1], bufs.current[2]
    return function()
      pcall(vim.api.nvim_buf_delete, a, { force = true })
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end, {})

  local function editor(label, bufnr, render)
    return {
      comp = ui.col,
      props = { grow = 1, gap = 1 },
      children = {
        { comp = ui.label, props = { text = label, style = { text_hl = "Title" } } },
        {
          -- wrap is the raw_buffer default: watch the mirror wrap the long
          -- comment exactly like the float does. The border brightens while
          -- the widget is focused.
          comp = ui.raw_buffer,
          props = { bufnr = bufnr, style = { border = true }, render = render, height = #LINES + 3 },
        },
      },
    }
  end
  return {
    comp = ui.row,
    props = { gap = 3 },
    children = {
      editor('render = "always"', bufs.current[1], "always"),
      editor('render = "focus"', bufs.current[2], "focus"),
    },
  }
end
]==],
  },
  {
    name = "images",
    title = "Images, generated live",
    intro = "Inline images are ordinary cells: this PNG is generated in Lua on every "
      .. "render (webapp.pnggen, a zero-dependency encoder) and displayed with ui.image. "
      .. "Shift the palette and a brand new image is encoded, transmitted and painted — "
      .. "edit the math on the left to draw something else entirely.",
    details = "fibrous images ride the kitty graphics protocol with Unicode placeholders: "
      .. "the picture is transmitted once (identified by a content hash, so an unchanged "
      .. "image never re-uploads) and referenced by regular text cells, which is why it "
      .. "scrolls, clips and layers exactly like the text around it. In this browser the "
      .. "nvim-wasm canvas renderer implements the same protocol a real kitty or ghostty "
      .. "terminal speaks; on terminals without image support the component degrades to "
      .. "its alt text. Try it in the native site too (nix run .#native inside kitty).",
    code = [==[
local ui = require("fibrous.inline.components")
local png = require("webapp.pnggen")

return function(ctx)
  local shift = ctx.use_state(0)
  local s = shift.get()
  local data = png.rgb(96, 48, function(x, y)
    local r = 128 + 127 * math.sin((x + s) / 14)
    local g = 128 + 127 * math.sin((y + s) / 7)
    local b = 128 + 127 * math.sin((x + y + s * 2) / 21)
    return r, g, b
  end)
  return {
    comp = ui.col,
    props = { gap = 1 },
    children = {
      {
        comp = ui.image,
        props = {
          data = data,
          cols = 40,
          alt = "[images need a kitty-protocol terminal]",
        },
      },
      {
        comp = ui.button,
        props = {
          label = "Shift the palette",
          on_press = function()
            shift.set(s + 6)
          end,
        },
      },
    },
  }
end
]==],
  },
}
