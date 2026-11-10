---
id: 11
title: Implement the construct filter
labels: [wayfinder:task]
status: closed
assignee: khawarizmus
blocked_by: []
---

## Question

Build the Lua filter that turns constructs into styled output for every format, exactly as decided in:
- [Construct vocabulary and syntax](03-construct-vocabulary-and-syntax.md)
- [Ayah reference grammar](02-ayah-reference-grammar.md); port the prototype's `AyahGrammar` module
- [Edition options model](04-edition-options-model.md)
- [Error policy](05-error-policy.md)
- [Qur'an data source](08-quran-data-source.md)

Also includes:
- `utils/quran/surah-names.csv`
- `utils/quran/SOURCE.md`
- a sample content file that exercises every construct and every error case

It must be runnable on its own with `pandoc --lua-filter` before the build script exists. The filter collects problems and doesn't exit, so the build can report them in one place.

Input from [Resolve-in-place workflow](07-resolve-in-place-workflow.md):
- The translation block's `lang`/`dir` comes from the book's `lang`, or `template: translation-lang:` if set.
- Written ayah Arabic is checked words-only against the data (mismatch is an error in every edition), then the output is rendered from the data.

## Resolution

Done. Modules in `utils/lua/`:

| Module | Job |
|---|---|
| `csv.lua` | RFC 4180 parser |
| `quran.lua` | data loading (34 ms), ayah tokenizing, script detection, canonical Arabic comparison |
| `ayah_grammar.lua` | port of the prototype; identical output on 24 references × 3 ayah-number settings |
| `options.lua` | option validation, precedence and suggestions |
| `suggest.lua` | edit distance and near-miss detection |
| `problems.lua` | problem collector and source-text line locator |
| `construct_filter.lua` | the filter; never prints or exits |
| `constructs.lua` | standalone `--lua-filter` entry |

Test bed:
- `tests/sample/`: a book using every construct
- `tests/errors/`: 16 cases, each stating the messages it expects
- `tests/run.lua`: 47 checks, all passing

**Findings that changed the implementation:**
- **Canonical equivalence is required.** The KFGQPC data stores combining marks in non-normalised order (e.g. shadda before kasra). Without canonical comparison, **33,129 of 77,430 Qur'an words** typed in an NFC-normalising editor would falsely "differ". `quran.canonical` decomposes the precomposed hamza/madda letters and orders marks by canonical combining class.
- **Pandoc's Lua treats byte 0xA0 as whitespace** in `%s`/`%S`, and that byte occurs inside UTF-8 Arabic digits. All splitting uses explicit ASCII classes. Multibyte characters never go inside `[...]` pattern classes.
- **Near-miss threshold scales with name length:** exact match only for names of 2 characters or fewer, 1 edit up to 5, 2 edits beyond. This stops short custom classes (`en`, `rtl`) being flagged as typos of `q` or `hon`.
- **HTML/EPUB output** wraps each construct in a `.quran`/`.hadith`/… div with `.quran-arabic`/`.quran-trans` inside, to match `trueilm.css`. Honorifics use the CSS's `in-text-honorifics`/`in-fn-honorifics`.
