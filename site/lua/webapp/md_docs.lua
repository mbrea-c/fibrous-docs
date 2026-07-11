-- Loader for long-form doc prose kept as MARKDOWN files (site/lua/webapp/docs/
-- *.md), so humans edit real markdown instead of Lua string literals. The pages
-- render the result with ui.markdown.
--
-- The .md files are read from a path computed off THIS module's own source, so
-- there is no runtimepath lookup and no build-time codegen: the files sit next
-- to this module, and extraLuaDirs copies the whole site/lua tree into the
-- config dir (on rtp) for the WASM build, so the same relative layout resolves
-- natively (tests, `nix run .#native`) and in the browser. Results are cached.

local M = {}

local dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "docs/"
local cache = {}

-- Load the markdown file `name` (relative to site/lua/webapp/docs/), or "" if
-- it cannot be read (so a missing file degrades to an empty section, never an
-- error).
---@param name string  e.g. "architecture/overview.md"
---@return string
function M.load(name)
  if cache[name] == nil then
    local ok, lines = pcall(vim.fn.readfile, dir .. name)
    cache[name] = (ok and lines) and table.concat(lines, "\n") or ""
  end
  return cache[name]
end

return M
