-- The site's look: a hand-rolled midnight palette (deep navy, soft contrast,
-- blue/purple accents) applied straight through nvim_set_hl — no colorscheme
-- plugin, so it works identically in nvim.wasm and a local terminal.
--
-- Three audiences: the page chrome (Normal/Title/Comment/NonText/...), the
-- regex lua syntax inside the playground editors (Statement/String/...), and
-- fibrous' theme hooks (FibrousBorder → LineNr, FibrousBorderFocus →
-- Directory, hover via CursorLine), which color through their default links.

local P = {
  bg = "#1a1b26",
  bg_soft = "#24283b",
  fg = "#c0caf5",
  dim = "#565f89",
  border = "#3b4261",
  blue = "#7aa2f7",
  purple = "#bb9af7",
  cyan = "#7dcfff",
  green = "#9ece6a",
  peach = "#ff9e64",
  yellow = "#e0af68",
  red = "#f7768e",
}

local GROUPS = {
  -- chrome
  Normal = { fg = P.fg, bg = P.bg },
  NormalFloat = { fg = P.fg, bg = P.bg },
  FloatBorder = { fg = P.border, bg = P.bg },
  Title = { fg = P.purple, bold = true },
  Comment = { fg = P.dim, italic = true },
  NonText = { fg = P.border },
  ErrorMsg = { fg = P.red },
  MsgArea = { fg = P.dim, bg = P.bg },
  StatusLine = { fg = P.dim, bg = P.bg },
  Visual = { bg = P.bg_soft },
  CursorLine = { bg = P.bg_soft },
  Search = { bg = P.bg_soft },
  IncSearch = { fg = P.bg, bg = P.peach },
  -- the banner uses Function ("fibrous") over Comment (".nvim")
  Function = { fg = P.blue },
  -- fibrous hooks: borders stay subtle, the focused widget lights up blue
  LineNr = { fg = P.border },
  Directory = { fg = P.blue },
  -- lua regex syntax in the editors
  Statement = { fg = P.purple },
  Keyword = { fg = P.purple },
  String = { fg = P.green },
  Number = { fg = P.peach },
  Constant = { fg = P.peach },
  Boolean = { fg = P.peach },
  Identifier = { fg = P.cyan },
  Special = { fg = P.cyan },
  Operator = { fg = P.fg },
  Type = { fg = P.yellow },
  PreProc = { fg = P.cyan },
  Delimiter = { fg = P.dim },
}

local M = { palette = P }

function M.apply()
  vim.o.termguicolors = true
  for name, attrs in pairs(GROUPS) do
    vim.api.nvim_set_hl(0, name, attrs)
  end
end

return M
