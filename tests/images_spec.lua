-- The images playground section: a PNG generated at render time by
-- webapp.pnggen (a dependency-free uncompressed-PNG encoder, so the demo
-- works inside nvim.wasm where there is no zlib and no external tool) and
-- shown through ui.image. In the browser the site forces the kitty provider
-- (the web renderer implements Unicode placeholders); on terminals without
-- image support the component degrades to its alt text.

local mount = require("fibrous.inline.mount")
local pnggen = require("webapp.pnggen")
local dims = require("fibrous.image.dims")
local image = require("fibrous.image")

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function page_text(handle)
  return table.concat(lines_of(handle.bufnr), "\n")
end

local function mount_home()
  vim.o.columns = 200
  vim.o.lines = 60
  return mount.floating(require("webapp"), {}, { width = 180, height = 50, row = 0, col = 0, mode = "scroll" })
end

describe("webapp.pnggen", function()
  it("produces a PNG whose dimensions fibrous can sniff", function()
    local data = pnggen.rgb(6, 4, function(x, y)
      return x * 40, y * 60, 128
    end)
    assert.equal("\137PNG\13\10\26\10", data:sub(1, 8))
    local px = dims.png_b64(vim.base64.encode(data))
    assert.truthy(px)
    assert.equal(6, px.w)
    assert.equal(4, px.h)
  end)

  it("clamps and rounds channel values", function()
    local data = pnggen.rgb(2, 1, function(x)
      if x == 0 then
        return -5, 300, 12.6
      end
      return 0, 0, 0
    end)
    -- decodes as a well-formed PNG regardless of out-of-range channels
    assert.truthy(dims.png_b64(vim.base64.encode(data)))
  end)

  it("matches the externally validated golden encoding", function()
    -- 2x1: a red then a green pixel. The golden was decoded back to those
    -- pixels with an independent PNG reader (python3/zlib) when it was baked,
    -- so byte equality here re-proves the whole container: magic, IHDR,
    -- stored-deflate framing, adler32 and both chunk CRCs.
    local data = pnggen.rgb(2, 1, function(x)
      if x == 0 then
        return 255, 0, 0
      end
      return 0, 255, 0
    end)
    local golden = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAEklEQVR4"
      .. "AQEHAPj/AP8AAAD/AAf/Af/FDuJqAAAAAElFTkSuQmCC"
    assert.equal(golden, vim.base64.encode(data))
  end)
end)

describe("images example", function()
  after_each(function()
    -- reset() clears the writer and refcounts but also restores provider
    -- "auto"; re-pin text (as tests/run.lua does for the whole suite) so no
    -- later mount depends on the real terminal
    image.reset()
    image.config.provider = "text"
  end)

  it("degrades to alt text where the provider is text", function()
    -- force the provider: auto-detection reads the real environment, which
    -- would make this test depend on the terminal the suite runs under
    image.reset()
    image.config.provider = "text"
    local handle = mount_home()
    local text = page_text(handle)
    assert.truthy(text:find("Images, generated live", 1, true))
    -- the alt string appears in the editor (it is part of the example code)
    -- AND in the preview, where it stands in for the image
    local _, alts = text:gsub("images need a kitty%-protocol terminal", "")
    assert.equal(2, alts)
    assert.falsy(text:find(vim.fn.nr2char(0x10EEEE), 1, true))
    handle.unmount()
  end)

  it("renders placeholder cells under a kitty provider (the web path)", function()
    image.reset()
    image.config.provider = "kitty"
    local written = {}
    image.config.writer = function(data)
      written[#written + 1] = data
    end
    local handle = mount_home()
    -- the image was transmitted over the writer (the browser parses this
    -- exact escape stream off stderr)...
    assert.truthy(table.concat(written):find("\27_Ga=T,U=1,f=100", 1, true))
    -- ...and the page text carries U+10EEEE placeholder clusters, with the
    -- alt string only in the editor's source view
    local text = page_text(handle)
    assert.truthy(text:find(vim.fn.nr2char(0x10EEEE), 1, true))
    local _, alts = text:gsub("images need a kitty%-protocol terminal", "")
    assert.equal(1, alts)
    handle.unmount()
  end)
end)
