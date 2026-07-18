-- A dependency-free PNG encoder for the playground's live image demo: pure
-- Lua 5.1 (runs identically under LuaJIT and the PUC VM inside nvim.wasm),
-- no zlib, no bit library, no external tools. Compression is the deflate
-- "stored" mode (raw bytes framed in uncompressed blocks) — a valid zlib
-- stream any decoder accepts, at the cost of size, which is fine for the
-- small procedural images the demo generates. CRC32 and adler32 are computed
-- with arithmetic only (xor via a 16x16 nibble table).

local M = {}

-- 4-bit xor lookup, built once: XOR[a][b] for nibbles a, b.
local XOR = {}
for a = 0, 15 do
  XOR[a] = {}
  for b = 0, 15 do
    local r, bit = 0, 1
    local x, y = a, b
    for _ = 1, 4 do
      local xb, yb = x % 2, y % 2
      if xb ~= yb then
        r = r + bit
      end
      x = (x - xb) / 2
      y = (y - yb) / 2
      bit = bit * 2
    end
    XOR[a][b] = r
  end
end

local function bxor8(a, b)
  local al, bl = a % 16, b % 16
  return XOR[(a - al) / 16][(b - bl) / 16] * 16 + XOR[al][bl]
end

local function bxor32(a, b)
  local r, mul = 0, 1
  for _ = 1, 4 do
    local ab, bb = a % 256, b % 256
    r = r + bxor8(ab, bb) * mul
    a = (a - ab) / 256
    b = (b - bb) / 256
    mul = mul * 256
  end
  return r
end

local CRC = {}
for n = 0, 255 do
  local c = n
  for _ = 1, 8 do
    local low = c % 2
    c = (c - low) / 2
    if low == 1 then
      c = bxor32(c, 0xEDB88320)
    end
  end
  CRC[n] = c
end

local function crc32(s)
  local c = 0xFFFFFFFF
  for i = 1, #s do
    local low = c % 256
    c = bxor32((c - low) / 256, CRC[bxor8(low, s:byte(i))])
  end
  return bxor32(c, 0xFFFFFFFF)
end

local function adler32(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + s:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

local function u32be(n)
  local b4 = n % 256
  n = (n - b4) / 256
  local b3 = n % 256
  n = (n - b3) / 256
  local b2 = n % 256
  n = (n - b2) / 256
  return string.char(n % 256, b2, b3, b4)
end

local function chunk(kind, data)
  return u32be(#data) .. kind .. data .. u32be(crc32(kind .. data))
end

-- Raw bytes -> zlib stream: header, stored-deflate blocks (65535-byte max
-- each, final bit on the last), adler32 of the raw data.
local function zlib_stored(raw)
  local out = { "\120\1" }
  local pos = 1
  repeat
    local block = raw:sub(pos, pos + 65534)
    pos = pos + 65535
    local final = pos > #raw
    local len = #block
    out[#out + 1] = string.char(final and 1 or 0, len % 256, (len - len % 256) / 256)
    -- NLEN, the one's complement of LEN
    local nlen = 65535 - len
    out[#out + 1] = string.char(nlen % 256, (nlen - nlen % 256) / 256)
    out[#out + 1] = block
  until final
  out[#out + 1] = u32be(adler32(raw))
  return table.concat(out)
end

local function channel(v)
  v = math.floor(v + 0.5)
  if v < 0 then
    return 0
  elseif v > 255 then
    return 255
  end
  return v
end

-- An 8-bit truecolor PNG: pixel(x, y) -> r, g, b (0-255, clamped and
-- rounded), x and y 0-indexed. Returns the raw PNG bytes (feed them to
-- ui.image's `data` prop, or vim.base64.encode for `b64`).
---@param width integer
---@param height integer
---@param pixel fun(x: integer, y: integer): number, number, number
---@return string
function M.rgb(width, height, pixel)
  local rows = {}
  for y = 0, height - 1 do
    local row = { "\0" } -- filter type 0 (none) per scanline
    for x = 0, width - 1 do
      local r, g, b = pixel(x, y)
      row[#row + 1] = string.char(channel(r), channel(g), channel(b))
    end
    rows[#rows + 1] = table.concat(row)
  end
  local raw = table.concat(rows)
  -- IHDR: dims, bit depth 8, color type 2 (truecolor), default methods
  local ihdr = u32be(width) .. u32be(height) .. "\8\2\0\0\0"
  return "\137PNG\13\10\26\10" .. chunk("IHDR", ihdr) .. chunk("IDAT", zlib_stored(raw)) .. chunk("IEND", "")
end

return M
