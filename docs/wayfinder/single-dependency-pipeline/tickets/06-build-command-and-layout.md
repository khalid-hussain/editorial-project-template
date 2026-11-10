---
id: 06
title: Build command and layout
labels: [wayfinder:grilling]
status: closed
assignee: khawarizmus
blocked_by: [01]
---

## Question

What does the user type, and where do things live? Decide the entry point (e.g. `pandoc lua build.lua docx`), whether a thin optional `make` alias survives for developers, how formats/options are passed, output naming (`dist/<date>-<title>.<ext>` from metadata instead of hardcoded names), how `content/` ordering is determined, and the new `utils/` layout (filters, data, templates, fonts, CSS).

The new build must not repeat these bugs from the current makefile:

- An undefined variable silently dropped the Word reference doc (`$(TEMPLATE)`). Every configured path must be checked to exist, and the build must fail if one doesn't.
- `mktemp -u` with backgrounded `gpp &` raced against Pandoc. The build must not run anything concurrently without waiting for it.
- macOS was handed a Windows `gpp.exe`. The build must not depend on platform-specific binaries.
- The EPUB name was hardcoded to `sealed-nectar`. Output names come from metadata.
- `init` failed if the directories already existed. Setup steps must be safe to re-run.

Input from [Pandoc capability baseline](01-pandoc-capability-baseline.md): the `pandoc lua` script must reproduce default templates, CSS/bibliography/CSL wiring, cross-file heading-ID de-duplication, CRLF output on Windows, and chunkedhtml unzipping; pin pandoc ≥ 3.9.0.1.

Input from [Error policy](05-error-policy.md):
- Configuration paths are validated before any content is processed.
- Exit codes are 0/1/2.
- A `--strict` flag applies final-edition strictness to a draft.
- No output is written when there are errors. Write to a temporary location, then move into `dist/`.

Input from [Edition options model](04-edition-options-model.md): the command accepts `key=value` overrides for any `template:` option. Precedence: command line > format section > book-wide value > default.

## Resolution

1. **One command, no wrappers.** There is no make and there are no `.sh`/`.cmd` scripts:
   ```
   pandoc lua build.lua docx
   pandoc lua build.lua docx epub edition=final
   pandoc lua build.lua all --strict
   ```
   No format means `docx`; `all` means every format. `key=value` options follow [Edition options model](04-edition-options-model.md). `--strict` follows [Error policy](05-error-policy.md).
2. **Housekeeping:** `pandoc lua build.lua clean` empties `dist/`. `pandoc lua build.lua help` lists formats, options and their current values. `init` is dropped because the build creates `dist/` itself.
3. **Output names:** `dist/<YYYYMMDD-HHMM>-<title-slug>[-final].<ext>`. chunkedhtml goes to a folder with that name, and html5 to a folder of per-file pages. Output is written to a temporary location and moved into `dist/` only when there are no errors.
4. **Content order:** `content/copyright.md` (if non-empty), then `frontmatter/`, `mainmatter/`, `backmatter/` (if present), sorted by file name within each. Each file is read separately (the old `--file-scope`), and duplicate heading IDs across files are de-duplicated.
5. **Date:** if `metadata.yaml` has no `date:`, the build fills in the build time (`Tue 10 Nov 2026 02:32PM`) and honours `SOURCE_DATE_EPOCH`. A literal date is kept. This replaces `\NOW`, the `DATE` placeholder and `inject-date.lua`. The template's `metadata.yaml` drops `date: DATE`.
6. **Layout:**
   ```
   build.lua
   metadata.yaml
   content/{copyright.md, frontmatter/, mainmatter/, backmatter/}
   utils/
     lua/        construct filter, ayah grammar, CSV parser, error reporter
     quran/      hafsData_v18.csv, surah-names.csv, SOURCE.md
     templates/  template.docx, template.odt
     css/  fonts/
     master.bib  chicago-fullnote-bibliography-short-title-subsequent.csl
   ```
7. **ODT reference doc:** `template.odt` is turned back on. If it turns out to be broken, record that in [Bugs to fix when porting](09-bugs-to-fix-when-porting.md).

The build script must also reproduce what the Pandoc CLI did for us: default templates for epub/chunkedhtml/html5, CSS/bibliography/CSL wiring, EPUB font embedding, CRLF output on Windows, and unzipping chunkedhtml. It must also avoid every old-makefile bug listed above: unchecked paths, concurrency races, platform binaries, hardcoded names, and setup that can't be re-run.
