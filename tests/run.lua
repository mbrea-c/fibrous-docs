-- Headless test runner for the site app. Invoked from the repo root:
--   nvim --headless -u NONE -i NONE -l tests/run.lua [path/to/file_spec.lua]
--
-- Mirrors fibrous' own tests/run.lua, with two extra path roots: site/lua
-- (the webapp modules that ship via extraLuaDirs) and the fibrous checkout
-- itself — the sibling ../nui-reactive by default, FIBROUS_PATH to override.
-- That means specs here exercise the site against the LOCAL fibrous tree,
-- not the flake.lock pin (which only matters for `nix build`).

local root = vim.fn.getcwd()
local fibrous = vim.env.FIBROUS_PATH or (root .. "/../nui-reactive")
fibrous = vim.fn.fnamemodify(fibrous, ":p"):gsub("/$", "")

package.path = table.concat({
  root .. "/site/lua/?.lua",
  root .. "/site/lua/?/init.lua",
  fibrous .. "/lua/?.lua",
  fibrous .. "/lua/?/init.lua",
  fibrous .. "/?.lua", -- tests.harness
  package.path,
}, ";")

-- The suite must not depend on the terminal it runs under: the image
-- provider auto-detects from the real environment (TERM, tmux), so a
-- kitty-ish terminal would make every homepage mount transmit real graphics
-- escapes to stderr mid-suite. Pin the provider to text; images_spec
-- overrides it per test (through its own writer). pcall: FIBROUS_PATH may
-- point at a fibrous without fibrous.image.
pcall(function()
  require("fibrous.image").config.provider = "text"
end)

local harness = require("tests.harness")
harness.expose()

local arg_file = _G.arg and _G.arg[1]
local specs
if arg_file and arg_file ~= "" then
  specs = { vim.fn.fnamemodify(arg_file, ":p") }
else
  specs = vim.fn.glob(root .. "/tests/**/*_spec.lua", false, true)
end

table.sort(specs)

if #specs == 0 then
  io.write("no spec files found\n")
  vim.cmd("cquit 1")
end

for _, spec in ipairs(specs) do
  local chunk, load_err = loadfile(spec)
  if not chunk then
    io.write(("ERROR loading %s: %s\n"):format(spec, load_err))
    vim.cmd("cquit 1")
  end
  local ok, err = pcall(chunk)
  if not ok then
    io.write(("ERROR running %s: %s\n"):format(spec, tostring(err)))
    vim.cmd("cquit 1")
  end
end

local results = harness.run()
vim.cmd("cquit " .. (results.failed == 0 and 0 or 1))
