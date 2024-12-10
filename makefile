TODAY = $(shell date +'%Y%m%d-%H%M')
MACROS = utils/gpp/macros.md
TEMPLATE = template.docx
CSL = chicago-fullnote-bibliography-short-title-subsequent.csl

GPP = utils/gpp/gpp.exe
MACROS = utils/gpp/_macros.pp

METADATA = metadata.yaml
FM = content/frontmatter/*.md
MM = content/mainmatter/*.md
CONTENT = $(FM) $(MM)

default: docx

docx:
	cat $(MACROS) $(METADATA) $(CONTENT) | \
	gpp | \
	pandoc \
	-t docx \
	-o dist/$(TODAY).docx

epub:
	cat $(MACROS) $(METADATA) $(CONTENT) | \
	gpp | \
	pandoc \
	-t epub3 \
	-o dist/$(TODAY).epub
