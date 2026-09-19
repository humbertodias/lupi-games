# Converte os PNG do Pang pelo lupi-codec (palette.lua, manifesto, bitmaps).
# Uso: make          # codec + instala no diretorio do cassete
#      make codec    # so gera .build/current
#      make clean

LUA        ?= lua
CODEC      ?= $(abspath $(CURDIR)/../../lupi-codec)
OUT        ?= $(CURDIR)/.build
STAGE      := $(OUT)/src
CODEC_OUT  := $(OUT)/codec
CURRENT    := $(CODEC_OUT)/current
COLORMAP   := $(OUT)/colormap.png

.PHONY: all codec install clean help stage

all: install

help:
	@echo "make          — codec e copia palette/manifest/bitmaps para este cassete"
	@echo "make codec    — so processa PNG em $(OUT)"
	@echo "make clean    — remove .build e artefatos gerados"
	@echo "CODEC=$(CODEC)"

stage:
	@command -v magick >/dev/null || { echo "ImageMagick (magick) nao encontrado"; exit 1; }
	@rm -rf "$(STAGE)"
	@mkdir -p "$(STAGE)/img" "$(OUT)/rgb" "$(OUT)/mask"
	cp -f "$(CURDIR)/game.lua" "$(STAGE)/"
	@test ! -f "$(CURDIR)/lupi.yaml" || cp -f "$(CURDIR)/lupi.yaml" "$(STAGE)/"
	cp -f "$(CURDIR)/img/"*.png "$(STAGE)/img/"
	@# Magenta (#FF00FF) e alpha viram mascara. O remap do magick zera o alpha
	@# e pintava o fundo de preto — por isso a mascara e reaplicada depois.
	@for f in "$(STAGE)/img/"*.png; do \
		b=$$(basename "$$f"); \
		magick "$$f" -transparent '#FF00FF' -alpha extract -threshold 50% "$(OUT)/mask/$$b"; \
		magick "$$f" -transparent '#FF00FF' -background '#FF00FF' -alpha remove -alpha off \
			-posterize 32 "$(OUT)/rgb/$$b"; \
	done
	magick "$(OUT)/rgb/"*.png +append -colors 200 "$(COLORMAP)"
	@for f in "$(STAGE)/img/"*.png; do \
		b=$$(basename "$$f"); \
		magick "$(OUT)/rgb/$$b" -dither None -remap "$(COLORMAP)" \
			"$(OUT)/mask/$$b" -compose CopyOpacity -composite PNG32:"$$f"; \
	done

codec: stage
	@command -v $(LUA) >/dev/null || { echo "lua nao encontrado"; exit 1; }
	@test -f "$(CODEC)/run.lua" || { echo "lupi-codec nao encontrado em $(CODEC)"; echo "Passe CODEC=/caminho/para/lupi-codec"; exit 1; }
	@rm -rf "$(CODEC_OUT)"
	@mkdir -p "$(CODEC_OUT)"
	cd "$(CODEC)" && $(LUA) run.lua "$(STAGE)" "$(CODEC_OUT)"

install: codec
	@test -f "$(CURRENT)/palette.lua" || { echo "release vazio em $(CURRENT)"; exit 1; }
	cp -f "$(CURRENT)/palette.lua" "$(CURDIR)/palette.lua"
	cp -f "$(CURRENT)/lupi_manifest.txt" "$(CURDIR)/lupi_manifest.txt"
	@mkdir -p "$(CURDIR)/img"
	find "$(CURRENT)/img" -type f ! -name '*.png' -exec cp -f {} "$(CURDIR)/img/" \;
	@echo "Instalado: palette.lua, lupi_manifest.txt e bitmaps em img/"

clean:
	rm -rf "$(OUT)"
	rm -f "$(CURDIR)/palette.lua" "$(CURDIR)/lupi_manifest.txt"
	find "$(CURDIR)/img" -type f ! -name '*.png' -delete
