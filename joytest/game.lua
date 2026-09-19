-- Controller Test Cassette para Lupi
-- Super Famicom em primitivas: capsula larga, cavidades, cruz arredondada.

pcall(function() require("palette") end)

local function rgb555(r, g, b)
  return r + (g * 32) + (b * 1024)
end

if not Palette then
  Palette = {
    rgb555(0, 0, 0), rgb555(0, 0, 0), rgb555(4, 4, 5), rgb555(24, 24, 25),
    rgb555(28, 28, 29), rgb555(19, 19, 20), rgb555(13, 13, 14), rgb555(10, 10, 11),
    rgb555(8, 25, 28), rgb555(6, 22, 8), rgb555(4, 8, 28), rgb555(28, 5, 5),
    rgb555(28, 25, 5), rgb555(8, 8, 9), rgb555(9, 9, 10), rgb555(31, 31, 31),
  }
end

local function btn_id(name, fallback)
  local v = rawget(_G, name)
  if v ~= nil then return v end
  return fallback
end

-- Lupi (docs): Z/X face, F/G extras, Q/E ombros.
-- No Lupinho BTN_X não existe e o fallback 5 é o mesmo id de BTN_Q,
-- então A e L acendiam juntos. Se colidir, usa layout Raylib.
local Z = btn_id("BTN_Z", 4)
local X = rawget(_G, "BTN_X")
local F = btn_id("BTN_F", 12)
local G = btn_id("BTN_G", 13)
local Q = btn_id("BTN_Q", 14)
local E = btn_id("BTN_E", 15)
local A = X or 5
local lupinho = (A == Q) or (X == nil and Q == 5)

local B = {
  left  = btn_id("LEFT", 0),
  right = btn_id("RIGHT", 1),
  up    = btn_id("UP", 2),
  down  = btn_id("DOWN", 3),
  y     = lupinho and E or F,
  b     = Z,
  a     = lupinho and 6 or A,
  x     = lupinho and Q or G,
  l     = lupinho and F or Q,
  r     = lupinho and G or E,
}

local P = 0

local FONT = {
  ["0"] = { "01110", "10001", "10011", "10101", "11001", "10001", "01110" },
  ["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
  ["2"] = { "01110", "10001", "00001", "00010", "00100", "01000", "11111" },
  ["3"] = { "01110", "10001", "00001", "00110", "00001", "10001", "01110" },
  ["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" },
  ["5"] = { "11111", "10000", "11110", "00001", "00001", "10001", "01110" },
  ["6"] = { "01110", "10000", "11110", "10001", "10001", "10001", "01110" },
  ["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
  ["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" },
  ["9"] = { "01110", "10001", "10001", "01111", "00001", "00001", "01110" },
  ["="] = { "00000", "00000", "11111", "00000", "11111", "00000", "00000" },
  A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
  C = { "01110", "10001", "10000", "10000", "10000", "10001", "01110" },
  E = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" },
  F = { "11111", "10000", "10000", "11110", "10000", "10000", "10000" },
  I = { "01110", "00100", "00100", "00100", "00100", "00100", "01110" },
  M = { "10001", "11011", "10101", "10101", "10001", "10001", "10001" },
  N = { "10001", "11001", "10101", "10011", "10001", "10001", "10001" },
  O = { "01110", "10001", "10001", "10001", "10001", "10001", "01110" },
  P = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
  R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
  S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
  T = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
  U = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" },
}

local function glyph(ch, x, y, scale, color)
  local rows = FONT[ch]
  if not rows then return x + 6 * scale end
  for row = 1, 7 do
    local bits = rows[row]
    for col = 1, 5 do
      if bits:sub(col, col) == "1" then
        local px = x + (col - 1) * scale
        local py = y + (row - 1) * scale
        ui.rectfill(px, py, px + scale, py + scale, color)
      end
    end
  end
  return x + 6 * scale
end

local function text_big(str, x, y, scale, color)
  for i = 1, #str do
    x = glyph(str:sub(i, i), x, y, scale, color)
  end
end

local function text_w(str, scale)
  return #str * 6 * scale
end

local function held(id)
  local v = ui.btn(id, P)
  return v and v ~= false and v ~= 0
end

local function apply_palette()
  for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
  end
end

-- Capsula: dois semicirculos + retangulo (formato do SFC, nao "oito").
local function stadium(cx, cy, w, h, color)
  local r = math.floor(h / 2)
  local x0 = cx - math.floor(w / 2)
  local x1 = cx + math.floor(w / 2)
  local y0 = cy - r
  local y1 = cy + r
  ui.rectfill(x0 + r, y0, x1 - r, y1, color)
  ui.circfill(x0 + r, cy, r, color)
  ui.circfill(x1 - r, cy, r, color)
end

-- Capsula inclinada (~45 graus), Select/Start.
local function slash_pill(x, y, len, rad, color)
  for i = 0, len do
    ui.circfill(x + i, y - i, rad, color)
  end
end

-- Braco da cruz com ponta redonda.
local function plus_arm(cx, cy, dir, arm, th, color)
  if dir == "up" then
    ui.rectfill(cx - th, cy - arm, cx + th, cy + th, color)
    ui.circfill(cx, cy - arm, th, color)
  elseif dir == "down" then
    ui.rectfill(cx - th, cy - th, cx + th, cy + arm, color)
    ui.circfill(cx, cy + arm, th, color)
  elseif dir == "left" then
    ui.rectfill(cx - arm, cy - th, cx + th, cy + th, color)
    ui.circfill(cx - arm, cy, th, color)
  else
    ui.rectfill(cx - th, cy - th, cx + arm, cy + th, color)
    ui.circfill(cx + arm, cy, th, color)
  end
end

local function arrow(cx, cy, dir, color)
  if dir == "up" then
    ui.trisfill(cx, cy - 4, cx - 4, cy + 1, cx + 4, cy + 1, color)
  elseif dir == "down" then
    ui.trisfill(cx, cy + 4, cx - 4, cy - 1, cx + 4, cy - 1, color)
  elseif dir == "left" then
    ui.trisfill(cx - 4, cy, cx + 1, cy - 4, cx + 1, cy + 4, color)
  else
    ui.trisfill(cx + 4, cy, cx - 1, cy - 4, cx - 1, cy + 4, color)
  end
end

-- Ombro L/R: pílula baixa e reta no topo, como no cassete (não segue o arco).
local function shoulder_bar(x0, y0, x1, y1, color)
  local rad = math.floor((y1 - y0) / 2)
  ui.rectfill(x0 + rad, y0, x1 - rad, y1, color)
  ui.circfill(x0 + rad, y0 + rad, rad, color)
  ui.circfill(x1 - rad, y0 + rad, rad, color)
end

local function draw_logo()
  local s = 4
  local super, fami = "SUPER", "FAMICOM"
  local x = math.floor((480 - text_w(super, s)) / 2)
  local cols = { 11, 9, 12, 10, 12 }
  for i = 1, #super do
    x = glyph(super:sub(i, i), x, 8, s, cols[i])
  end
  x = math.floor((480 - text_w(fami, s)) / 2)
  local fcols = { 7, 15, 10, 11, 7, 7, 7 }
  for i = 1, #fami do
    x = glyph(fami:sub(i, i), x, 40, s, fcols[i])
  end
end

local function draw_controller(st)
  local cx, cy = 240, 162
  local w, h = 304, 126
  local r = math.floor(h / 2)
  local lx = cx - math.floor(w / 2) + r
  local rx = cx + math.floor(w / 2) - r

  stadium(cx, cy, w + 6, h + 6, 2)
  stadium(cx, cy, w, h, 3)

  -- brilho na borda superior do meio
  ui.rectfill(cx - 70, cy - r + 3, cx + 70, cy - r + 10, 4)

  local top = cy - r + 4
  local sh = 13
  shoulder_bar(lx - r + 22, top, lx + 20, top + sh, st.l and 4 or 5)
  shoulder_bar(rx - 20, top, rx + r - 22, top + sh, st.r and 4 or 5)

  ui.print("Nintendo", cx - 28, cy - 38, 13)
  ui.print("SUPER LUPINHO", cx - 40, cy - 28, 13)

  -- D-pad
  local dx, dy = lx - 4, cy + 8
  ui.circfill(dx, dy, 34, 5)
  ui.circfill(dx, dy, 30, 6)
  local arm, th = 16, 8
  local dirs = { "up", "down", "left", "right" }
  for i = 1, 4 do
    local d = dirs[i]
    plus_arm(dx, dy, d, arm, th, st[d] and 8 or 7)
  end
  ui.circfill(dx, dy, th - 1, 7)
  arrow(dx, dy - 12, "up", st.up and 15 or 13)
  arrow(dx, dy + 12, "down", st.down and 15 or 13)
  arrow(dx - 12, dy, "left", st.left and 15 or 13)
  arrow(dx + 12, dy, "right", st.right and 15 or 13)

  -- Select / Start
  slash_pill(cx - 28, cy + 14, 16, 5, 14)
  slash_pill(cx + 6, cy + 14, 16, 5, 14)
  ui.print("SELECT", cx - 40, cy + 24, 13)
  ui.print("START", cx + 8, cy + 24, 13)

  -- face
  local fx, fy = rx + 4, cy + 8
  ui.circfill(fx, fy, 38, 5)
  ui.circfill(fx, fy, 34, 6)

  local function face(bx, by, dim, lit, on, label, lx2, ly2)
    ui.circfill(bx, by, 11, on and lit or dim)
    ui.print(label, lx2, ly2, 13)
  end

  face(fx, fy - 16, 10, 10, st.x, "X", fx + 12, fy - 28)
  face(fx + 16, fy, 11, 11, st.a, "A", fx + 26, fy - 6)
  face(fx, fy + 16, 12, 12, st.b, "B", fx + 12, fy + 22)
  face(fx - 16, fy, 9, 9, st.y, "Y", fx - 28, fy + 10)
  if st.x then ui.circfill(fx, fy - 16, 4, 15) end
  if st.a then ui.circfill(fx + 16, fy, 4, 15) end
  if st.b then ui.circfill(fx, fy + 16, 4, 15) end
  if st.y then ui.circfill(fx - 16, fy, 4, 15) end
end

local start_frame = nil

function update(frame)
  apply_palette()
  if start_frame == nil then start_frame = frame or 0 end

  local st = {
    up    = held(B.up),
    down  = held(B.down),
    left  = held(B.left),
    right = held(B.right),
    y     = held(B.y),
    b     = held(B.b),
    a     = held(B.a),
    x     = held(B.x),
    l     = held(B.l),
    r     = held(B.r),
  }

  local seconds = math.floor(((frame or 0) - start_frame) / 60)
  if seconds < 0 then seconds = 0 end

  ui.cls(1)
  draw_logo()
  draw_controller(st)

  local label = "TIME=" .. string.format("%02d", seconds % 100)
  text_big(label, math.floor((480 - text_w(label, 3)) / 2), 236, 3, 15)
  ui.print("NINTENDO", 408, 252, 15)
end
