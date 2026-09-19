-- ============================================
-- LUPI GAMES — menu de cassetes
-- Carrega os mini-games do array fixo abaixo.
-- Ombro L (tecla G) volta ao menu. ESC fecha a janela do emulador.
-- ============================================

local SCREEN_W = 480
local SCREEN_H = 270

local function rgb555(r, g, b)
  return r + (g * 32) + (b * 1024)
end

local MENU_PALETTE = {
  rgb555(0, 0, 0),
  rgb555(2, 3, 8),
  rgb555(4, 8, 16),
  rgb555(8, 18, 28),
  rgb555(20, 24, 28),
  rgb555(28, 30, 31),
  rgb555(8, 24, 28),
  rgb555(28, 22, 6),
}

local function apply_menu_palette()
  for i = 1, #MENU_PALETTE do
    ui.palset(i - 1, MENU_PALETTE[i])
  end
end

local function reset_view()
  if ui.camera then ui.camera() end
  if ui.clip then ui.clip() end
  if ui.fillp then ui.fillp(0, 0, 0, 0, 0, 0, 0, 0) end
end

local function btn_id(name, fallback)
  local v = rawget(_G, name)
  if v ~= nil then return v end
  return fallback
end

local UP = btn_id("UP", 2)
local DOWN = btn_id("DOWN", 3)
local CONFIRM_A = btn_id("BTN_Z", 7)
local CONFIRM_B = btn_id("BTN_Q", 5)
local BACK_L = btn_id("BTN_F", 9)
local BACK_SELECT = 13
local BACK_START = 15

local function pressed(id)
  local v = ui.btnp(id, 0)
  return v and v ~= false and v ~= 0
end

local function want_back()
  return pressed(BACK_L)
    or pressed(BACK_SELECT)
    or pressed(BACK_START)
end

local function want_confirm()
  return pressed(CONFIRM_A) or pressed(CONFIRM_B)
end

local function script_dir()
  if debug and debug.getinfo then
    local src = debug.getinfo(1, "S").source
    if type(src) == "string" and src:sub(1, 1) == "@" then
      local path = src:sub(2)
      local dir = path:match("^(.*)[/\\][^/\\]+$")
      if dir and dir ~= "" then return dir end
    end
  end
  return "."
end

local ROOT = script_dir()

local games = { "joytest", "kof", "pang", "pong", "rain", "snake" }
local cursor = 1
local scroll = 0
local playing = false
local game_tick = nil
local load_error = nil
local ignore_back_until = 0
local frame_now = 0
local orig_package_path = package and package.path or ""
local launcher_update

local VISIBLE = 10
local ROW_H = 16

local function clamp_cursor()
  if #games == 0 then
    cursor = 1
    scroll = 0
    return
  end
  if cursor < 1 then cursor = #games end
  if cursor > #games then cursor = 1 end
  if cursor - 1 < scroll then scroll = cursor - 1 end
  if cursor > scroll + VISIBLE then scroll = cursor - VISIBLE end
  if scroll < 0 then scroll = 0 end
end

local function title_of(name)
  return name:upper()
end

local function load_game(name)
  load_error = nil
  if package then
    package.path = orig_package_path .. ";" .. ROOT .. "/" .. name .. "/?.lua"
    if package.loaded then
      package.loaded.palette = nil
      package.loaded.sprites = nil
    end
  end

  Palette = nil
  update = nil
  reset_view()

  local path = ROOT .. "/" .. name .. "/game.lua"
  local ok, err = pcall(dofile, path)
  if not ok then
    load_error = tostring(err)
    apply_menu_palette()
    reset_view()
    playing = false
    game_tick = nil
    update = launcher_update
    return
  end

  if type(update) ~= "function" then
    load_error = name .. " nao define update()"
    apply_menu_palette()
    reset_view()
    playing = false
    game_tick = nil
    update = launcher_update
    return
  end

  game_tick = update
  playing = true
  ignore_back_until = (frame_now or 0) + 20
  update = launcher_update
end

local function return_to_menu()
  playing = false
  game_tick = nil
  Palette = nil
  if package and package.loaded then
    package.loaded.palette = nil
  end
  if package then
    package.path = orig_package_path
  end
  apply_menu_palette()
  reset_view()
  clamp_cursor()
end

local function draw_menu(frame)
  ui.cls(1)
  ui.rectfill(0, 0, SCREEN_W, 28, 2)
  ui.print("LUPI GAMES", 12, 10, 6)
  ui.print("cassetes", 120, 10, 4)

  if load_error then
    ui.print(load_error, 12, 34, 7)
  elseif #games == 0 then
    ui.print("Nenhuma pasta com game.lua.", 12, 48, 5)
    ui.print("Crie uma pasta ao lado deste menu.", 12, 62, 4)
  else
    ui.print("escolha um mini-game", 12, 36, 4)
    local list_y = 52
    local last = math.min(#games, scroll + VISIBLE)
    for i = scroll + 1, last do
      local y = list_y + (i - 1 - scroll) * ROW_H
      local selected = (i == cursor)
      if selected then
        ui.rectfill(8, y - 3, SCREEN_W - 8, y + 11, 2)
        ui.print(">", 14, y, 6)
        ui.print(title_of(games[i]), 28, y, 5)
      else
        ui.print(title_of(games[i]), 28, y, 4)
      end
    end

    if #games > VISIBLE then
      ui.print((scroll + 1) .. "-" .. last .. "/" .. #games, 400, 36, 4)
    end
  end

  local blink = math.floor((frame or 0) / 30) % 2 == 0
  local hint = "W/S mover   K confirmar   G voltar"
  ui.rectfill(0, SCREEN_H - 18, SCREEN_W, SCREEN_H, 2)
  ui.print(hint, 12, SCREEN_H - 13, blink and 6 or 4)
end

local function menu_tick(frame)
  if pressed(UP) and #games > 0 then
    cursor = cursor - 1
    clamp_cursor()
  elseif pressed(DOWN) and #games > 0 then
    cursor = cursor + 1
    clamp_cursor()
  elseif want_confirm() and games[cursor] then
    load_game(games[cursor])
  end

  draw_menu(frame)
end

launcher_update = function(frame)
  frame_now = frame or 0

  if playing then
    if frame_now > ignore_back_until and want_back() then
      return_to_menu()
      return
    end
    if game_tick then
      local ok, err = pcall(game_tick, frame)
      if not ok then
        load_error = tostring(err)
        return_to_menu()
      end
    end
    return
  end

  menu_tick(frame)
end

apply_menu_palette()
update = launcher_update
