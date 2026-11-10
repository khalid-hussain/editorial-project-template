---
id: 10
title: Convert existing content to the new constructs
labels: [wayfinder:task]
status: closed
assignee: khawarizmus
blocked_by: []
---

## Question

Write a one-time converter (a `pandoc lua` script or plain Lua; no new dependency) that rewrites GPP syntax in `content/**/*.md` into the constructs from [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md):
- `\hon{\X}{\Y}` → `[x]{.hon}`
- `\AYAH_AR_START…\AYAH_END` → `::: {.ayah ref=…}`. The ref is recovered from the trailing `(Qs:a)` where present, or flagged for a human.
- `\HADITH_*` → `::: hadith`; `\AR_/EN_` → `::: arabic-quote`
- `\trans{ar}{en}` → `::: trans`
- `\note`/`\c1`–`\c4`/`\warn` → spans; `\SC` → `.smallcaps`; `\surahref` → `.q`
- raw `left-ragged` → `::: signature`

The converter must report anything it can't convert instead of skipping it. While converting, fix the content items in [Bugs to fix when porting](09-bugs-to-fix-when-porting.md). The converted files are left in the working tree for review.

**Proving the migration:** the content is small (two files with constructs), so a human reviews the converter's report plus the diff, and the converted files must build with zero errors. Comparing against the old pipeline's output isn't required: it can't run on macOS (Windows-only `gpp.exe`), and its DOCX output was already wrong (the reference doc was silently dropped).

## Resolution

Done with `utils/lua/convert-gpp.lua`. **Deviation from the plan:** it is kept rather than deleted, because other books still written with GPP macros need it. The README documents it under "Moving an older book over".

- It converted `03-preface.md` and `01-lineage.md`. It found the preface ayah's reference **83:26 from the Arabic text alone** (the source had no `(Q…)`), and it can find partial quotes too, emitting `|prefix-N` / `|suffix-N` slices.
- Running it again changes nothing, and converting a fresh copy of the original gives byte-identical files. It leaves empty files and final-newline state alone.
- The converted book builds in all 5 formats with 0 errors and 0 warnings. A final edition fails only on the two flagged lineage paragraphs (see [Bugs to fix when porting](09-bugs-to-fix-when-porting.md)).
- Review: `git diff content/`.
