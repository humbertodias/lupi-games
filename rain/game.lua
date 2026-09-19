-- ============================================
-- RAIN - Lupinho
-- Converted from BennuGD
--
-- Lupinho:
--   480 x 270
--   256 color palette
--   BGR555
-- ============================================

local SCREEN_WIDTH  = 480
local SCREEN_HEIGHT = 270

local MAX_DROPS = 400


-- ============================================
-- PALETTE
-- ============================================

-- Original BennuGD colors:
--
-- Background : 2114
-- Dark blue  : 4640
-- Medium blue: 11615
-- Blue       : 32255
-- Bright blue: 40191
--
-- Original values are RGB565.
-- Converted to Lupinho BGR555.
--
-- Index 0 = background
-- Index 1 = dark blue
-- Index 2 = medium blue
-- Index 3 = blue
-- Index 4 = bright blue

local Palette = {
    0x0821, -- 0 - RGB565 2114
    0x0102, -- 1 - RGB565 4640
    0x7EA5, -- 2 - RGB565 11615
    0x7EEF, -- 3 - RGB565 32255
    0x7E73  -- 4 - RGB565 40191
}

for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
end


-- ============================================
-- RAIN ARRAYS
-- ============================================

local rain_x = {}
local rain_y = {}
local rain_speed = {}
local rain_len = {}
local rain_brightness = {}


-- ============================================
-- RESET DROP
-- ============================================

local function reset_drop(i)

    -- Horizontal position
    rain_x[i] = math.random(0, SCREEN_WIDTH - 1)


    -- Start above the screen.
    --
    -- Fixed point:
    -- 10 = 1 pixel
    --
    rain_y[i] =
        -(math.random(0, SCREEN_HEIGHT - 1) * 10)


    -- Original BennuGD:
    --
    -- rand(15, 44)
    --
    -- 1.5 .. 4.4 pixels/frame

    rain_speed[i] =
        math.random(15, 44)


    -- Original:
    --
    -- rand(4, 9)

    rain_len[i] =
        math.random(4, 9)


    -- Original:
    --
    -- rand(0, 3)

    rain_brightness[i] =
        math.random(0, 3)

end


-- ============================================
-- INITIALIZE
-- ============================================

for i = 1, MAX_DROPS do
    reset_drop(i)
end


-- ============================================
-- UPDATE
-- ============================================

function update()

    -- ========================================
    -- BACKGROUND
    -- ========================================

    -- Original BennuGD:
    --
    -- drawing_color(2114)
    -- draw_box(0, 0, 319, 199)
    --
    -- Lupinho uses palette index 0.

    ui.cls(0)


    -- ========================================
    -- RAIN
    -- ========================================

    for i = 1, MAX_DROPS do

        -- ====================================
        -- MOVE
        -- ====================================

        rain_y[i] =
            rain_y[i] + rain_speed[i]


        -- ====================================
        -- RESET
        -- ====================================

        if rain_y[i] > (SCREEN_HEIGHT * 10) then
            reset_drop(i)
        end


        -- ====================================
        -- FIXED POINT -> PIXEL
        -- ====================================

        local y =
            math.floor(rain_y[i] / 10)


        -- ====================================
        -- COLOR
        -- ====================================

        local color

        if rain_brightness[i] == 0 then

            -- Dark blue
            color = 1

        elseif rain_brightness[i] == 1 then

            -- Medium blue
            color = 2

        elseif rain_brightness[i] == 2 then

            -- Normal blue
            color = 3

        else

            -- Bright blue
            color = 4

        end


        -- ====================================
        -- DRAW
        -- ====================================

        ui.line(
            rain_x[i],
            y,
            rain_x[i],
            y + rain_len[i],
            color
        )

    end

end

