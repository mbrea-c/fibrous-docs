local docs = require("webapp.md_docs")

describe("optional rendering optimization documentation", function()
  it("explains native opt-in and the independent viewport contract", function()
    local native = docs.load("api/native-markdown.md")
    for _, value in ipairs({ "off by default", "withRustMarkdown", "source_entry", "fall back to Lua" }) do
      assert.truthy(native:find(value, 1, true), "missing native contract: " .. value)
    end
    local viewport = docs.load("api/viewport.md")
    for _, value in ipairs({ "use_range", "sequences", "blank", "reveal", "not the exact word" }) do
      assert.truthy(viewport:find(value, 1, true), "missing viewport contract: " .. value)
    end
  end)
end)
