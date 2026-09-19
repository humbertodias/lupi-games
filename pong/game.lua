-- Pong
-- Converted from Lutro Pong (320x240) to Lupi (480x270).
-- P1: UP/DOWN. P2: segundo pad ou IA. BTN_Z reinicia.

local SCREEN_W = 480
local SCREEN_H = 270
local ORIG_W = 320
local ORIG_H = 240
local SX = SCREEN_W / ORIG_W
local SY = SCREEN_H / ORIG_H
local DT = 1 / 60

local function rgb555(r, g, b)
	return r + (g * 32) + (b * 1024)
end

local function to555(r8, g8, b8)
	local r = math.floor(r8 / 255 * 31 + 0.5)
	local g = math.floor(g8 / 255 * 31 + 0.5)
	local b = math.floor(b8 / 255 * 31 + 0.5)
	if r < 0 then r = 0 elseif r > 31 then r = 31 end
	if g < 0 then g = 0 elseif g > 31 then g = 31 end
	if b < 0 then b = 0 elseif b > 31 then b = 31 end
	return rgb555(r, g, b)
end

local function btn_id(name, fallback)
	local v = rawget(_G, name)
	if v ~= nil then
		return v
	end
	return fallback
end

local UP = btn_id("UP", 2)
local DOWN = btn_id("DOWN", 3)
local ACTION = btn_id("BTN_Z", 7)
local ACTION2 = rawget(_G, "BTN_X")

local Palette = {
	to555(33, 33, 33),
	to555(255, 255, 255),
	to555(244, 67, 54),
	to555(33, 150, 243),
	to555(90, 90, 90),
	to555(200, 200, 200),
}

local function pal()
	for i = 1, #Palette do
		ui.palset(i - 1, Palette[i])
	end
end

local function held(id, player)
	if id == nil then
		return false
	end
	local v = ui.btn(id, player or 0)
	return v and v ~= false and v ~= 0
end

local function just(id, player)
	if id == nil then
		return false
	end
	local v = ui.btnp(id, player or 0)
	return v and v ~= false and v ~= 0
end

local function beep(note, pan)
	if sfx and sfx.fx then
		pcall(sfx.fx, 0, note or 60, pan or 0.5)
	end
end

local function mag(vx, vy)
	return math.sqrt(vx * vx + vy * vy)
end

local function set_mag(e, m)
	local d = mag(e.vx, e.vy)
	if d == 0 then
		e.vx = m
		e.vy = 0
		return
	end
	e.vx = e.vx / d * m
	e.vy = e.vy / d * m
end

local function direction(vx, vy)
	return math.atan(vy, vx)
end

local function set_direction(e, rad)
	local m = mag(e.vx, e.vy)
	e.vx = math.cos(rad) * m
	e.vy = math.sin(rad) * m
end

local function reflect_degrees(e, degrees)
	local angle = math.deg(direction(e.vx, e.vy))
	local opp = (angle + 180) % 360
	if degrees >= opp then
		local diff = degrees - opp
		angle = (degrees + diff) % 360
	else
		local diff = opp - degrees
		angle = degrees - diff
		if angle < 0 then
			angle = angle + 360
		end
	end
	set_direction(e, math.rad(angle))
end

local function apply_motion(e)
	e.vx = e.vx + e.ax * DT
	e.vy = e.vy + e.ay * DT
	local fxd = e.fx * DT
	local fyd = e.fy * DT
	if e.vx > 0 then
		if e.vx > fxd then
			e.vx = e.vx - fxd
		else
			e.vx = 0
		end
	elseif e.vx < 0 then
		if e.vx < -fxd then
			e.vx = e.vx + fxd
		else
			e.vx = 0
		end
	end
	if e.vy > 0 then
		if e.vy > fyd then
			e.vy = e.vy - fyd
		else
			e.vy = 0
		end
	elseif e.vy < 0 then
		if e.vy < -fyd then
			e.vy = e.vy + fyd
		else
			e.vy = 0
		end
	end
	e.x = e.x + e.vx * DT
	e.y = e.y + e.vy * DT
end

local function left(e)
	return e.x
end
local function right(e)
	return e.x + e.w
end
local function top(e)
	return e.y
end
local function bottom(e)
	return e.y + e.h
end
local function center_x(e)
	return e.x + e.w / 2
end
local function center_y(e)
	return e.y + e.h / 2
end

local function set_left(e, v)
	e.x = v
end
local function set_right(e, v)
	e.x = v - e.w
end
local function set_top(e, v)
	e.y = v
end
local function set_bottom(e, v)
	e.y = v - e.h
end
local function set_center_x(e, v)
	e.x = v - e.w / 2
end
local function set_center_y(e, v)
	e.y = v - e.h / 2
end

local function collide(a, b)
	return left(a) < right(b) and top(a) < bottom(b) and bottom(a) > top(b) and right(a) > left(b)
end

local function fill(e, color)
	ui.rectfill(
		math.floor(e.x),
		math.floor(e.y),
		math.floor(e.x + e.w - 1),
		math.floor(e.y + e.h - 1),
		color
	)
end

local PADDLE_W = 5 * SX
local PADDLE_H = 50 * SY
local BALL_W = 8 * SX
local BALL_H = 8 * SY
local SIDE = 20 * SX
local ACCEL = 1800 * SY
local FRICTION_Y = 900 * SY
local MAX_SPEED_Y = 250 * SY
local BALL_SPEED = 180 * SX

local p1
local p2
local ball
local score1
local score2
local human2

local function make_paddle()
	return {
		x = 0,
		y = 0,
		w = PADDLE_W,
		h = PADDLE_H,
		vx = 0,
		vy = 0,
		ax = 0,
		ay = 0,
		fx = 0,
		fy = FRICTION_Y,
		color = 1,
	}
end

local function reset_ball(flip_x)
	set_center_x(ball, SCREEN_W / 2)
	set_center_y(ball, SCREEN_H / 2)
	ball.vx = BALL_SPEED
	ball.vy = 0
	ball.ax = 0
	ball.ay = 0
	ball.fx = 0
	ball.fy = 0
	if flip_x then
		ball.vx = -ball.vx
	end
end

local function init()
	p1 = make_paddle()
	p1.color = 2
	set_left(p1, SIDE)
	set_center_y(p1, SCREEN_H / 2)

	p2 = make_paddle()
	p2.color = 3
	set_right(p2, SCREEN_W - SIDE)
	set_center_y(p2, SCREEN_H / 2)

	ball = {
		x = 0,
		y = 0,
		w = BALL_W,
		h = BALL_H,
		vx = 0,
		vy = 0,
		ax = 0,
		ay = 0,
		fx = 0,
		fy = 0,
	}
	reset_ball(false)

	score1 = 0
	score2 = 0
	human2 = false
end

local function clamp_paddle(p)
	if bottom(p) > SCREEN_H then
		p.vy = -p.vy
		set_bottom(p, SCREEN_H)
	elseif top(p) < 0 then
		p.vy = -p.vy
		set_top(p, 0)
	end
	if p.vy > MAX_SPEED_Y then
		p.vy = MAX_SPEED_Y
	elseif p.vy < -MAX_SPEED_Y then
		p.vy = -MAX_SPEED_Y
	end
end

local function paddle_input(p, player)
	if held(UP, player) then
		p.ay = -ACCEL
	elseif held(DOWN, player) then
		p.ay = ACCEL
	else
		p.ay = 0
	end
end

local function paddle_ai(p)
	if ball.vx > 0 then
		if center_y(ball) < center_y(p) then
			p.ay = -ACCEL
		else
			p.ay = ACCEL
		end
	else
		p.ay = 0
	end
end

local function paddle_collide()
	if ball.vx <= 0 and collide(ball, p1) then
		beep(62, 0.2)
		return p1
	elseif ball.vx >= 0 and collide(ball, p2) then
		beep(67, 0.8)
		return p2
	end
	return nil
end

local function update_ball()
	if bottom(ball) > SCREEN_H then
		set_bottom(ball, SCREEN_H)
		ball.vy = -ball.vy
	elseif top(ball) < 0 then
		set_top(ball, 0)
		ball.vy = -ball.vy
	end

	local paddle = paddle_collide()
	if paddle then
		local hit = (center_y(paddle) - center_y(ball)) / paddle.h * 100
		reflect_degrees(ball, hit * -0.75)
		set_mag(ball, mag(ball.vx, ball.vy) * 1.1)
		if left(ball) < SCREEN_W / 2 then
			set_left(ball, right(paddle))
		else
			set_right(ball, left(paddle))
		end
	end

	if left(ball) > SCREEN_W then
		reset_ball(true)
		score1 = score1 + 1
		beep(52, 0.5)
	elseif right(ball) < 0 then
		reset_ball(false)
		score2 = score2 + 1
		beep(52, 0.5)
	end

	apply_motion(ball)
end

local function draw_net()
	local x = math.floor(SCREEN_W / 2)
	local padding = math.floor(10 * SY)
	local length = math.floor(10 * SY)
	local gap = math.floor(20 * SY)
	for y = padding, SCREEN_H - padding, length + gap do
		ui.line(x, y, x, y + length, 5)
	end
end

local function draw_score()
	ui.print(tostring(score1), math.floor(SCREEN_W / 3) - 4, math.floor(10 * SY), 1)
	ui.print(tostring(score2), math.floor(SCREEN_W / 3 * 2) - 4, math.floor(10 * SY), 1)
end

init()

function update(frame)
	pal()
	ui.cls(0)

	if just(ACTION) or just(ACTION2) then
		init()
	end

	paddle_input(p1, 0)

	if held(UP, 1) or held(DOWN, 1) then
		human2 = true
	end
	if human2 then
		paddle_input(p2, 1)
	else
		paddle_ai(p2)
	end

	clamp_paddle(p1)
	clamp_paddle(p2)
	apply_motion(p1)
	apply_motion(p2)
	clamp_paddle(p1)
	clamp_paddle(p2)

	update_ball()

	draw_net()
	fill(p1, p1.color)
	fill(p2, p2.color)
	fill(ball, 1)
	draw_score()
end
