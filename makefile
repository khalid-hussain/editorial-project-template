SHELL = /bin/bash
PLATFORM := $(shell uname)
TODAY = $(shell date +'%Y%m%d-%H%M')
MACROS = utils/gpp/macros.md
TEMPLATE = utils/template.docx
CSL = utils/chicago-fullnote-bibliography-short-title-subsequent.csl

ifeq ($(PLATFORM),Linux)
GPP = gpp
else
GPP = utils/gpp/gpp.exe
endif

MACROS = utils/gpp/_macros.pp

METADATA = metadata.yaml
FM = content/frontmatter/*.md
MM = content/mainmatter/*.md
CONTENT = $(FM) $(MM)

default: docx

docx:
	for file in $(CONTENT); do \
		fifo=$$(mktemp -u); \
		FIFOS+=("$$fifo"); \
		cat $(MACROS) "$$file" | \
		$(GPP) -DWORD -x -o "$$fifo" & \
	done; \
	pandoc metadata.yaml "$${FIFOS[@]}" -f markdown -t docx \
	--citeproc --csl $(CSL) \
	--reference-doc=$(TEMPLATE) \
	--file-scope \
	-o dist/$(TODAY).docx

epub:
	for file in $(CONTENT); do \
		fifo=$$(mktemp -u); \
		FIFOS+=("$$fifo"); \
		cat $(MACROS) "$$file" | \
		$(GPP) -DEPUB -x -o "$$fifo" & \
	done; \
	pandoc metadata.yaml "$${FIFOS[@]}" \
	-f markdown \
	-t epub3 -s \
	--css=./utils/css/boilerplate.css \
	--css=./utils/css/trueilm.css \
	--epub-embed-font=./utils/fonts/UthmanTN1Ver20.ttf \
	--epub-embed-font=./utils/fonts/UthmanicHafs_V22.ttf \
	--citeproc --csl $(CSL) \
	--file-scope \
	-o dist/$(TODAY)-sealed-nectar.epub

