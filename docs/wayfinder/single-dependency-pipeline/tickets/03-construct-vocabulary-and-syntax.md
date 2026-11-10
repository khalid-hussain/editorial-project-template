---
id: 03
title: Construct vocabulary and syntax
labels: [wayfinder:grilling]
status: closed
assignee: khawarizmus
blocked_by: [01]
---

## Question

What is the complete construct vocabulary and the Pandoc-native spelling of each? Today's GPP constructs: honorifics (`\hon{\PBUH}{\BODY}`, header/body/footer placement), ayah and hadith blocks (Arabic + translation, plus `LIST_` variants), generic `AR_/EN_` blocks, translation pairs (`\trans{ar}{en}`), editorial highlights (`\note`, `\c1`–`\c4`, `\warn`), small caps (`\SC`), `\BIN`/`\BINT`, `\surahref`, `\NOW`. For each: keep, merge, or drop; div vs span; class and attribute names; and how it renders per output format (DOCX/ODT `custom-style`, EPUB/HTML classes).

Input from [Pandoc capability baseline](01-pandoc-capability-baseline.md): choose the reader. `markdown` has `[@key]` citations but no source positions; `commonmark_x` has line numbers but no citations and leaves `.smallcaps` as a plain span. Options: no line numbers, our own citation parsing on `commonmark_x`, or parsing each file twice.

## Resolution

**Reader:** use pandoc `markdown`, which keeps `[@key]` citations. Pandoc gives no line numbers here, so to report one the error reporter searches the source file for the construct's distinctive text (e.g. `ref="21:107"`) and prints `file:line`.

**Vocabulary.** Each construct is written as one div or span in the source. The build expands it into whatever styled blocks the output needs.

| Construct | Source | Output (DOCX/ODT custom-style · HTML/EPUB class) |
|---|---|---|
| Honorific | `[pbuh]{.hon}`. Keys are today's names in lowercase (`swt`, `azwjl`, `pbuh`, `s-him` … `h-thm`); an unknown key is an error | `Char Header/Body/Footer Honorifics`, chosen **automatically** from context (heading, body, footnote). Arabic or English text depends on the edition |
| Ayah | `::: {.ayah ref="83:26"}` + optional Arabic paragraph(s) + optional English translation. `ref` follows [Ayah reference grammar](02-ayah-reference-grammar.md) | Two blocks: `quran-arabic`, then `quran-trans`. `list-` variants are chosen **automatically** inside list items. The citation is appended to the translation automatically; `cite=false` turns it off |
| Hadith | `::: hadith` + Arabic and/or English paragraphs | `hadith-arabic` + `hadith-trans` (`list-` variants automatic) |
| Arabic quote | `::: arabic-quote` (was `AR_/EN_START`) | `arabic-text` + `arabic-text-trans` |
| Translation pair | `::: trans` (was `\trans{ar}{en}`) | `Arabic Source` + `English Target`. The final edition keeps the English only |
| Highlights | `[text]{.note}` (rendered "NOTE: …"), `.c1`–`.c4`, `.warn` | `Highlight C1`–`C4`, `Highlight Warn`. **A final edition fails if any remain** |
| Small caps | native `[term]{.smallcaps}` (was `\SC`) | native |
| Inline Qur'an citation | `[21:107]{.q}` (was `\surahref`), using the ayah-reference grammar | `(Q21:107)`, or the long form if the edition asks for it |
| Signature | `::: signature` (replaces raw `custom-style="left-ragged"`) | `left-ragged` |

**Arabic + English inside one div** (ayah, hadith, arabic-quote, trans):
- A paragraph whose letters are mostly Arabic script counts as Arabic. This rule keeps an English paragraph with an Arabic honorific in it as English.
- Any combination is allowed: Arabic only, English only, or both. When both are present, Arabic comes first in the input and in the output.
- English followed by Arabic, or the two interleaved, is an error.
- For an ayah, if no Arabic is written, it is fetched from `ref`. Arabic written by hand is review text; [Resolve-in-place workflow](07-resolve-in-place-workflow.md) decides what happens when it differs from the data.

**Dropped:** `\BIN`/`\BINT` (write "ibn" in full; add back if a book needs it); `\NOW` (the build fills the date, see [Build command and layout](06-build-command-and-layout.md)); `\SC`.

**Strictness:**
- Raw `custom-style` in content is forbidden. Only the filter knows Word style names.
- A class that is a **near miss** of a construct name is an **error** with a suggestion. Near miss means within 2 edits, ignoring case, `-`/`_`, and a trailing `s`.
- Any other unknown class is allowed and passes through Pandoc unchanged (HTML/EPUB keep it; DOCX/ODT ignore it). The build warns once per unknown class, not per use.
- Pandoc built-ins like `smallcaps`, `unnumbered` and `underline` are allowed silently.

**Style names** stay exactly as they are in `template.docx`.
