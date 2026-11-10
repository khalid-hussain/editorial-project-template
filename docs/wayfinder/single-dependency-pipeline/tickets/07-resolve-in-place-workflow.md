---
id: 07
title: Resolve-in-place workflow
labels: [wayfinder:grilling]
status: closed
assignee: khawarizmus
blocked_by: [02]
---

## Question

Besides resolving ayah text at build time, editors want to see the Arabic in the source for review. How does a "write it into the file" command work: what does it write and where (inside the ayah block, keeping the reference), how is it re-run safely, what happens when hand-edited text disagrees with the Qur'an data (warn, error, or override), and how do authors opt in per block or per file?

Input from [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md): an ayah is one div. The Arabic written into it is a leading Arabic-script paragraph inside that same div; no inner div, no attribute.

## Resolution

1. **`pandoc lua build.lua resolve [files…]`** (defaults to all content files). For each ayah div with no Arabic, it inserts the Arabic as the first paragraph inside the div, right after the `::: {.ayah ref=…}` line. The source stays **one div**, as decided in [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md). The command edits text in place and never re-writes the file through Pandoc's writer, so every other byte stays untouched. It prints each change as `file:line: inserted <ref>`.
2. **Comparison is words-only.** Ayah numbers, `…`, ۞ and whitespace are ignored, so changing `ayah-numbers` never makes a resolved file wrong. Waqf marks and diacritics must match exactly.
3. **A mismatch is an error in every edition.** The message shows the written text and the data text side by side.
4. **Fixing:** plain `resolve` only fills gaps and never touches existing Arabic, so it is always safe to re-run. `resolve --refresh` overwrites mismatched Arabic with the data.
5. **The build renders from the data** with the current options, once the written text passes the check. The written text exists only for review.
6. **`unresolve [files…]`** removes Arabic paragraphs that match the data, taking the source back to the short form. It reports mismatches instead of removing them.
7. **Scope:** only ayah blocks. Hadith, Arabic quotes and trans have no data source.

**Output stays two styled blocks** for every Arabic + translation construct. The Arabic block gets its style, `lang="ar"`, `dir="rtl"` and the Arabic font. **The translation block takes its language from the book's `lang`** (e.g. `en-US`), with `dir="rtl"` for right-to-left languages such as Urdu. An optional `template: translation-lang:` overrides it when the translation language differs from the book's. This adds one option to [Edition options model](04-edition-options-model.md); it follows the same precedence and validation rules.
