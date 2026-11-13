---
id: 16
title: "PR review: ICML, timestamps, raw custom styles"
labels: [wayfinder:task]
status: closed
assignee: khawarizmus
blocked_by: []
---

## Question

The owner's review of PR #1 asked for two changes in this PR:

1. ICML output, with no timestamp in file names by default (each build overwrites) and a metadata option to turn timestamps on.
2. Raw `custom-style` allowed, along with any Pandoc Markdown, because some books need elements the constructs don't cover. The user keeps the templates in step.

## Resolution

1. **ICML:** `icml` is a format (it's included in `all`), styled through `custom-style` like DOCX/ODT. It uses Pandoc's standalone ICML template, which InDesign can Place. Output names are `dist/<title-slug>[-final].<ext>` and each build overwrites. The new option `timestamp: true` (book-wide, per-format, or `timestamp=true` on the command line) restores `<YYYYMMDD-HHMM>-`. **Supersedes** output naming in [Build command and layout](06-build-command-and-layout.md).
2. **Raw custom styles:** allowed. **Supersedes** "raw custom-style is an error" in [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md). Two checks remain:
   - A near-miss of a style the filter emits (`quran-arabc`) is an error with a suggestion.
   - A style missing from the format's reference doc (`template.docx` / `template.odt`) is a warning, once per style. Like every warning, it fails a final edition. ICML and HTML have no reference doc, so they get no check.
   - New module: `utils/lua/reference_styles.lua`.

Tests: 54 checks pass.

The owner's other requests are follow-ups, listed under Out of scope on the map: locator checks, heading capitalisation, and Buckwalter transliteration.
