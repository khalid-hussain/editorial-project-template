---
title: Single-dependency build pipeline
labels: [wayfinder:map]
---

## Destination

The template builds every current output format (DOCX, ODT, EPUB, chunked HTML, HTML5) from one command, on any OS and shell, with **Pandoc as the only dependency**; GPP, Jupyter/pandas, Make and bash are gone; existing content is migrated; unknown or malformed constructs fail the build loudly.

## Notes

- **Execution is in scope.** The destination is the migration *done*, not just planned. Once the decisions an implementation slice depends on are closed, graduate that slice into a `wayfinder:task` ticket.
- Chosen approach: [Pandoc as the only build dependency](../../adr/0001-pandoc-as-the-only-dependency.md) (Lua filters + `pandoc lua` build script). AsciiDoc ruled out.
- Vocabulary: [Glossary](../../GLOSSARY.md). Use *construct*, not *macro*.
- Users are both non-developer translators/editors and developers: setup must be "install Pandoc, run one command".
- Stay flexible for the main formats Pandoc supports; don't design anything that blocks Typst/PDF later.
- Git: the human commits. Agents never commit, push, stage or stash; research findings go in `research/` in the working tree, not on a branch.
- Implementation order and steps: [implementation plan](implementation-plan.md).
- Grilling tickets: consult the `grilling` and `domain-modeling` skills.
- **Fix bugs along the way.** Any bug found while working a ticket is fixed as part of that work, or appended to [Bugs to fix when porting](tickets/09-bugs-to-fix-when-porting.md). The old pipeline is not patched; only bugs that would carry over are fixed.

## Decisions so far

<!-- one line per closed ticket -->

- [Pandoc capability baseline](tickets/01-pandoc-capability-baseline.md): pure Pandoc suffices, pin ≥ 3.9.0.1; `pandoc lua` can run the build; line numbers vs `[@key]` citations is a reader trade-off (`commonmark_x` vs `markdown`).
- [Ayah reference grammar](tickets/02-ayah-reference-grammar.md): `surah[:ayah[-ayah]]` parts joined by `;`, composable `|prefix-N` / `|suffix-N` word slices; numbers after every quoted ayah (after the `…`), ۞ dropped, waqf kept, gaps marked ` … `, merged citations, strict errors.
- [Construct vocabulary and syntax](tickets/03-construct-vocabulary-and-syntax.md): `markdown` reader; one div/span per construct (`.hon`, `.ayah`, `hadith`, `arabic-quote`, `trans`, highlights, `.q`, `signature`), Arabic paragraphs first and split by script, context-automatic styles; near-miss classes error, unknown classes warn.
- [Error policy](tickets/05-error-policy.md): collect all problems and report at the end, writing nothing on error; `file:line: error:` messages; missing citations and leftover GPP syntax are errors; warnings become errors in final editions (`--strict` for drafts); config checked first; exit 0/1/2, no tracebacks.
- [Edition options model](tickets/04-edition-options-model.md): `template:` block in `metadata.yaml` (`edition`, `honorifics`, `quran-citation`, `ayah-numbers`), optional per-format sections, `key=value` command-line overrides; validated; no per-use honorific override.
- [Qur'an data source](tickets/08-quran-data-source.md): ship the KFGQPC CSV unmodified and parse at build time; transliterations move to `surah-names.csv`; provenance in `SOURCE.md`; fixed paths; Python removed.
- [Build command and layout](tickets/06-build-command-and-layout.md): `pandoc lua build.lua [formats] [key=value] [--strict]`, plus `clean`/`help`; no make or wrappers; dated, title-slugged outputs; fixed content order including `copyright.md`; date auto-filled; tidied `utils/`; ODT reference doc back on.
- [Resolve-in-place workflow](tickets/07-resolve-in-place-workflow.md): `resolve` / `resolve --refresh` / `unresolve` write ayah Arabic into the one-div source as text edits; words-only check, mismatch always an error; output rendered from data as two styled blocks; translation `lang` from the book (`translation-lang` override).
- [Implement the construct filter](tickets/11-implement-construct-filter.md): `utils/lua/` modules + `tests/` (47 checks); Arabic compared by canonical equivalence (43% of Qur'an words would otherwise falsely mismatch).
- [Implement the build script](tickets/13-implement-the-build-script.md): `build.lua` with every decided command, check and writer; verified on macOS, Windows still to try.
- [Convert existing content to the new constructs](tickets/10-convert-existing-content.md): `convert-gpp.lua` (kept for other books) converted the content and found the preface ayah 83:26 from its Arabic.
- [Bugs to fix when porting](tickets/09-bugs-to-fix-when-porting.md): honorific table fixed, content fixed or flagged; `template.docx` style gaps listed in the README TODO.
- [Retire the old pipeline](tickets/12-retire-the-old-pipeline.md): GPP, makefile, Python and notebooks deleted.
- [Rewrite README and authoring guide](tickets/14-rewrite-readme-and-authoring-guide.md): new README and `docs/authoring-guide.md`.

## Not yet specified

_Nothing left: every remaining step is a ticket. See the [implementation plan](implementation-plan.md)._


## Out of scope

- **KFGQPC data/font licence confirmation**: a legal question for the project owner, not a pipeline decision; recorded as unconfirmed in `utils/quran/SOURCE.md` ([Qur'an data source](tickets/08-quran-data-source.md)).
- **Data-backed hadith lookup**: hadith stays typed-in text; a lookup like ayat is a new feature, not part of the migration.
- **CI**: no automated build on push for now; the sample content and test runner are run by hand.
- **Typst / PDF output**: deferred to a later effort; only constraint here is not blocking it.
- **README TODOs on Word template design** (fonts, Arabic/English alignment): template styling, not pipeline.
