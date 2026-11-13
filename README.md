# Editorial Project Template

A template for editing and translating Islamic books. You write in Markdown and get DOCX, ODT, ICML (InDesign), EPUB and HTML out of it. Qurʾān quotations are filled in from the bundled Ḥafṣ text, so they are never copied by hand.

## Setup

You need one program: **[Pandoc] 3.9.0.1 or newer**.

| System | Install |
|---|---|
| macOS | `brew install pandoc` |
| Windows | `winget install JohnMacFarlane.Pandoc` |
| Linux | the `.deb` or tarball from the [Pandoc releases page](https://github.com/jgm/pandoc/releases). Distribution packages are usually too old. |

Check it with `pandoc --version`. Nothing else is needed: no Make, no Python, no particular shell or editor.

## Building

Run every command from this folder:

```
pandoc lua build.lua                        a DOCX draft
pandoc lua build.lua docx epub              several formats
pandoc lua build.lua all                    docx, odt, icml, epub, chunkedhtml and html5
pandoc lua build.lua epub edition=final     change an option for one build
pandoc lua build.lua help                   formats, options and their current values
pandoc lua build.lua clean                  delete dist/
```

Output goes to `dist/`, named after the book title, for example `dist/concise-biography-of-the-prophet.docx`. Each build overwrites the last. Set `timestamp: true` to keep each build: `dist/20261110-1432-concise-biography-of-the-prophet.docx`.

**If something is wrong, nothing is written.** The build lists every problem with its file and line, then stops:

```
content/frontmatter/03-preface.md:12: error: unknown class "hadeeth" (did you mean "hadith"?)

1 error, 0 warnings. Nothing was written.
```

Warnings (for example a class the template doesn't know) don't stop a draft. A **final** edition treats every warning as an error. Add `--strict` to a draft build to get the same checks.

## Starting a book

1. Clone the repository.
2. Fill in `metadata.yaml`: title, author, language, and the `template:` options (see below).
3. Write Markdown files in `content/frontmatter/`, `content/mainmatter/` and, if needed, `content/backmatter/`. Files are built in name order, so number them: `01-preface.md`, `02-…`. `content/copyright.md` comes first if it has any text.
   - Front-matter headings are usually unnumbered: `# Preface {.unnumbered}`.
   - Most books split naturally into one file per chapter. If a long book doesn't, split it anyway.
4. Run `pandoc lua build.lua`.

## Writing

The **[authoring guide](docs/authoring-guide.md)** covers everything with examples. In short:

| You write | You get |
|---|---|
| `[pbuh]{.hon}` | an honorific in Arabic or English, styled for heading, body or footnote |
| `::: {.ayah ref="21:107"}` + translation + `:::` | the ayah in Arabic from the Ḥafṣ data, the translation, and `(Q21:107)` |
| `::: hadith` + Arabic + translation + `:::` | a hadith with its translation |
| `::: trans` + Arabic + English + `:::` | a translation pair; the final edition keeps only the English |
| `[21:107]{.q}` | the citation `(Q21:107)` |
| `[text]{.note}`, `.c1`–`.c4`, `.warn` | editorial highlights (drafts only) |
| `[@saadi02, 12]` | a Chicago full-note citation from `utils/master.bib` |
| `::: {custom-style="Basmalah"}` | any Word/ODT/ICML style of your own; add it to the template so it isn't unstyled |

To see the ayah Arabic in your source files while reviewing, run `pandoc lua build.lua resolve`. `unresolve` takes it out again.

## Options

Set options in `metadata.yaml`. Override any of them for one build on the command line (`edition=final`).

```yaml
template:
  edition: draft          # draft | final
  honorifics: arabic      # arabic | english
  quran-citation: short   # short (Q21:107) | long (al-Anbiyāʾ, Q21:107)
  ayah-numbers: always    # always | ended | never
  timestamp: false        # true puts the build date and time in file names
  epub:                   # any format can override any option
    honorifics: english
```

## Fonts

Arabic content uses the fonts from the King Fahd Glorious Qurʾān Printing Complex (KFGQPC), so Arabic line height stays consistent. Other fonts work too if the line height can be kept, e.g. in InDesign. That is harder, if not impossible, in EPUB. See `utils/quran/SOURCE.md` for where the data and fonts come from; their redistribution terms are unconfirmed.

## References

Citations use Pandoc's citation processor with the [Chicago fullnote (short title subsequent)] style. It is preferred over "Ibid."-style citations because "Ibid." is awkward in digital formats such as EPUB3. It also lets you add other content to a footnote alongside the reference.

Use citations only if the book is being re-edited. Otherwise, copy reference content as it is.

## Moving an older book over

Books written with the old GPP macros (`\hon{\PBUH}{\BODY}`, `\AYAH_AR_START`, `\trans{…}{…}`) can be converted in one step:

```
pandoc lua utils/lua/convert-gpp.lua
```

It rewrites `content/` in place, finds each ayah's reference from its Arabic text where the `(Q…)` is missing, and lists anything it couldn't convert. Review the diff before committing. Any old syntax left over makes the build fail and name the replacement.

## For developers

- `build.lua` is the build. The construct filter and its helpers are in `utils/lua/`. `utils/lua/constructs.lua` also works as a plain filter: `pandoc file.md --lua-filter utils/lua/constructs.lua -o out.docx`.
- `pandoc lua tests/run.lua` runs the self-test: ayah grammar, options, every error case in `tests/errors/`, and a full build of `tests/sample/`.
- Design decisions and their reasons are in `docs/` (`docs/adr/` and `docs/wayfinder/`).

## Guidelines

1. Leave one blank line between a heading and its first paragraph.
2. Put footnote content right after the paragraph that holds its marker.
3. Hadith references need to be typed at the end of their translations. Ayah references are added automatically.
4. The conventional order of English book front matter is:
   1. Dedication
   2. Foreword
   3. Preface
   4. Acknowledgements
   5. Contents
5. If front-matter content ends with its author's details (name, date and place of writing), wrap them in a signature block, ending each line except the last with two spaces:

   ```
   ::: signature
   Content Line 1  
   Content Line 2  
   Content Line 3
   :::
   ```

   It is aligned left even when the content is right-aligned, because EPUB readers may override right alignment.

## TODO

1. Check the design font in the Word template.
1. Fix the English Target / Arabic Source alignment in the Word template.
1. Add the styles the build emits that `utils/templates/template.docx` does not define yet: `Char Header/Body/Footer Honorifics` (the template has `honorifics_body`), `arabic-text`, `arabic-text-trans`, `Arabic Source`, `English Target`, `Highlight C1`–`C4`, `Highlight Warn`, and the `list-quran-*` / `list-hadith-*` styles. Until then Word creates them unstyled. `template.odt` defines almost none of them.

## Roadmap

1. Add Typst as an export option with decent A4 and A5 templates.

### Typst template

The Typst template should:

1. Allow user-defined fonts.
1. Allow user-defined page sizes and margin sizes.
1. Predefine fonts for English and Arabic, which the user can override.
1. Predefine functions for Qurʾān text, ḥadīth text, and translation blocks.
1. Use a custom bibliography style for common ḥadīth books, e.g. _Ṣaḥīḥ al-Bukhārī_, vol. 2, p. 100, #500, instead of _Ṣaḥīḥ al-Bukhārī_, Muḥammad ibn Ismāʿīl al-Bukhārī (Dār al-Taʾṣīl, Cairo: 2000) vol. 2, p. 100, #500.

[Pandoc]: https://pandoc.org/
[Chicago fullnote (short title subsequent)]: https://www.zotero.org/styles/chicago-fullnote-bibliography-short-title-subsequent
