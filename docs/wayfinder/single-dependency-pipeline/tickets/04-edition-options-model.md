---
id: 04
title: Edition options model
labels: [wayfinder:grilling]
status: closed
assignee: khawarizmus
blocked_by: [03]
---

## Question

How are build-time choices expressed now that GPP `-D` flags are gone? Current flags: `WORD`/`EPUB` (output family), `HONORIFICS_ENG` (Arabic vs English honorifics), `LONG_SURAH_REF`, `FINAL` (drop Arabic source from translation pairs), `IBN` (`ibn` vs `b.`), `NOW`. Decide where each lives (`metadata.yaml`, per-format defaults, command-line argument), their names, and their defaults.

Input from [Ayah reference grammar](02-ayah-reference-grammar.md): add an ayah-number preference (`always` default / `ended` / `never`); the short vs long citation is the existing `LONG_SURAH_REF`.

Input from [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md): `FINAL` now means two things: translation pairs keep only the English, and leftover highlights or notes fail the build. `IBN` is dropped. `NOW` moves to the build. Honorific language (`HONORIFICS_ENG`) and long citations (`LONG_SURAH_REF`) remain edition choices.

Input from [Error policy](05-error-policy.md): draft vs final also controls strictness, since warnings become errors in a final edition. `--strict` overrides this for a draft.

## Resolution

Options live in `metadata.yaml` under one `template:` key. Every option is optional:

```yaml
template:
  edition: draft          # draft | final
  honorifics: arabic      # arabic | english
  quran-citation: short   # short | long
  ayah-numbers: always    # always | ended | never
  epub:                   # optional per-format section: any option, any format
    honorifics: english
```

- **Precedence:** command line (`… docx edition=final`) > format section > book-wide value > built-in default (`draft`, `arabic`, `short`, `always`).
- **Per-format sections:** a section can exist for any output format and hold any option, so the author decides per format. The template's `metadata.yaml` ships with `epub: honorifics: english`, because Arabic honorifics currently disturb EPUB line spacing. Authors can change or delete that.
- **Validation:** an unknown option, format or value is a configuration error (exit 2) with a suggestion.
- **Edition:** `final` keeps only the English in translation pairs, fails on leftover highlights, and turns warnings into errors.
- **Output family:** `WORD` / `EPUB` aren't options; they follow from the output format.
- **Dropped:** `IBN`. `NOW` is replaced by the build filling the date.
- **No per-use honorific override:** `lang` on a `.hon` span is an error. Add it later if a book needs it.
