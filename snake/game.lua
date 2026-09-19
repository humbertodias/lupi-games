-- Snake

local SCREEN_W = 480
local SCREEN_H = 270
local CELL = 12
local GRID_W = 40
local GRID_H = 21
local START_LEN = 5
local TICK = 5
local OX = 0
local OY = math.floor((SCREEN_H - GRID_H * CELL) / 2)

local function rgb555(r, g, b)
	return r + (g * 32) + (b * 1024)
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
local LEFT = btn_id("LEFT", 0)
local RIGHT = btn_id("RIGHT", 1)
local ACTION = btn_id("BTN_Z", 7)
local ACTION2 = rawget(_G, "BTN_X")

local OPPOSITE = { [1] = 2, [2] = 1, [3] = 4, [4] = 3 }

local snake
local dir
local pending
local food
local score
local alive

local function hsl(h, s, l)
	if s <= 0 then
		return l, l, l
	end
	h, s, l = h / 256 * 6, s / 255, l / 255
	local c = (1 - math.abs(2 * l - 1)) * s
	local x = (1 - math.abs(h % 2 - 1)) * c
	local m = l - 0.5 * c
	local r, g, b = 0, 0, 0
	if h < 1 then
		r, g, b = c, x, 0
	elseif h < 2 then
		r, g, b = x, c, 0
	elseif h < 3 then
		r, g, b = 0, c, x
	elseif h < 4 then
		r, g, b = 0, x, c
	elseif h < 5 then
		r, g, b = x, 0, c
	else
		r, g, b = c, 0, x
	end
	return (r + m) * 255, (g + m) * 255, (b + m) * 255
end

local function to555(r, g, b)
	r = math.floor(r / 255 * 31 + 0.5)
	g = math.floor(g / 255 * 31 + 0.5)
	b = math.floor(b / 255 * 31 + 0.5)
	if r < 0 then r = 0 elseif r > 31 then r = 31 end
	if g < 0 then g = 0 elseif g > 31 then g = 31 end
	if b < 0 then b = 0 elseif b > 31 then b = 31 end
	return rgb555(r, g, b)
end

local function held(id)
	if id == nil then
		return false
	end
	local v = ui.btn(id, 0)
	return v and v ~= false and v ~= 0
end

local function just(id)
	if id == nil then
		return false
	end
	local v = ui.btnp(id, 0)
	return v and v ~= false and v ~= 0
end

local function occupied(x, y)
	for i = 1, #snake do
		if snake[i][1] == x and snake[i][2] == y then
			return true
		end
	end
	return false
end

local function place_food()
	local x, y
	repeat
		x = math.random(1, GRID_W - 2)
		y = math.random(1, GRID_H - 2)
	until not occupied(x, y)
	food = { x, y }
end

local function init()
	snake = {}
	local cx = math.floor(GRID_W / 2)
	local cy = math.floor(GRID_H / 2)
	for _ = 1, START_LEN do
		table.insert(snake, { cx, cy })
	end
	dir = 0
	pending = 0
	score = 0
	alive = true
	place_food()
end

local function cell(x, y, color)
	local x0 = OX + x * CELL
	local y0 = OY + y * CELL
	ui.rectfill(x0, y0, x0 + CELL - 1, y0 + CELL - 1, color)
end

math.randomseed(os.time())
init()

function update(frame)
	local lum = math.sin(frame / 300) * 8 + 40
	local br, bg, bb = hsl(frame / 100, 128, lum)
	local gr, gg, gb = hsl(frame / 100, 128, lum + 10)

	ui.palset(0, to555(br, bg, bb))
	ui.palset(1, to555(gr, gg, gb))
	ui.palset(2, rgb555(31, 31, 31))
	ui.palset(3, rgb555(31, 8, 8))
	ui.palset(4, rgb555(31, 28, 10))
	ui.palset(5, rgb555(8, 8, 10))

	ui.cls(0)

	if just(ACTION) or just(ACTION2) then
		init()
	end

	if alive then
		if held(UP) then
			pending = 1
		elseif held(DOWN) then
			pending = 2
		elseif held(LEFT) then
			pending = 3
		elseif held(RIGHT) then
			pending = 4
		end

		if frame % TICK == 0 then
			if pending > 0 and pending ~= OPPOSITE[dir] then
				dir = pending
			end

			if dir > 0 then
				local head = snake[#snake]
				local nx, ny = head[1], head[2]
				if dir == 1 then
					ny = ny - 1
				elseif dir == 2 then
					ny = ny + 1
				elseif dir == 3 then
					nx = nx - 1
				else
					nx = nx + 1
				end

				local hit = nx <= 0 or nx >= GRID_W - 1 or ny <= 0 or ny >= GRID_H - 1
				if not hit then
					for i = 1, #snake do
						if snake[i][1] == nx and snake[i][2] == ny then
							hit = true
							break
						end
					end
				end

				if hit then
					alive = false
				else
					table.insert(snake, { nx, ny })
					if nx == food[1] and ny == food[2] then
						score = score + 1
						place_food()
					else
						table.remove(snake, 1)
					end
				end
			end
		end
	end

	for y = 0, GRID_H - 1 do
		for x = 0, GRID_W - 1 do
			cell(x, y, 1)
		end
	end

	for i = 1, #snake do
		cell(snake[i][1], snake[i][2], 2)
	end
	cell(food[1], food[2], 3)

	ui.print("SNAKE  " .. score, 8, 2, 2)
	if not alive then
		ui.print("GAME OVER  Z RESTART", 150, 2, 4)
	elseif dir == 0 then
		ui.print("WASD / D-PAD", 200, 2, 5)
	end
end
