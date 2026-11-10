# Pandoc as the only build dependency

The build used four moving parts: GPP for macros, Pandoc for conversion and citations, a Jupyter/pandas notebook to fetch ayah text (copy-pasted by hand), and Make + bash to glue them. GPP fails silently on misspelled macros, the notebook ties authors to an editor like VS Code, and the bash-specific makefile does not run on stock Windows (and selects a Windows `gpp.exe` on macOS).

We decided to make **Pandoc the single dependency**: constructs are written in Pandoc-native Markdown (fenced divs, bracketed spans with attributes) and interpreted by Lua filters that ship inside Pandoc; the build itself is a `pandoc lua` script, so it is shell-agnostic; ayah text is resolved from the bundled CSV by Lua at build time. Strictness comes from walking Pandoc's AST and raising an error on any construct not in the vocabulary.

## Considered options

- **AsciiDoc (Asciidoctor)**: rejected. Adds Ruby + Asciidoctor and still needs Pandoc for DOCX; citation support (asciidoctor-bibtex) cannot match CSL Chicago full-note footnotes; its "strictness" is an AST property Pandoc already has.
- **Typst alone**: rejected as the primary engine because it cannot emit DOCX or EPUB, which translators and readers need. Kept as a future additional output.
- **Quarto**: rejected; large bundle, wraps Pandoc anyway.
- **Keep GPP, swap glue for Python/just**: rejected; same silent failures, no fewer dependencies.

## Consequences

- Authoring syntax changes; existing content needs a one-time conversion.
- Error quality depends on what source positions Pandoc exposes to Lua filters.
