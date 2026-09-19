-- Pang
-- Converted from the SDL2 clone (320x240) to Lupi (480x270).
-- Source art is PNG in img/ (same as caio-pernocas).
-- require "sprites" / require "palette" are filled in by lupi-codec.
-- LEFT/RIGHT move, UP/DOWN ladders, BTN_Z / BTN_X shoot.

local SCREEN_W = 480
local SCREEN_H = 270
local ORIG_W = 320
local ORIG_H = 240
local SCALE = 1
local OX = math.floor((SCREEN_W - ORIG_W) / 2)
local OY = math.floor((SCREEN_H - ORIG_H) / 2)
local FLOOR = 200

local MAX_LEVEL = 25
local MAX_BALL = 32
local MAX_PLATFORMS = 50
local MAX_LADDER = 10
local MAX_SHOOT = 15
local MAX_BONUS = 5
local MAX_OBJECTS = 10
local GRAV = 0.5

local BIG, NORMAL, SMALL, MICRO = 1, 2, 3, 4
local WPN_NORMAL, WPN_DOUBLE, WPN_GLUE = 1, 2, 3
local DIR_L, DIR_R, DIR_U, DIR_D, DIR_STOP = -1, 1, -1, 1, 0
local TOUCH_H, TOUCH_V = 1, 2
local BONUS_BOOM, BONUS_FREEZE, BONUS_LIFE, BONUS_PROT = 5, 6, 7, 8
local OBJ_MUL, OBJ_1UP = 1, 6
local PF_INC, PF_CASS, PF_CASSV, PF_INCV = 20, 21, 22, 23
local PF_MINC, PF_MCASS, PF_UINC, PF_UCASS = 24, 25, 26, 27
local RND = 99

local ST_TITLE, ST_PLAY, ST_DEATH, ST_NEXT, ST_OVER = 5, 0, 1, 4, 2
local P_LEFT, P_RIGHT, P_STOP, P_LADDER = 1, 2, 8, 16
local A_SHOOT, A_L1, A_L2, A_L3 = 10, 11, 12, 13
local A_R1, A_R2, A_R3, A_DEAD, A_STOP = 14, 15, 16, 17, 18
local A_LAD1, A_LAD2 = 30, 31

local BALL_SIZE = {
  [BIG] = { w = 48, h = 40, xbox = 6, ybox = 4, hbox = 34, lbox = 38 },
  [NORMAL] = { w = 32, h = 26, xbox = 3, ybox = 3, hbox = 20, lbox = 26 },
  [SMALL] = { w = 16, h = 14, xbox = 1, ybox = 1, hbox = 11, lbox = 13 },
  [MICRO] = { w = 8, h = 7, xbox = 1, ybox = 1, hbox = 5, lbox = 6 },
}

local PF_SIZE = {
  [PF_INC] = { w = 32, h = 8 },
  [PF_CASS] = { w = 32, h = 8 },
  [PF_CASSV] = { w = 8, h = 32 },
  [PF_INCV] = { w = 8, h = 32 },
  [PF_MINC] = { w = 16, h = 8 },
  [PF_MCASS] = { w = 16, h = 8 },
  [PF_UINC] = { w = 8, h = 8 },
  [PF_UCASS] = { w = 8, h = 8 },
}

local THEMES = {
  { sky = 1, wall = 2, floor = 3 },
  { sky = 16, wall = 17, floor = 18 },
  { sky = 19, wall = 20, floor = 21 },
  { sky = 22, wall = 23, floor = 24 },
  { sky = 1, wall = 25, floor = 3 },
  { sky = 16, wall = 2, floor = 18 },
  { sky = 19, wall = 17, floor = 21 },
  { sky = 22, wall = 20, floor = 24 },
  { sky = 1, wall = 23, floor = 3 },
  { sky = 16, wall = 25, floor = 18 },
  { sky = 19, wall = 2, floor = 21 },
  { sky = 22, wall = 17, floor = 24 },
  { sky = 1, wall = 20, floor = 3 },
}

local function rgb555(r, g, b)
  return r + (g * 32) + (b * 1024)
end

local function btn_id(name, fallback)
  local v = rawget(_G, name)
  if v ~= nil then return v end
  return fallback
end

local UP = btn_id("UP", 2)
local DOWN = btn_id("DOWN", 3)
local LEFT = btn_id("LEFT", 0)
local RIGHT = btn_id("RIGHT", 1)
local Z = btn_id("BTN_Z", 4)
local X = rawget(_G, "BTN_X")

local function game_dir()
  if debug and debug.getinfo then
    local src = debug.getinfo(1, "S").source
    if type(src) == "string" and src:sub(1, 1) == "@" then
      local dir = src:sub(2):match("^(.*)[/\\][^/\\]+$")
      if dir and dir ~= "" then return dir end
    end
  end
  return "./pang"
end

local DIR = game_dir()
pcall(function()
  require "palette"
  require "sprites"
end)
if type(Palette) ~= "table" then
  Palette = { 0x0000, 0x0000, rgb555(6, 14, 24), rgb555(28, 30, 31) }
end

local function pal()
  for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
  end
end

local Img = (type(Sprites) == "table" and Sprites.img) or {}

local function asset(name, w, h)
  if Img[name] then return Img[name] end
  return { path = DIR .. "/img/" .. name, width = w, height = h, ntiles = 1 }
end

local SPR = {
  player = {
    [A_R1] = asset("player_r1", 31, 32),
    [A_R2] = asset("player_r2", 31, 32),
    [A_R3] = asset("player_r3", 31, 32),
    [A_L1] = asset("player_l1", 31, 32),
    [A_L2] = asset("player_l2", 31, 32),
    [A_L3] = asset("player_l3", 31, 32),
    [A_SHOOT] = asset("player_shoot", 31, 32),
    [A_STOP] = asset("player_shoot", 31, 32),
    [A_DEAD] = asset("player_dead", 48, 40),
    [A_LAD1] = asset("player_lad1", 26, 32),
    [A_LAD2] = asset("player_lad2", 26, 32),
  },
  ball = {
    [BIG] = asset("ball_big", 48, 40),
    [NORMAL] = asset("ball_normal", 32, 26),
    [SMALL] = asset("ball_small", 16, 14),
    [MICRO] = asset("ball_micro", 8, 7),
  },
  pf = {
    [PF_INC] = asset("pf_inc", 32, 8),
    [PF_CASS] = asset("pf_cass", 32, 8),
    [PF_CASSV] = asset("pf_cassv", 8, 32),
    [PF_INCV] = asset("pf_incv", 8, 32),
    [PF_MINC] = asset("pf_minc", 16, 8),
    [PF_MCASS] = asset("pf_mcass", 16, 8),
    [PF_UINC] = asset("pf_uinc", 8, 8),
    [PF_UCASS] = asset("pf_ucass", 8, 8),
  },
  bonus = {
    [WPN_DOUBLE] = asset("bonus_double", 18, 18),
    [WPN_GLUE] = asset("bonus_glue", 18, 18),
    [BONUS_BOOM] = asset("bonus_boom", 18, 18),
    [BONUS_FREEZE] = asset("bonus_freeze", 18, 18),
    [BONUS_LIFE] = asset("bonus_life", 18, 18),
    [BONUS_PROT] = asset("bonus_prot", 18, 18),
  },
  ladder = asset("ladder", 22, 4),
  wire = asset("wire", 9, 200),
  glue = asset("glue", 9, 200),
  shield = asset("shield", 43, 43),
  life = asset("hud_life", 18, 18),
  label_score = asset("label_score", 38, 11),
  label_level = asset("label_level", 36, 14),
  obj_1up = asset("obj_1up", 21, 13),
  obj_x = asset("obj_x", 7, 9),
  gameover = asset("gameover", 130, 15),
  title = asset("title", 320, 240),
  next1 = asset("nextlevel1", 320, 240),
  next2 = asset("nextlevel2", 320, 240),
  digit = {},
  fond = {},
}

for i = 0, 9 do
  SPR.digit[i] = asset("digit" .. i, 13, 13)
end
for i = 1, 13 do
  SPR.fond[i] = asset("fond" .. i, 320, 240)
end

local function sx(x)
  return math.floor(OX + x * SCALE)
end

local function sy(y)
  return math.floor(OY + y * SCALE)
end

local function blit(ref, x, y)
  if not ref or not ui.spr then return false end
  ui.spr(ref, sx(x), sy(y))
  return true
end

local function blit_clip(ref, x, y, w, h)
  if not ref or not ui.spr then return false end
  if ui.clip then
    ui.clip(sx(x), sy(y), math.max(1, w), math.max(1, h))
  end
  ui.spr(ref, sx(x), sy(y))
  if ui.clip then ui.clip() end
  return true
end

local function fond_for(level)
  local id = math.floor((level - 1) / 3) + 1
  if id < 1 then id = 1 end
  if id > 13 then id = 13 end
  return SPR.fond[id]
end

local function draw_number(n, x, y)
  local s = tostring(math.floor(n))
  for i = 1, #s do
    local d = tonumber(s:sub(i, i))
    blit(SPR.digit[d], x + (i - 1) * 6, y)
  end
end

local function held(id, p)
  if id == nil then return false end
  local v = ui.btn(id, p or 0)
  return v and v ~= false and v ~= 0
end

local function pressed(id, p)
  if id == nil then return false end
  local v = ui.btnp(id, p or 0)
  return v and v ~= false and v ~= 0
end

local function beep(note)
  if sfx and sfx.fx then
    pcall(sfx.fx, 0, note or 60, 0.5)
  end
end

local function gfill(x, y, w, h, c)
  local x0, y0 = sx(x), sy(y)
  local x1, y1 = sx(x + w) - 1, sy(y + h) - 1
  if x1 < x0 then x1 = x0 end
  if y1 < y0 then y1 = y0 end
  ui.rectfill(x0, y0, x1, y1, c)
end

local function gcirc(x, y, w, h, c)
  local cx = sx(x + w * 0.5)
  local cy = sy(y + h * 0.5)
  local r = math.max(1, math.floor(math.min(w, h) * SCALE * 0.5))
  ui.circfill(cx, cy, r, c)
  return cx, cy, r
end

local function gbox(x, y, w, h, c)
  local x0, y0 = sx(x), sy(y)
  local x1, y1 = sx(x + w) - 1, sy(y + h) - 1
  if ui.line then
    ui.line(x0, y0, x1, y0, c)
    ui.line(x1, y0, x1, y1, c)
    ui.line(x1, y1, x0, y1, c)
    ui.line(x0, y1, x0, y0, c)
  end
end

local function aabb(x1, y1, h1, l1, x2, y2, h2, l2)
  if x1 + l1 < x2 then return false end
  if x1 > x2 + l2 then return false end
  if y1 + h1 < y2 then return false end
  if y1 > y2 + h2 then return false end
  return true
end

local function theme_of(level)
  local i = math.floor((level - 1) / 3) + 1
  return THEMES[((i - 1) % #THEMES) + 1]
end

local function resolve_bonus(v)
  if v == RND then return get_random_bonus() end
  return v or 0
end

local gbl_timer = 1
local gbl_evt = ST_TITLE
local onetwo = 0
local current_level = 1
local death_cpt = 0
local over_cpt = 0
local wait_release = false

local player = {}
local balls = {}
local pform = {}
local ladders = {}
local shoots = {}
local bonuses = {}
local objs = {}

local function pool(n)
  local t = {}
  for i = 1, n do
    t[i] = { active = false }
  end
  return t
end

local function free_slot(t)
  for i = 1, #t do
    if not t[i].active then return i end
  end
  return nil
end

function get_random_bonus()
  local i = math.random(0, 4)
  if i == 0 then return BONUS_BOOM end
  if i == 1 then return BONUS_FREEZE end
  if i == 2 then return BONUS_PROT end
  if i == 3 then return WPN_DOUBLE end
  return WPN_GLUE
end

local function ball_w(b)
  return BALL_SIZE[b.type].w
end

local function ball_h(b)
  return BALL_SIZE[b.type].h
end

local function create_ball(posx, posy, type_ball, hdir, vdir)
  local i = free_slot(balls)
  if not i then return 1 end
  local spec = {
    [BIG] = { hmax = 180, hcpt = 160, vel = -10.0, vel_cst = 12.5 },
    [NORMAL] = { hmax = 120, hcpt = 100, vel = -10.0, vel_cst = 10.0 },
    [SMALL] = { hmax = 80, hcpt = 60, vel = -8.0, vel_cst = 8.0 },
    [MICRO] = { hmax = 60, hcpt = 30, vel = -6.5, vel_cst = 6.5 },
  }
  local s = spec[type_ball]
  local sz = BALL_SIZE[type_ball]
  local b = balls[i]
  b.posx, b.posy = posx, posy
  b.last_posx, b.last_posy = posx, posy
  b.hauteurmax, b.hauteurmax_cpt = s.hmax, s.hcpt
  b.active = true
  b.xbox, b.ybox, b.hbox, b.lbox = sz.xbox, sz.ybox, sz.hbox, sz.lbox
  b.type = type_ball
  b.bonus, b.bonus_parent = 0, 0
  b.vel, b.vel_cst, b.move = s.vel, s.vel_cst, 2
  b.nbtouch, b.had_col = 0, 0
  if hdir == DIR_L then
    b.move = -b.move
  end
  if vdir == DIR_U then
    b.vel = -b.vel
  end
  return i
end

local function create_platform(x, y, typ, bonus)
  local i = free_slot(pform)
  if not i then return 1 end
  local sz = PF_SIZE[typ]
  local p = pform[i]
  p.active = true
  p.posx, p.posy = x, y
  p.largeur, p.hauteur = sz.w, sz.h
  p.type = typ
  p.bonus = resolve_bonus(bonus)
  return i
end

local function create_ladder(x, y, rungs)
  local i = free_slot(ladders)
  if not i then return 1 end
  local L = ladders[i]
  L.active = true
  L.posx, L.posy = x, y
  L.nb_rungs = rungs
  L.hauteur = 4 * rungs
  L.largeur = 22
  L.pad_haut_x, L.pad_haut_y = x, y - 4
  L.pad_haut_l, L.pad_haut_h = 22, 4
  L.pad_mil_x, L.pad_mil_y = x, y
  L.pad_mil_l, L.pad_mil_h = 22, L.hauteur - 4
  L.pad_bas_x, L.pad_bas_y = x, y + L.hauteur - 4
  L.pad_bas_l, L.pad_bas_h = 22, 4
  return i
end

local function create_bonus(typ, x, y)
  local i = free_slot(bonuses)
  if not i then return 1 end
  local b = bonuses[i]
  b.posx, b.posy = x, y
  b.xbox, b.ybox, b.hbox, b.lbox = 0, 0, 18, 18
  b.type = typ
  b.active = true
  b.etat = DIR_D
  b.life = 200
  return i
end

local function create_object(typ, x, y, value)
  local i = free_slot(objs)
  if not i then return end
  local o = objs[i]
  o.type, o.posx, o.posy, o.value = typ, x, y, value
  o.active = true
  if typ == OBJ_MUL then
    o.cpt = 20
  else
    o.cpt = 100
  end
end

local function create_shoot(typ)
  local i = free_slot(shoots)
  if not i then return end
  local s = shoots[i]
  s.posx = player.posx + 12
  s.posy = player.posy
  s.xbox, s.ybox, s.hbox, s.lbox = 0, 0, 0, 9
  s.type = typ
  s.active = true
  s.duree = -1
  s.posy_depart = player.posy + 32
  beep(72)
end

local function clear_world()
  balls = pool(MAX_BALL)
  pform = pool(MAX_PLATFORMS)
  ladders = pool(MAX_LADDER)
  shoots = pool(MAX_SHOOT)
  bonuses = pool(MAX_BONUS)
  objs = pool(MAX_OBJECTS)
end

local function init_player()
  player.posx = 150
  player.posy = FLOOR - 32
  player.xbox, player.ybox, player.hbox, player.lbox = 4, 2, 28, 18
  player.nblive = 3
  player.weapon = WPN_NORMAL
  player.score = 0
  player.nbtir = 0
  player.etat = P_STOP
  player.old_etat = -1
  player.anim = A_R1
  player.anim_cpt = 0
  player.derniere_balle = 0
  player.multiplicateur = 1
  player.shoot_timer = 0
  player.bonus_boom = 0
  player.bonus_freeze = 0
  player.bonus_life = 0
  player.bonus_life_level = -1
  player.bonus_protection = 0
  player.bonus_protection_timer = -1
  player.en_descente = 0
end

local function reinit_player()
  local score = player.score
  local lives = player.nblive
  local life_lv = player.bonus_life_level
  init_player()
  player.score = score
  player.nblive = lives
  player.bonus_life_level = life_lv
end

local function explode_ball(a)
  local src = balls[a]
  if not src.active then return end
  beep(55)
  if src.type < MICRO then
    local t1 = create_ball(src.posx, src.posy, src.type + 1, DIR_L, DIR_U)
    balls[t1].hauteurmax_cpt = balls[t1].hauteurmax - 20
    balls[t1].vel = 2.0
    if src.bonus_parent ~= 0 then
      balls[t1].bonus = src.bonus_parent
    end
    local t2 = create_ball(src.posx, src.posy, src.type + 1, DIR_R, DIR_U)
    balls[t2].hauteurmax_cpt = balls[t2].hauteurmax - 20
    balls[t2].vel = 2.0
  end
  if src.bonus ~= 0 then
    create_bonus(src.bonus, math.floor(src.posx) + 10, math.floor(src.posy) + 10)
  end
  src.active = false
end

local function explode_all()
  local order = { BIG, NORMAL, SMALL }
  for _, typ in ipairs(order) do
    for i = 1, MAX_BALL do
      if balls[i].active and balls[i].type == typ then
        explode_ball(i)
        return
      end
    end
  end
  player.bonus_boom = 0
end

local function ball_vs_platform(b, p)
  if not b.active or not p.active then return 0 end
  local bw, bh = ball_w(b), ball_h(b)
  local x1, y1 = b.posx, b.posy
  local x2, y2 = p.posx, p.posy
  local w2, h2 = p.largeur, p.hauteur
  if x1 > x2 + w2 or x1 + bw < x2 or y1 > y2 + h2 or y1 + bh < y2 then
    return 0
  end
  local rx1 = math.max(x1, x2)
  local ry1 = math.max(y1, y2)
  local rx2 = math.min(x1 + bw, x2 + w2)
  local ry2 = math.min(y1 + bh, y2 + h2)
  local lw, lh = rx2 - rx1, ry2 - ry1
  local ligne, cote = 0, 0
  if lw < lh then
    ligne = 2
    cote = (rx1 == x2) and 3 or 4
  elseif lw > lh then
    ligne = 1
  end
  if b.move > 0 then
    if cote == 4 then return TOUCH_H end
    if cote == 3 then return TOUCH_V end
  else
    if cote == 3 then return TOUCH_H end
    if cote == 4 then return TOUCH_V end
  end
  if ligne == 1 then return TOUCH_H end
  if ligne == 2 then return TOUCH_V end
  return TOUCH_V
end

local function ball_vs_border(b)
  local hit = false
  local bw, bh = ball_w(b), ball_h(b)
  if b.posy >= FLOOR - bh then
    b.vel = b.vel_cst
    b.posy = FLOOR - bh
    hit = true
  end
  if b.posy < 8 then
    b.posy = 8
    hit = true
  end
  if b.posx <= 8 then
    b.move = -b.move
    b.posx = 8
    hit = true
  end
  if b.posx >= (ORIG_W - 8) - bw then
    b.move = -b.move
    b.posx = (ORIG_W - 8) - bw
    hit = true
  end
  return hit
end

local function pop_ball(b)
  if b.type < MICRO then
    local tmp = create_ball(b.posx, b.posy, b.type + 1, DIR_L, DIR_U)
    if player.bonus_freeze > 0 then
      local oldx, oldy = b.posx, b.posy
      balls[tmp].posx = b.posx + ball_w(balls[tmp])
      local blocked = false
      for p = 1, MAX_PLATFORMS do
        if pform[p].active and ball_vs_platform(balls[tmp], pform[p]) ~= 0 then
          blocked = true
        end
      end
      if blocked then
        balls[tmp].posx, balls[tmp].posy = oldx, oldy
      end
    end
    balls[tmp].hauteurmax_cpt = balls[tmp].hauteurmax - 20
    balls[tmp].vel = 2.0
    if b.bonus_parent ~= 0 then
      balls[tmp].bonus = b.bonus_parent
    end
    tmp = create_ball(b.posx, b.posy, b.type + 1, DIR_R, DIR_U)
    balls[tmp].hauteurmax_cpt = balls[tmp].hauteurmax - 20
    balls[tmp].vel = 2.0
  end
  if player.derniere_balle == b.type then
    player.multiplicateur = player.multiplicateur + 1
  else
    player.multiplicateur = 1
  end
  local pts = ({ [MICRO] = 4, [SMALL] = 3, [NORMAL] = 2, [BIG] = 1 })[b.type] or 1
  player.score = player.score + pts * player.multiplicateur
  player.derniere_balle = b.type
  if player.multiplicateur > 1 then
    create_object(OBJ_MUL, math.floor(b.posx), math.floor(b.posy), player.multiplicateur)
  end
  if b.bonus ~= 0 then
    if b.bonus == BONUS_LIFE then
      if player.bonus_life == 0 and player.bonus_life_level ~= current_level then
        create_bonus(b.bonus, math.floor(b.posx) + 5, math.floor(b.posy) + 5)
      end
    else
      create_bonus(b.bonus, math.floor(b.posx) + 5, math.floor(b.posy) + 5)
    end
  end
  b.active = false
  beep(64)
end

local function update_ball(i)
  local b = balls[i]
  if not b.active then return end
  for p = 1, MAX_SHOOT do
    local s = shoots[p]
    if s.active then
      if aabb(b.xbox + b.posx, b.ybox + b.posy, b.hbox, b.lbox, s.posx + s.xbox, s.posy + s.ybox, s.hbox, s.lbox) then
        s.active = false
        player.nbtir = player.nbtir - 1
        pop_ball(b)
        return
      end
    end
  end
  if player.bonus_freeze ~= 0 then return end
  local total = 0
  for p = 1, MAX_PLATFORMS do
    if pform[p].active then
      local c = ball_vs_platform(b, pform[p])
      if c ~= 0 then
        total = c
        b.posx, b.posy = b.last_posx, b.last_posy
        break
      end
    end
  end
  local any = total ~= 0
  if total == TOUCH_H then
    b.vel = -b.vel
    if b.vel == 0 then b.move = -b.move end
  elseif total == TOUCH_V then
    b.move = -b.move
  end
  if ball_vs_border(b) then any = true end
  if not any then
    b.last_posx, b.last_posy = b.posx, b.posy
    b.had_col, b.nbtouch = 0, 0
  else
    if b.had_col == 1 then
      b.nbtouch = b.nbtouch + 1
    else
      b.had_col = 1
    end
  end
  if b.nbtouch > 5 then
    b.posx = b.posx + b.move
  end
  b.posx = b.posx + b.move
  b.vel = b.vel - GRAV
  b.posy = b.posy - b.vel
end

local function breakable(typ)
  return typ == PF_CASS or typ == PF_CASSV or typ == PF_MCASS or typ == PF_UCASS
end

local function unbreakable(typ)
  return typ == PF_INC or typ == PF_INCV or typ == PF_MINC or typ == PF_UINC
end

local function update_shoot(i)
  local s = shoots[i]
  if not s.active then return end
  if s.type == WPN_NORMAL or s.type == WPN_DOUBLE then
    s.posy = s.posy - 2
    s.hbox = s.posy_depart - s.posy
    if s.posy < 8 then
      s.active = false
      player.nbtir = player.nbtir - 1
    end
  elseif s.type == WPN_GLUE then
    if s.duree == -1 then
      s.posy = s.posy - 2
    end
    s.hbox = s.posy_depart - s.posy
    if s.posy < 8 then
      if s.duree == -1 then s.duree = 120 end
      s.posy = 8
    end
  end
  if s.duree > 0 then s.duree = s.duree - 1 end
  if s.duree == 0 then
    s.duree = -1
    s.active = false
    player.nbtir = player.nbtir - 1
  end
  for p = 1, MAX_PLATFORMS do
    local pf = pform[p]
    if pf.active and s.active then
      if aabb(s.posx + s.xbox, s.posy + s.ybox, math.max(0, s.hbox - 5), s.lbox, pf.posx, pf.posy, pf.hauteur, pf.largeur) then
        if s.type == WPN_DOUBLE or s.type == WPN_NORMAL then
          s.active = false
          player.nbtir = player.nbtir - 1
        end
        if s.type == WPN_GLUE and unbreakable(pf.type) then
          if s.duree == -1 then s.duree = 120 end
        end
        if breakable(pf.type) then
          if s.active then
            s.active = false
            player.nbtir = player.nbtir - 1
          end
          pf.active = false
          if pf.bonus ~= 0 then
            if pf.bonus == BONUS_LIFE then
              if player.bonus_life == 0 and player.bonus_life_level ~= current_level then
                create_bonus(pf.bonus, pf.posx + 4, pf.posy)
              end
            else
              create_bonus(pf.bonus, pf.posx + 4, pf.posy)
            end
          end
        end
      end
    end
  end
  if player.nbtir < 0 then player.nbtir = 0 end
end

local function update_bonus(i)
  local b = bonuses[i]
  if not b.active then return end
  local collide = false
  for p = 1, MAX_PLATFORMS do
    local pf = pform[p]
    if pf.active then
      if aabb(b.xbox + b.posx, b.ybox + b.posy, b.hbox, b.lbox, pf.posx, pf.posy, pf.hauteur, pf.largeur) then
        collide = true
      end
    end
  end
  if collide or b.posy + b.hbox > FLOOR then
    b.etat = DIR_STOP
  else
    b.etat = DIR_D
  end
  if b.etat == DIR_D then b.posy = b.posy + 2 end
  if b.etat == DIR_STOP then b.life = b.life - 1 end
  if b.life < 0 then b.active = false end
end

local function update_player()
  local where = 999
  local echelle, plat = -1, -1
  for i = 1, MAX_LADDER do
    local L = ladders[i]
    if L.active then
      if aabb(player.posx + 12, player.posy + 30, 2, 10, L.pad_mil_x, L.pad_mil_y, L.pad_mil_h, L.pad_mil_l) and player.en_descente < 3 then
        where, echelle = 2, i
      end
      if aabb(player.posx + 12, player.posy + 30, 2, 10, L.pad_bas_x, L.pad_bas_y, L.pad_bas_h, L.pad_bas_l) and player.en_descente < 3 then
        where, echelle = 1, i
      end
      if aabb(player.posx + 12, player.posy + 30, 2, 10, L.pad_haut_x, L.pad_haut_y, L.pad_haut_h, L.pad_haut_l) and player.en_descente < 3 then
        where, echelle = 3, i
        player.en_descente = 0
      end
    end
  end
  for i = 1, MAX_PLATFORMS do
    local pf = pform[i]
    if pf.active and where > 3 then
      local guard = 0
      while guard < 40 and aabb(player.posx + 12, player.posy + 30, 2, 6, pf.posx, pf.posy, pf.hauteur, pf.largeur) do
        where, plat = 4, i
        player.en_descente = 0
        player.posy = player.posy - 1
        guard = guard + 1
      end
    end
  end
  if where == 999 then
    if player.posy == FLOOR - 32 then
      where = 0
      player.en_descente = 0
    else
      where = 5
    end
  end
  if where == 5 then
    player.posy = player.posy + 2
    player.en_descente = player.en_descente + 2
  end
  if where == 4 and plat > 0 then
    player.posy = pform[plat].posy - 32
  end

  local key_left, key_right = held(LEFT), held(RIGHT)
  local key_up, key_down = held(UP), held(DOWN)
  local key_shot = held(Z) or held(X)

  if key_left and player.anim ~= A_SHOOT and where ~= 2 then
    player.xbox, player.ybox, player.hbox, player.lbox = 8, 2, 28, 22
    player.posx = player.posx - ((gbl_timer % 3 == 0) and 2 or 1)
    local stuck, guard = true, 0
    while stuck and guard < 8 do
      guard = guard + 1
      local block = false
      for i = 1, MAX_PLATFORMS do
        local pf = pform[i]
        if pf.active and aabb(player.posx + 5, player.posy + 6, 19, 2, pf.posx, pf.posy, pf.hauteur, pf.largeur) then
          block = true
        end
      end
      if not block then
        stuck = false
      else
        player.posx = player.posx + ((gbl_timer % 3 == 0) and 2 or 1)
      end
    end
    player.old_etat = player.etat
    player.etat = P_LEFT
  elseif key_right and player.anim ~= A_SHOOT and where ~= 2 then
    player.xbox, player.ybox, player.hbox, player.lbox = 4, 2, 28, 18
    player.posx = player.posx + ((gbl_timer % 3 == 0) and 2 or 1)
    local stuck, guard = true, 0
    while stuck and guard < 8 do
      guard = guard + 1
      local block = false
      for i = 1, MAX_PLATFORMS do
        local pf = pform[i]
        if pf.active and aabb(player.posx + 25, player.posy + 6, 19, 2, pf.posx, pf.posy, pf.hauteur, pf.largeur) then
          block = true
        end
      end
      if not block then
        stuck = false
      else
        player.posx = player.posx - ((gbl_timer % 3 == 0) and 2 or 1)
      end
    end
    player.old_etat = player.etat
    player.etat = P_RIGHT
  elseif key_up and where > 0 and where < 3 and echelle > 0 then
    player.posy = player.posy - 1
    player.posx = ladders[echelle].posx
    player.old_etat = player.etat
    player.etat = P_LADDER
  elseif key_down and where > 0 and where < 4 and echelle > 0 then
    player.posy = player.posy + 1
    player.posx = ladders[echelle].posx
    player.old_etat = player.etat
    player.etat = P_LADDER
  else
    player.etat = P_STOP
    player.anim = (where == 2) and A_LAD1 or A_STOP
  end

  if key_shot and player.shoot_timer == 0 then
    player.xbox, player.ybox, player.hbox, player.lbox = 2, 2, 30, 30
    local can = false
    if player.nbtir < 1 and (player.weapon == WPN_NORMAL or player.weapon == WPN_GLUE) then
      can = true
    elseif player.nbtir < 2 and player.weapon == WPN_DOUBLE then
      can = true
    end
    if can then
      create_shoot(player.weapon)
      player.nbtir = player.nbtir + 1
      player.anim = A_SHOOT
      player.anim_cpt = 5
      player.shoot_timer = 1
    end
  end
  if not key_shot then player.shoot_timer = 0 end
  if player.posx < 8 then player.posx = 8 end
  if player.posx > 283 then player.posx = 283 end
  if player.posy > FLOOR - 32 then player.posy = FLOOR - 32 end

  if player.bonus_freeze == 0 then
    for i = 1, MAX_BALL do
      local b = balls[i]
      if b.active then
        if aabb(player.posx, player.posy, 32, 31, b.posx, b.posy, ball_h(b), ball_w(b)) then
          if player.bonus_protection == 1 then
            if player.bonus_protection_timer == -1 then
              player.bonus_protection_timer = 20
            end
            explode_ball(i)
          elseif gbl_evt ~= ST_DEATH then
            gbl_evt = ST_DEATH
            death_cpt = 0
            player.nblive = player.nblive - 1
            beep(40)
          end
        end
      end
    end
  end

  for i = 1, MAX_BONUS do
    local b = bonuses[i]
    if b.active then
      if aabb(player.xbox + player.posx, player.ybox + player.posy, player.hbox, player.lbox, b.xbox + b.posx, b.ybox + b.posy, b.hbox, b.lbox) then
        if b.type == WPN_DOUBLE then
          player.weapon = WPN_DOUBLE
        elseif b.type == WPN_GLUE then
          player.weapon = WPN_GLUE
        elseif b.type == BONUS_BOOM then
          player.bonus_boom = 1
        elseif b.type == BONUS_FREEZE then
          player.bonus_freeze = 300
          player.bonus_boom = 0
        elseif b.type == BONUS_LIFE then
          player.bonus_life = 1
          player.bonus_life_level = current_level
          player.nblive = player.nblive + 1
          create_object(OBJ_1UP, player.posx, player.posy, 0)
        elseif b.type == BONUS_PROT then
          player.bonus_protection = 1
          player.bonus_protection_timer = -1
        end
        b.active = false
        beep(76)
      end
    end
  end

  if player.bonus_boom == 1 and gbl_timer % 10 == 0 then
    explode_all()
  end
  if player.bonus_freeze > 0 then
    player.bonus_freeze = player.bonus_freeze - 1
  end
  if player.bonus_protection_timer ~= -1 then
    player.bonus_protection_timer = player.bonus_protection_timer - 1
  end
  if player.bonus_protection_timer == 0 then
    player.bonus_protection = 0
    player.bonus_protection_timer = -1
  end

  if player.anim ~= A_SHOOT then
    if player.etat == P_RIGHT then
      if player.etat == player.old_etat then
        if gbl_timer % 5 == 0 then
          player.anim = player.anim + 1
          if player.anim > A_R3 then player.anim = A_R1 end
        end
      else
        player.anim = A_R1
      end
    elseif player.etat == P_LEFT then
      if player.etat == player.old_etat then
        if gbl_timer % 5 == 0 then
          player.anim = player.anim + 1
          if player.anim > A_L3 then player.anim = A_L1 end
        end
      else
        player.anim = A_L1
      end
    elseif player.etat == P_LADDER then
      if player.etat == player.old_etat then
        if gbl_timer % 5 == 0 then
          player.anim = player.anim + 1
          if player.anim > A_LAD2 then player.anim = A_LAD1 end
        end
      else
        player.anim = A_LAD1
      end
    end
  else
    player.anim_cpt = player.anim_cpt - 1
    if player.anim_cpt == 0 then
      if player.old_etat == P_RIGHT then
        player.anim = A_R1
      elseif player.old_etat == P_LEFT then
        player.anim = A_L1
      else
        player.anim = A_LAD1
      end
    end
  end
end

local function B(x, y, typ, h, v, bonus, parent, vel, vel_cst)
  local i = create_ball(x, y, typ, h, v)
  local b = balls[i]
  b.bonus = resolve_bonus(bonus)
  b.bonus_parent = resolve_bonus(parent)
  if vel then b.vel = vel end
  if vel_cst then b.vel_cst = vel_cst end
  return i
end

local function P(x, y, typ, bonus)
  return create_platform(x, y, typ, bonus)
end

local function L(x, y, n)
  return create_ladder(x, y, n)
end

local function init_level(n)
  clear_world()
  if n == 1 then
    B(39 - 32, 19, BIG, DIR_L, DIR_D, RND, RND)
  elseif n == 2 then
    B(120 - 32, 18, BIG, DIR_L, DIR_D, 0, RND)
    P(161 - 32, 81, PF_CASS, RND)
    P(193 - 32, 81, PF_CASS, RND)
  elseif n == 3 then
    B(76 - 32, 32, BIG, DIR_L, DIR_D)
    B(176 - 32, 101, SMALL, DIR_R, DIR_D, 0, 0, 0.5)
    P(177 - 32, 81, PF_CASS, RND)
    P(177 - 32, 138, PF_CASS, RND)
    P(73 - 32, 81 - 8, PF_INC)
    P(281 - 32, 81 - 8, PF_INC)
  elseif n == 4 then
    B(39 - 32, 19, BIG, DIR_L, DIR_D, RND, RND)
    L(162 - 32, 153, 12)
    L(202 - 32, 153, 12)
    P(185 - 32, 153 - 1, PF_INCV)
    P(193 - 32, 153 - 1, PF_INCV)
    player.posx = player.posx + 16
  elseif n == 5 then
    B(49 - 32, 70, BIG, DIR_L, DIR_D, WPN_DOUBLE)
    B(241, 120, NORMAL, DIR_L, DIR_D, 0, BONUS_FREEZE)
    P(97 - 32, 56, PF_CASSV)
    P(97 - 32, 81, PF_CASSV)
    P(289 - 32, 56, PF_CASSV, BONUS_BOOM)
    P(289 - 32, 81, PF_CASSV)
    P(193 - 32, 57, PF_CASSV)
  elseif n == 6 then
    P(81 - 32, 65, PF_MINC)
    P(297 - 32, 65, PF_MINC)
    P(185 - 32, 65, PF_MCASS)
    B(154 - 32, 16, BIG, DIR_L, DIR_D, WPN_DOUBLE)
    B(192 - 32, 16, BIG, DIR_R, DIR_D)
  elseif n == 7 then
    P(97 - 48, 49, PF_UINC)
    P(105 - 48, 57, PF_UINC)
    P(113 - 48, 65, PF_UINC)
    P(129 - 48, 105, PF_UINC)
    P(137 - 48, 121, PF_UINC)
    P(305 - 48, 49, PF_UINC)
    P(297 - 48, 57, PF_UINC)
    P(289 - 48, 65, PF_UINC)
    P(273 - 48, 105, PF_UINC)
    P(265 - 48, 121, PF_UINC)
    P(281 - 48, 73, PF_INCV)
    P(121 - 48, 73, PF_INCV)
    P(193 - 48 - 5, 121, PF_CASS)
    P(161 - 48, 121, PF_MCASS)
    P(232 - 48, 121, PF_MCASS)
    B(205 - 32, 31, BIG, DIR_L, DIR_D, RND, RND)
    B(161 - 32, 85, NORMAL, DIR_R, DIR_D, 0, WPN_DOUBLE)
  elseif n == 8 then
    P(65 - 32, 97, PF_INC)
    P(65, 97, PF_INC)
    P(65 - 32, 105, PF_INC)
    P(65, 105, PF_INC)
    P(257 - 32, 97, PF_INC)
    P(257, 97, PF_INC)
    P(257 - 32, 105, PF_INC)
    P(257, 105, PF_INC)
    P(185 - 32, 49, PF_INCV)
    P(193 - 32, 49, PF_INCV)
    P(185 - 32, 129, PF_INCV)
    P(193 - 32, 129, PF_INCV)
    B(150 - 32, 79, NORMAL, DIR_R, DIR_D, BONUS_FREEZE)
    B(209 - 32, 79, NORMAL, DIR_R, DIR_D, 0, RND)
  elseif n == 9 then
    B(134 - 42, 61, BIG, DIR_L, DIR_D, RND, RND)
    B(209 - 22, 61, BIG, DIR_R, DIR_D, RND, RND)
    L(51, 184, 4)
    P(73, 183, PF_MINC)
    P(73, 191, PF_MINC)
    L(90, 184, 4)
    L(129, 184, 4)
    P(151, 183, PF_MINC)
    P(151, 191, PF_MINC)
    L(169, 184, 4)
    L(213, 184, 4)
    P(235, 183, PF_MINC)
    P(235, 191, PF_MINC)
    L(253, 184, 4)
    player.posx = player.posx + 15
  elseif n == 10 then
    P(57 - 32, 89, PF_UCASS)
    P(81 - 32, 113, PF_UCASS)
    P(153 - 32, 89, PF_UCASS)
    P(177 - 32, 113, PF_UCASS, RND)
    P(249 - 32, 89, PF_UCASS)
    P(273 - 32, 113, PF_UCASS)
    P(105 - 32, 89, PF_UINC)
    P(128 - 32, 113, PF_UINC)
    P(201 - 32, 89, PF_UINC)
    P(225 - 32, 113, PF_UINC)
    P(296 - 32, 89, PF_UINC)
    P(320 - 32, 113, PF_UINC)
    B(42 - 32, 54, NORMAL, DIR_R, DIR_D, RND)
    B(279 - 32, 45, BIG, DIR_R, DIR_D, 0, RND)
  elseif n == 11 then
    P(41 - 32, 62, PF_MCASS)
    P(105 - 32, 53, PF_MCASS)
    P(185 - 32, 38, PF_MCASS, BONUS_LIFE)
    P(265 - 32, 54, PF_MCASS)
    P(329 - 32, 62, PF_MCASS, RND)
    P(81 - 32, 94, PF_MCASS)
    P(160 - 32, 86, PF_MCASS)
    P(209 - 32, 86, PF_MCASS)
    P(289 - 32, 94, PF_MCASS, RND)
    P(121 - 32, 126, PF_MCASS)
    P(250 - 32, 126, PF_MCASS, RND)
    P(161 - 32, 150, PF_MCASS)
    P(209 - 32, 150, PF_MCASS)
    B(119 - 32, 20, NORMAL, DIR_R, DIR_D)
    B(217 - 32, 37, BIG, DIR_R, DIR_D, 0, RND)
  elseif n == 12 then
    B(39 - 32, 19, BIG, DIR_L, DIR_D, 0, RND)
    B(276 - 32, 19, BIG, DIR_R, DIR_D, 0, RND)
    L(177 - 32, 56, 36)
    P(177 - 64, 55, PF_INC)
    P(199 - 32, 55, PF_INC)
    P(88 - 26, 156, PF_MINC)
    P(88 - 26, 164, PF_MINC)
    P(280 - 38, 156, PF_MINC)
    P(280 - 38, 164, PF_MINC)
  elseif n == 13 then
    P(8, 139, PF_INC)
    P(50, 139, PF_INC)
    P(104, 139, PF_INC)
    P(136, 139, PF_INC)
    P(180, 139, PF_INC)
    P(234, 139, PF_INC)
    P(280, 139, PF_INC)
    P(49, 80, PF_MINC)
    P(248, 80, PF_MINC)
    P(108, 38, PF_MINC)
    P(192, 38, PF_MINC)
    L(212, 140, 5)
    L(82, 140, 15)
    local i = B(134, 60, BIG, DIR_R, DIR_D, WPN_GLUE, RND)
    balls[i].vel = balls[i].vel / 2
    i = B(20, 105, NORMAL, DIR_R, DIR_D, RND, WPN_GLUE)
    balls[i].vel = balls[i].vel / 2
  elseif n == 14 then
    P(65, 118, PF_INC)
    P(119, 118, PF_INC)
    P(151, 118, PF_INC)
    P(183, 118, PF_INC)
    P(215, 118, PF_INC)
    P(8, 66, PF_INC)
    P(40, 66, PF_INC)
    P(248, 55, PF_INC)
    P(280, 55, PF_INC)
    L(97, 119, 5)
    L(247, 119, 20)
    P(75, 28, PF_CASSV)
    P(54, 81, PF_CASSV)
    B(9, 9, BIG, DIR_R, DIR_D, RND, RND)
    B(222, 76, NORMAL, DIR_R, DIR_D, RND, RND)
  elseif n == 15 then
    B(68, 128, NORMAL, DIR_L, DIR_D, RND, RND)
    local i = B(68, 22, NORMAL, DIR_L, DIR_D, 0, RND)
    balls[i].vel = balls[i].vel / 2
    i = B(246, 20, NORMAL, DIR_R, DIR_D, RND, RND)
    balls[i].vel = balls[i].vel / 2
    B(246, 135, NORMAL, DIR_R, DIR_D, 0, RND)
    P(8, 109, PF_INC)
    P(62, 109, PF_INC)
    P(94, 109, PF_INC)
    P(147, 109, PF_INC)
    P(179, 109, PF_INC)
    P(211, 109, PF_INC)
    P(265, 109, PF_INC)
    L(243, 109, 23)
    L(125, 109, 6)
    L(40, 109, 23)
  elseif n == 16 then
    B(21, 14, MICRO, DIR_R, DIR_D, RND)
    B(25, 30, MICRO, DIR_R, DIR_D)
    B(29, 46, MICRO, DIR_R, DIR_D)
    B(33, 62, MICRO, DIR_R, DIR_D)
    B(36, 77, MICRO, DIR_R, DIR_D)
    B(41, 92, MICRO, DIR_R, DIR_D)
    B(45, 110, MICRO, DIR_R, DIR_D)
    B(50, 127, MICRO, DIR_R, DIR_D)
    B(320 - 21, 14, MICRO, DIR_L, DIR_D, RND)
    B(320 - 25, 30, MICRO, DIR_L, DIR_D)
    B(320 - 29, 46, MICRO, DIR_L, DIR_D)
    B(320 - 33, 62, MICRO, DIR_L, DIR_D)
    B(320 - 36, 77, MICRO, DIR_L, DIR_D)
    B(320 - 41, 92, MICRO, DIR_L, DIR_D)
    B(320 - 45, 110, MICRO, DIR_L, DIR_D)
    B(320 - 50, 127, MICRO, DIR_L, DIR_D)
    for j = 1, MAX_BALL do
      if balls[j].active then balls[j].vel_cst = 10.0 end
    end
  elseif n == 17 then
    for i = 0, 8 do
      P(17 + i * 32, 29, PF_CASS)
    end
    P(9, 29, PF_UCASS, BONUS_LIFE)
    P(305, 29, PF_UCASS, RND)
    for j = 0, 7 do
      B(18 + j * 8, 18, MICRO, DIR_R, DIR_D, 0, 0, 0.5)
    end
    for j = 0, 7 do
      B(230 + j * 8, 18, MICRO, DIR_R, DIR_D, 0, 0, 0.5)
    end
    B(69, 56, BIG, DIR_L, DIR_D, 0, WPN_DOUBLE, 1.0, 11.0)
    B(194, 64, NORMAL, DIR_R, DIR_D, 0, WPN_DOUBLE, 1.0)
  elseif n == 18 then
    for i = 0, 3 do
      B(18 + i * 8, 150, MICRO, DIR_L, DIR_D, 0, 0, nil, 8.0)
    end
    for i = 0, 3 do
      B(230 + i * 8, 150, MICRO, DIR_R, DIR_D, 0, 0, nil, 8.0)
    end
    P(65, 85, PF_CASS, WPN_DOUBLE)
    P(220, 85, PF_CASS, RND)
  elseif n == 19 then
    B(77, 17, BIG, DIR_R, DIR_D, 0, RND)
    B(229, 19, NORMAL, DIR_L, DIR_D, 0, RND)
    L(8, 100, 25)
    L(290, 100, 25)
    for j = 0, 6 do
      P(47 + j * 32, 136, PF_INC)
    end
  elseif n == 20 then
    P(64 - 32, 48, PF_MCASS)
    P(304 - 32, 48, PF_MCASS)
    P(160 - 32, 140, PF_INC)
    P(160, 140, PF_INC)
    local i = B(124 - 32, 27, BIG, DIR_R, DIR_D, RND, RND)
    balls[i].vel = balls[i].vel / 2
    i = B(225 - 32, 27, BIG, DIR_L, DIR_D)
    balls[i].vel = balls[i].vel / 2
  elseif n == 21 then
    P(175 - 48, 127, PF_CASS)
    P(175 - 16, 127, PF_CASS)
    P(185 - 32, 65, PF_MINC)
    P(90 - 32, 80, PF_MINC)
    P(286 - 32, 80, PF_MINC)
    local i = B(124 - 32, 27, BIG, DIR_R, DIR_D, RND, RND)
    balls[i].vel = balls[i].vel / 2
    i = B(225 - 32, 27, BIG, DIR_L, DIR_D)
    balls[i].vel = balls[i].vel / 2
  elseif n == 22 then
    for i = 0, 6 do
      P(112 - 64 + i * 32, 104, PF_INC)
    end
    local i = B(92 - 32, 27, BIG, DIR_R, DIR_D, 0, RND)
    balls[i].vel = balls[i].vel / 2
    i = B(250 - 32, 27, BIG, DIR_R, DIR_D, 0, RND)
    balls[i].vel = balls[i].vel / 2
  elseif n == 23 then
    for i = 0, 3 do
      P(81 - 32, 33 + i * 32, PF_INCV)
      P(153 - 32, 33 + i * 32, PF_CASSV)
      P(225 - 32, 33 + i * 32, PF_CASSV)
      P(297 - 32, 33 + i * 32, PF_INCV)
    end
    player.posx = player.posx + 64
    B(197 - 64, 20, BIG, DIR_R, DIR_D, RND, RND)
  elseif n == 24 then
    for i = 0, 3 do
      P(81 - 32, 33 + i * 32, PF_INCV)
      P(297 - 32, 33 + i * 32, PF_INCV)
    end
    B(205, 20, BIG, DIR_R, DIR_D, RND, RND)
    B(197 - 128, 20, BIG, DIR_L, DIR_D, RND, RND)
  elseif n == 25 then
    B(50, 10, BIG, DIR_L, DIR_D, RND, RND)
    B(50, 10, BIG, DIR_R, DIR_D, RND, RND)
    B(200, 10, MICRO, DIR_L, DIR_D)
    B(205, 15, MICRO, DIR_L, DIR_U)
    B(210, 20, MICRO, DIR_R, DIR_D)
    B(215, 22, MICRO, DIR_R, DIR_D)
    B(220, 25, MICRO, DIR_R, DIR_U)
    B(225, 30, MICRO, DIR_L, DIR_D)
    for j = 0, 5 do
      if j > 2 then
        P(305 - j * 8, 41 + j * 8, PF_UINC)
        P(9 + j * 8, 41 + j * 8, PF_UINC)
      end
    end
    L(288, 57, 36)
    L(11, 57, 36)
    P(233, 89, PF_CASS)
    local i = P(57, 81, PF_CASS)
    P(89, 89, PF_MINC)
    pform[i].bonus = resolve_bonus(RND)
    P(209, 89, PF_MINC)
    pform[i].bonus = BONUS_LIFE
    for j = 0, 2 do
      P(208 - j * 8, 97 + j * 8, PF_UINC)
      P(105 + j * 8, 97 + j * 8, PF_UINC)
    end
    P(129, 121, PF_MINC)
    P(177, 121, PF_MINC)
  end
end

local function start_level(n)
  reinit_player()
  init_level(n)
  gbl_evt = ST_PLAY
end

local function bonus_color(typ)
  if typ == WPN_DOUBLE then return 7 end
  if typ == WPN_GLUE then return 8 end
  if typ == BONUS_BOOM then return 6 end
  if typ == BONUS_FREEZE then return 13 end
  if typ == BONUS_LIFE then return 5 end
  if typ == BONUS_PROT then return 9 end
  return 4
end

local function pf_color(typ)
  if breakable(typ) then return 10 end
  return 15
end

local function ball_color(typ)
  if typ == BIG then return 6 end
  if typ == NORMAL then return 11 end
  if typ == SMALL then return 5 end
  return 4
end

local function draw_bg()
  ui.cls(0)
  if not blit(fond_for(current_level), 0, 0) then
    local th = theme_of(current_level)
    ui.cls(th.sky)
    gfill(0, 0, 8, FLOOR, th.wall)
    gfill(ORIG_W - 8, 0, 8, FLOOR, th.wall)
    gfill(0, FLOOR, ORIG_W, ORIG_H - FLOOR, th.floor)
  end
end

local function draw_player()
  local x, y = player.posx, player.posy
  if player.bonus_protection == 1 then
    if player.bonus_protection_timer == -1 or gbl_timer % 2 == 0 then
      blit(SPR.shield, x - 5, y - 5)
    end
  end
  local spr = SPR.player[player.anim] or SPR.player[A_STOP]
  if not blit(spr, x, y) then
    gfill(x + 10, y + 12, 12, 14, 11)
    gcirc(x + 10, y + 2, 12, 12, 12)
  end
end

local function draw_world()
  for i = 1, MAX_LADDER do
    local L = ladders[i]
    if L.active then
      for e = 0, L.nb_rungs - 1 do
        if not blit(SPR.ladder, L.posx, L.posy + e * 4) then
          gfill(L.posx, L.posy + e * 4, 22, 3, 5)
        end
      end
    end
  end
  for i = 1, MAX_PLATFORMS do
    local p = pform[i]
    if p.active then
      if not blit(SPR.pf[p.type], p.posx, p.posy) then
        gfill(p.posx, p.posy, p.largeur, p.hauteur, pf_color(p.type))
      end
    end
  end
  for i = 1, MAX_SHOOT do
    local s = shoots[i]
    if s.active then
      local hide = s.type == WPN_GLUE and s.duree > 0 and s.duree < 30 and gbl_timer % 2 == 0
      if not hide then
        local ref = (s.type == WPN_GLUE) and SPR.glue or SPR.wire
        local h = math.max(1, s.hbox)
        if not blit_clip(ref, s.posx, s.posy, s.lbox, h) then
          gfill(s.posx, s.posy, s.lbox, h, 4)
        end
      end
    end
  end
  for i = 1, MAX_BALL do
    local b = balls[i]
    if b.active then
      local show = true
      if player.bonus_freeze > 0 and player.bonus_freeze < 81 and gbl_timer % 2 ~= 0 then
        show = false
      end
      if show then
        if not blit(SPR.ball[b.type], b.posx, b.posy) then
          gcirc(b.posx, b.posy, ball_w(b), ball_h(b), ball_color(b.type))
        end
      end
    end
  end
  for i = 1, MAX_BONUS do
    local b = bonuses[i]
    if b.active then
      if not blit(SPR.bonus[b.type], b.posx, b.posy) then
        gfill(b.posx, b.posy, 18, 18, bonus_color(b.type))
      end
    end
  end
  draw_player()
  for i = 1, MAX_OBJECTS do
    local o = objs[i]
    if o.active then
      if o.cpt > 0 then
        if o.type == OBJ_MUL then
          blit(SPR.obj_x, o.posx, o.posy)
          draw_number(o.value, o.posx + 8, o.posy)
        else
          if not blit(SPR.obj_1up, o.posx, o.posy) then
            ui.print("1UP", sx(o.posx), sy(o.posy), 5)
          end
        end
        o.posy = o.posy - 1
        o.cpt = o.cpt - 1
      else
        o.active = false
      end
    end
  end
end

local function draw_hud()
  for i = 0, math.min(player.nblive, 3) - 1 do
    if not blit(SPR.life, 10 + i * 20, 214) then
      gfill(10 + i * 20, 214, 18, 18, 11)
    end
  end
  blit(SPR.label_score, 130, 210)
  draw_number(player.score, 170, 209)
  blit(SPR.label_level, 130, 224)
  draw_number(current_level, 170, 224)
end

local function count_balls()
  local n = 0
  for i = 1, MAX_BALL do
    if balls[i].active then n = n + 1 end
  end
  return n
end

local function extra_lives(old)
  if (old < 600 and player.score >= 600)
    or (old < 1500 and player.score >= 1500)
    or (old < 5000 and player.score >= 5000) then
    create_object(OBJ_1UP, player.posx, player.posy, 0)
    player.nblive = player.nblive + 1
  end
end

local function draw_title()
  ui.cls(0)
  if not blit(SPR.title, 0, 0) then
    ui.print("PANG", sx(140), sy(70), 5)
  end
end

math.randomseed(36547)
balls, pform, ladders, shoots, bonuses, objs = pool(MAX_BALL), pool(MAX_PLATFORMS), pool(MAX_LADDER), pool(MAX_SHOOT), pool(MAX_BONUS), pool(MAX_OBJECTS)
init_player()

function update(frame)
  pal()
  gbl_timer = gbl_timer + 1
  if gbl_timer == 51 then gbl_timer = 1 end
  onetwo = onetwo + 1
  if onetwo > 5 then onetwo = 0 end

  if gbl_evt == ST_TITLE then
    draw_title()
    if wait_release then
      if not held(Z) and not held(X) then wait_release = false end
    elseif pressed(Z) or pressed(X) then
      init_player()
      current_level = 1
      init_level(1)
      gbl_evt = ST_PLAY
    end
    return
  end

  if gbl_evt == ST_NEXT then
    ui.cls(0)
    blit(((current_level % 2) == 0) and SPR.next1 or SPR.next2, 0, 0)
    blit(SPR.label_score, 110, 217)
    draw_number(player.score, 183, 217)
    if wait_release then
      if not held(Z) and not held(X) then wait_release = false end
    elseif pressed(Z) or pressed(X) then
      current_level = current_level + 1
      if current_level > MAX_LEVEL then current_level = 1 end
      start_level(current_level)
    end
    return
  end

  if gbl_evt == ST_OVER then
    draw_bg()
    draw_world()
    draw_hud()
    over_cpt = over_cpt + 3
    blit(SPR.gameover, ORIG_W - over_cpt, 100)
    if over_cpt >= 230 then
      ui.print("aperte Z", sx(120), sy(130), 4)
      if pressed(Z) or pressed(X) then
        init_player()
        current_level = 1
        gbl_evt = ST_TITLE
        wait_release = true
      end
    end
    return
  end

  if gbl_evt == ST_DEATH then
    death_cpt = death_cpt + 1
    if death_cpt > 20 then player.anim = A_DEAD end
    if death_cpt > 20 and death_cpt < 40 then
      player.posy = player.posy - 1
    elseif death_cpt > 40 then
      player.posy = player.posy + 1
      player.posx = player.posx + 1
    end
    draw_bg()
    draw_world()
    draw_hud()
    if death_cpt >= 70 then
      if player.nblive <= 0 then
        gbl_evt = ST_OVER
        over_cpt = 0
      else
        reinit_player()
        init_level(current_level)
        gbl_evt = ST_PLAY
      end
    end
    return
  end

  local old = player.score
  update_player()
  for i = 1, MAX_SHOOT do update_shoot(i) end
  if onetwo == 0 or onetwo == 2 or onetwo == 4 then
    for i = 1, MAX_BALL do update_ball(i) end
  end
  for i = 1, MAX_BONUS do update_bonus(i) end
  extra_lives(old)
  if count_balls() == 0 and gbl_evt == ST_PLAY then
    gbl_evt = ST_NEXT
    wait_release = true
    beep(80)
  end

  draw_bg()
  draw_world()
  draw_hud()
end
