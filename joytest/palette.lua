-- Paleta do cassete: corpo cinza, D-pad ciano, Y/X/A/B.

local function rgb555(r, g, b)
  return r + (g * 32) + (b * 1024)
end

Palette = {
  rgb555(0, 0, 0),    -- 0
  rgb555(0, 0, 0),    -- 1 fundo
  rgb555(4, 4, 5),    -- 2 contorno
  rgb555(24, 24, 25), -- 3 corpo
  rgb555(28, 28, 29), -- 4 brilho
  rgb555(19, 19, 20), -- 5 sombra corpo
  rgb555(13, 13, 14), -- 6 cavidade
  rgb555(10, 10, 11), -- 7 D-pad idle
  rgb555(8, 25, 28),  -- 8 ciano
  rgb555(6, 22, 8),   -- 9 Y verde
  rgb555(4, 8, 28),   -- 10 X azul
  rgb555(28, 5, 5),   -- 11 A vermelho
  rgb555(28, 25, 5),  -- 12 B amarelo
  rgb555(8, 8, 9),    -- 13 texto no pad
  rgb555(9, 9, 10),   -- 14 select/start
  rgb555(31, 31, 31), -- 15 branco
}
