-- Reference data for every builtin component. One entry per builtin, each with
-- a summary, a props table ({ name, type, desc } rows) and a live playground
-- `example` in the exact shape webapp.playground consumes (unique `name` per
-- entry so the playground registry + its <C-CR> keymaps never collide with the
-- Home page examples). components_page renders these as master/detail docs.
--
-- LAYOUT_PROPS below are the flex props every node accepts; each entry lists
-- only the props unique to it, then references the shared layout/style tables.
--
-- `group` sorts the entry in the side-nav: "primitive" (a host leaf the
-- reconciler/layout/flush machinery operate on directly) or "builtin" (an
-- ordinary function component that desugars to primitives by remapping props).
-- `stateful = true` flags a builtin that owns hook state / effects (animation)
-- rather than being a pure prop remap — surfaced as a callout on its doc.

-- The flex/layout props every node accepts (col, row, and every leaf).
local LAYOUT_PROPS = {
	{ "width/height", "integer", "fixed size on an axis (columns/rows)" },
	{ "min_width/max_width", "integer", "clamp the width (responsive shrink/grow)" },
	{ "min_height/max_height", "integer", "clamp the height" },
	{ "grow", "number", "weight for sharing leftover main-axis space (flex-grow; 0 = don't grow)" },
	{ "gap", "integer", "space between children (containers only: col/row/container)" },
	{ "align", "string", "cross-axis alignment of children: stretch (default) | start | center | end" },
	{ "justify", "string", "main-axis distribution: start (default) | center | end | space-between" },
	{ "align_self", "string", "override the parent's `align` for this node alone" },
}

-- The style vocabulary (props.style), shared by every node. The key set is
-- CLOSED — an unknown style key errors (as do the removed flat props hl/bg/etc.
-- at the node top level: styling all lives under props.style).
local STYLE_PROPS = {
	{ "text_hl", "string", "foreground highlight group for the text" },
	{ "hl", "string", "background fill of the whole (border-box) node rect" },
	{ "border_hl", "string", "recolour the border only (wins over a border spec's own hl; stays on the fast path)" },
	{ "border", "bool|string|table", "true|\"rounded\"|\"double\"|\"single\", or a table: { \"rounded\", per-side left/top/…, hl, title }" },
	{ "  border.title", "string|table", "embedded border label: a string, or { text, align = left|center|right, pos = top|bottom, hl }" },
	{ "padding", "table", "inner spacing: { x = n, y = n } or per-side { left, right, top, bottom }" },
	{ "margin", "table", "outer spacing, same shape as padding" },
	{ "_hover", "table", "style keys applied while the cursor hovers the node (merged key-wise)" },
	{ "_focus", "table", "style keys applied while the node (or its subwindow) is focused" },
}

-- The interaction vocabulary: node-level props (not under `style`) that make a
-- node respond to the cursor. Shared reference, surfaced on the API ▸ Interaction
-- tab; button/checkbox/text_input/raw_buffer set the relevant ones for you.
local INTERACTION_PROPS = {
	{ "role", "string", "\"button\" | \"checkbox\" — marks the node interactive (hover cue + activation)" },
	{ "on_press", "fun(x)", "role=\"button\": fired by <CR>/<Space>/click (x = cursor column within the node)" },
	{ "on_toggle", "fun(v)", "role=\"checkbox\": fired with the NEW checked value" },
	{ "on_key", "table", "{ [key] = fun(x) } — app keys routed to the node under the cursor; the key must be listed in the mount `keys` opt (needs no role)" },
}

return {
	{
		id = "col",
		name = "col",
		group = "primitive",
		summary = "A vertical flex container: stacks its children top-to-bottom. The layout "
			.. "primitive everything nests in — gap spaces the children, align positions them "
			.. "across the axis, justify distributes them along it, grow shares leftover space.",
		props = {
			{ "children", "node[]", "the stacked child nodes" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_col",
			title = "col",
			intro = "A column with a gap, a border, and a child that grows to fill.",
			details = "col is the vertical axis of the flex model; row is the horizontal one. "
				.. "Both take gap/align/justify/grow — this is the same box model the Home page's "
				.. "\"CSS-like box model\" example demonstrates.",
			code = [==[
local ui = require("fibrous.inline.components")

return function()
  return {
    comp = ui.col,
    props = { gap = 1, style = { border = "rounded", padding = { x = 2, y = 1 } } },
    children = {
      { comp = ui.label, props = { text = "top", style = { text_hl = "Title" } } },
      { comp = ui.label, props = { text = "middle" } },
      { comp = ui.label, props = { text = "bottom", style = { text_hl = "Comment" } } },
    },
  }
end
]==],
		},
	},

	{
		id = "row",
		name = "row",
		group = "primitive",
		summary = "A horizontal flex container: lays its children left-to-right. Same props as "
			.. "col, different axis — use grow to let one child absorb the leftover width.",
		props = {
			{ "children", "node[]", "the child nodes, laid left-to-right" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_row",
			title = "row",
			intro = "Three chips in a row; the middle one grows to push the third to the edge.",
			details = "justify and align control distribution and cross-axis placement; grow on a "
				.. "single child is the quick way to shove siblings apart.",
			code = [==[
local ui = require("fibrous.inline.components")

return function()
  return {
    comp = ui.row,
    props = { gap = 1 },
    children = {
      { comp = ui.label, props = { text = "[left]" } },
      { comp = ui.col, props = { grow = 1 } },
      { comp = ui.label, props = { text = "[right]" } },
    },
  }
end
]==],
		},
	},

	{
		id = "text",
		name = "text",
		group = "primitive",
		summary = "The ONE host leaf every visible component ultimately renders to. Its `text` "
			.. "may be a plain string OR a rich-text span list — bare strings and { \"chunk\", "
			.. "hl = \"Group\" } tables mixed together. label and paragraph are thin wrappers "
			.. "over it (wrap = false / true).",
		props = {
			{ "text", "string|Span[]", "the content; a span list mixes plain strings and { text, hl } chunks" },
			{ "wrap", "boolean", "wrap to the node width (paragraph) vs. clip to one line (label)" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_text",
			title = "text",
			intro = "A single leaf with a mixed span list — each chunk carries its own highlight.",
			details = "Spans are how one line carries multiple colours without splitting into "
				.. "separate nodes. text_hl on the style is the default for un-highlighted chunks.",
			code = [==[
local ui = require("fibrous.inline.components")

return function()
  return {
    comp = ui.text,
    props = {
      wrap = false,
      text = {
        "status: ",
        { "ok", hl = "DiagnosticOk" },
        "  latency: ",
        { "12ms", hl = "Title" },
      },
    },
  }
end
]==],
		},
	},

	{
		id = "label",
		name = "label",
		group = "builtin",
		summary = "A single, non-wrapping line of text (wrap = false over the text leaf). Use it "
			.. "for headings, keys, chips — anything that should stay on one line and clip rather "
			.. "than reflow.",
		props = {
			{ "text", "string|Span[]", "the line content (plain or spans)" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_label",
			title = "label",
			intro = "Labels as a heading and a bordered chip.",
			details = "Same leaf as text with wrap forced off; reach for paragraph when you want "
				.. "the text to reflow to the available width.",
			code = [==[
local ui = require("fibrous.inline.components")

return function()
  return {
    comp = ui.col,
    props = { gap = 1 },
    children = {
      { comp = ui.label, props = { text = "Heading", style = { text_hl = "Title" } } },
      { comp = ui.label, props = { text = " chip ", style = { border = "rounded" } } },
    },
  }
end
]==],
		},
	},

	{
		id = "paragraph",
		name = "paragraph",
		group = "builtin",
		summary = "Wrapping body text (wrap = true over the text leaf). Give it a width (or let a "
			.. "flex parent size it) and it reflows to fit — the workhorse for prose.",
		props = {
			{ "text", "string|Span[]", "the body text (plain or spans)" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_paragraph",
			title = "paragraph",
			intro = "A paragraph clamped to 40 columns so the wrapping is visible.",
			details = "Wrapping happens at the node's content width, so max_width / a flex parent "
				.. "decides where it breaks. This very docs page is built from paragraphs.",
			code = [==[
local ui = require("fibrous.inline.components")

return function()
  return {
    comp = ui.paragraph,
    props = {
      max_width = 40,
      text = "This is a wrapping paragraph. It reflows to the content width of the "
        .. "node, so shrinking the box rewraps the text rather than clipping it.",
    },
  }
end
]==],
		},
	},

	{
		id = "button",
		name = "button",
		group = "builtin",
		summary = "A pressable chip: label text framed by bracket borders from its theme, fired "
			.. "by <CR> or a click on the cursor's hit-map. Shrink-wraps by default (align_self = "
			.. "\"start\"); pass a width or align_self = \"stretch\" for a full-width button.",
		props = {
			{ "label", "string", "the button text" },
			{ "on_press", "fun()", "called on <CR>/click while the cursor is on the button" },
			{ "theme", "string|false", "restyle key, or false for a bare label with no brackets" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_button",
			title = "button",
			intro = "Press it (mouse or <CR>) — on_press bumps the counter beside it.",
			details = "The brackets are a transparent left/right border from theme.styles.button, "
				.. "not part of the label; theme = false drops them. Hover and activation share the "
				.. "same hit-map as every other interactive node.",
			code = [==[
local ui = require("fibrous.inline.components")

return function(ctx)
  local n = ctx.use_state(0)
  return {
    comp = ui.row,
    props = { gap = 2 },
    children = {
      { comp = ui.button, props = { label = "Bump", on_press = function() n.set(n.get() + 1) end } },
      { comp = ui.label, props = { text = "pressed " .. n.get() .. "x" } },
    },
  }
end
]==],
		},
	},

	{
		id = "checkbox",
		name = "checkbox",
		group = "builtin",
		summary = "A toggle row: a mark glyph + label, flipped by <Space>/<CR>/click. The checked "
			.. "and unchecked marks come from the theme and override per instance via the `marks` "
			.. "prop (bare strings or spans).",
		props = {
			{ "label", "string", "text after the mark" },
			{ "checked", "boolean", "current state (controlled — you own it in state)" },
			{ "on_toggle", "fun(checked)", "called with the NEW value on toggle" },
			{ "marks", "table", "glyph overrides: { checked = ..., unchecked = ... }" },
			{ "theme", "string|false", "restyle key, or false to opt out of theme styling" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_checkbox",
			title = "checkbox",
			intro = "A controlled checkbox — its state lives in use_state; on_toggle updates it.",
			details = "checkbox is controlled: it renders whatever `checked` says, and on_toggle "
				.. "hands you the next value to store. The Home page's todo example wires several "
				.. "of these to a list.",
			code = [==[
local ui = require("fibrous.inline.components")

return function(ctx)
  local on = ctx.use_state(false)
  return {
    comp = ui.checkbox,
    props = {
      label = "enable the thing",
      checked = on.get(),
      on_toggle = function(v) on.set(v) end,
    },
  }
end
]==],
		},
	},

	{
		id = "animation",
		name = "animation",
		group = "builtin",
		stateful = true,
		summary = "Time-driven text: give it a duration and a value(progress) function and it runs "
			.. "the timer, diffs the frames and tears the timer down on unmount. progress loops in "
			.. "[0, 1) — elapsed time modulo duration. A frame only writes when the rendered value "
			.. "actually changes, so it costs almost nothing while nothing moves.",
		props = {
			{ "duration", "number", "loop length in seconds (required, > 0)" },
			{ "value", "fun(p)->text", "maps progress in [0,1) to text/spans (required)" },
			{ "fps", "number", "timer rate; default 30" },
			{ "play", "boolean", "false freezes at the current frame" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_animation",
			title = "animation",
			intro = "A progress readout driven purely by value(progress).",
			details = "value receives progress in [0, 1) and returns what to show; the timer, the "
				.. "frame diffing and the cleanup are handled for you. Each commit re-renders only "
				.. "this leaf — the memoized fast path.",
			code = [==[
local ui = require("fibrous.inline.components")

return function()
  return {
    comp = ui.animation,
    props = {
      duration = 4,
      value = function(p)
        local filled = math.floor(p * 20)
        return {
          "[",
          { string.rep("#", filled), hl = "Title" },
          string.rep("-", 20 - filled),
          ("] %3d%%"):format(math.floor(p * 100)),
        }
      end,
    },
  }
end
]==],
		},
	},

	{
		id = "text_input",
		name = "text_input",
		group = "primitive",
		summary = "An editable single-line (or multi-line) field: a real Neovim buffer spliced "
			.. "into the layout as a float. The cursor glides over it until you enter it (<CR>/i/"
			.. "click); then it edits like any buffer. Edits report through on_change; NORMAL-mode "
			.. "<CR> submits (insert-mode <CR> is a newline, so it composes multi-line).",
		props = {
			{ "value", "string", "initial seed text (the buffer is the source of truth after)" },
			{ "on_change", "fun(value)", "fired on every edit (TextChanged/TextChangedI)" },
			{ "on_submit", "fun(value)", "fired on NORMAL-mode <CR>; insert <CR> is always a plain newline" },
			{ "clear_on_submit", "boolean", "empty the field after on_submit" },
			{ "insert_on_click", "boolean", "click enters insert mode (vs. normal-mode focus)" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_text_input",
			title = "text_input",
			intro = "Type into it, press <Esc> for normal mode, then <CR> — on_submit echoes the value above and clears.",
			details = "Move the cursor into the field to focus it (its border brightens), edit "
				.. "like any buffer, leave by stepping out at an edge or <Esc>. NORMAL-mode <CR> "
				.. "submits; insert-mode <CR> is a plain newline. It is a genuine editable buffer, "
				.. "so all of vim works inside it.",
			code = [==[
local ui = require("fibrous.inline.components")

return function(ctx)
  local last = ctx.use_state("(nothing yet)")
  return {
    comp = ui.col,
    props = { gap = 1 },
    children = {
      { comp = ui.label, props = { text = "submitted: " .. last.get() } },
      {
        comp = ui.text_input,
        props = {
          style = { border = true },
          clear_on_submit = true,
          on_submit = function(v) last.set(v) end,
        },
      },
    },
  }
end
]==],
		},
	},

	{
		id = "raw_buffer",
		name = "raw_buffer",
		group = "primitive",
		summary = "Embed an EXISTING, caller-owned buffer as a widget (an editor, a terminal, a "
			.. "preview). Unlike text_input, fibrous does not own the buffer — you create and free "
			.. "it. render = \"focus\" transcribes the buffer's highlights onto the page and only "
			.. "floats a live editor when entered; render = \"always\" keeps the float on top.",
		props = {
			{ "bufnr", "integer", "the buffer to embed (you own its lifecycle)" },
			{ "height", "integer", "viewport height in rows" },
			{ "render", "string", "\"focus\" (default) | \"always\" — see the Home focus-policies example" },
			{ "wrap", "boolean", "wrap long lines in the mirror; default true" },
			{ "insert_on_click", "boolean", "click enters insert mode" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_raw_buffer",
			title = "raw_buffer",
			intro = "A real lua scratch buffer embedded as a widget — glide over it, <CR> to edit.",
			details = "The buffer is created in a ref and freed in the effect cleanup — raw_buffer "
				.. "never owns it. This is the machinery behind the Home page's live code editors.",
			code = [==[
local ui = require("fibrous.inline.components")

return function(ctx)
  local buf = ctx.use_ref(nil)
  if not buf.current then
    buf.current = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf.current, 0, -1, false, {
      "-- a real, editable buffer",
      "local x = 41",
      "return x + 1",
    })
    vim.bo[buf.current].syntax = "lua"
  end
  ctx.use_effect(function()
    local b = buf.current
    return function() pcall(vim.api.nvim_buf_delete, b, { force = true }) end
  end, {})
  return {
    comp = ui.raw_buffer,
    props = { bufnr = buf.current, height = 5, style = { border = true } },
  }
end
]==],
		},
	},

	{
		id = "container",
		name = "container",
		group = "primitive",
		summary = "A container boundary: its children render into the container's OWN buffer, "
			.. "shown in a float over the boundary box — one fiber tree, N buffers. With a height "
			.. "(or grow) it is a viewport: mode = \"scroll\" (default) lets the content grow and "
			.. "the float scroll natively; mode = \"fixed\" lays out at exactly the viewport height. "
			.. "Without either it auto-sizes to its content.",
		props = {
			{ "children", "node[]", "laid out as a col (gap/align/justify apply)" },
			{ "height", "integer", "viewport height — makes it a scrolling region" },
			{ "mode", "string", "\"scroll\" (default) native scroll | \"fixed\" clip to height" },
			{ "scroll_x", "boolean", "false pins horizontal scroll (leftcol 0) — e.g. a vertical-only transcript" },
			{ "scroll_y", "boolean", "false pins vertical scroll (topline 1)" },
			{ "keys", "string[]", "normal-mode keys routed to descendants' on_key handlers" },
			{ "anchor", "boolean", "keep your place across relayout (cursor when focused, view when not); default true (false opts out)" },
		},
		layout = true,
		style = true,
		example = {
			name = "ref_container",
			title = "container",
			intro = "A fixed-height scroll viewport over a tall list — scroll it with j/k once inside.",
			details = "The children live in the container's own buffer; a height turns it into a "
				.. "natively-scrolling viewport, so long content stays boxed instead of stretching "
				.. "the page. This is how panels keep a transcript scrollable.",
			code = [==[
local ui = require("fibrous.inline.components")

return function()
  local rows = {}
  for i = 1, 30 do
    rows[i] = { comp = ui.label, props = { text = ("line %02d"):format(i) } }
  end
  return {
    comp = ui.container,
    props = { height = 6, mode = "scroll", style = { border = true } },
    children = rows,
  }
end
]==],
		},
	},

	LAYOUT_PROPS = LAYOUT_PROPS,
	STYLE_PROPS = STYLE_PROPS,
	INTERACTION_PROPS = INTERACTION_PROPS,
}
