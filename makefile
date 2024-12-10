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
	gpp $(MACROS) $(METADATA) $(CONTENT) | \
	pandoc \
	-t docx \
	-o dist/$(TODAY).docx
