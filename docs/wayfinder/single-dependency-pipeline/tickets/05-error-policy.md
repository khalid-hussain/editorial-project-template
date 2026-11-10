---
id: 05
title: Error policy
labels: [wayfinder:grilling]
status: closed
assignee: khawarizmus
blocked_by: [01]
---

## Question

What does "fail loudly" mean precisely? Decide which conditions are errors vs warnings (unknown construct class, unknown honorific key, bad ayah reference, missing citation key, leftover legacy backslash syntax), whether the build stops at the first error or reports all, and the message format (file, line if available, construct, suggestion such as "did you mean `pbuh`?").

Input from [Pandoc capability baseline](01-pandoc-capability-baseline.md): whether errors can cite a line number depends on the reader chosen in [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md). Clean messages need our own print + `os.exit`; `pandoc.log.silence` can enforce warnings-as-errors.

Input from [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md):
- Reader is `markdown`; line numbers come from searching the source text.
- Already decided as **errors**: near-miss class names (within 2 edits, with a suggestion), unknown honorific keys, bad ayah references, raw `custom-style`, Arabic after English inside a construct, leftover highlights in a final edition.
- Already decided as a **warning**: unknown classes, reported once per class.

What's left to decide: missing citation keys, leftover legacy backslash syntax, whether to collect all errors or stop at the first, the message format, and whether warnings can be promoted to errors.

## Resolution

1. **Collect everything, report at the end.** Every file is checked. All errors and warnings are printed together at the end. If there is any error, no output file is written.
2. **Compiler-style messages** that editors turn into links:
   ```
   content/frontmatter/03-preface.md:12: error: unknown class "hadeeth" (did you mean "hadith"?)
   content/mainmatter/01-lineage.md:40: warning: custom class "poem" (first use; 3 uses)

   2 errors, 1 warning. Nothing was written.
   ```
   If the line can't be found, the message shows the file plus a short quote of the offending text.
3. **A missing citation key is an error.** citeproc's default is a warning plus `???` in the document.
4. **Leftover GPP syntax is an error** (`\hon{`, `\AYAH_…`, `\HADITH_…`, `\trans{`, `\SC{`, `\surahref{`, `\note{`, `\c1{`…), and the message shows the replacement construct.
5. **Draft vs final:** warnings stay warnings in a draft and **become errors in a final edition**: unknown classes, Pandoc warnings, leftover highlights. `--strict` applies final strictness to a draft.
6. **Pandoc's own warnings** are captured with `pandoc.log.silence` and shown in the same format with their file attached, never as raw `[WARNING]` lines.
7. **Configuration is checked first.** Every configured path (reference doc, CSL, bibliography, CSS, fonts) must exist before any content is processed.
8. **Exit codes:**
   - `0` success, even with warnings
   - `1` content errors
   - `2` configuration or usage errors
   - an internal crash prints one line saying it's a template bug and asking for a report, never a Lua traceback

Already decided in [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md) and still standing:
- **Errors:** near-miss class names, unknown honorific keys, bad ayah references, raw `custom-style`, Arabic after English.
- **Warnings:** unknown classes, reported once per class.
