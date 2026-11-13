# Authoring guide

How to write a book with this template. Everything is ordinary Markdown plus a small set of **constructs**: named blocks and spans that carry editorial meaning. The build turns each construct into the right styles for Word, EPUB and HTML, so you never type a style name.

If you mistype a construct, the build stops and tells you where:

```
content/mainmatter/02-hijrah.md:41: error: unknown honorific "pbhu" (did you mean "pbuh"?)
```

## Honorifics

Write the short key in square brackets with `{.hon}`:

```markdown
The Prophet [pbuh]{.hon} said …
ʿUmar [p-him]{.hon} replied …
```

The build writes the full phrase in Arabic or English, depending on the `honorifics` option. It also picks the right style for a heading, body text or footnote.

| Key | Arabic | English |
|---|---|---|
| `swt` | سبحانه وتعالى | (Exalted be He) |
| `azwjl` | عزَّ وجلَّ | (Exalted and Glorified be He) |
| `pbuh` | صلى الله عليه وسلم | (May peace and blessings be on him) |
| `pbuhs` | صلى الله عليه وسلم | (Peace be on him) |
| `s-him` `s-her` `s-two` `s-thm` | عليه / عليها / عليهما / عليهم السلام | (Peace be on him / her / them both / them) |
| `ss-him` `ss-her` `ss-two` `ss-thm` | عليه / عليها / عليهما / عليهم الصلاة والسلام | (Prayers and peace be on him / her / them both / them) |
| `p-him` `p-her` `p-two` `p-thm` | رضي الله عنه / عنها / عنهما / عنهم | (May Allāh be pleased with him / her / them both / them) |
| `m-him` `m-her` `m-two` `m-thm` | رحمه / رحمها / رحمهما / رحمهم الله تعالى | (May Allāh have mercy on him / her / them both / them) |
| `h-him` `h-her` `h-two` `h-thm` | حفظه / حفظها / حفظهما / حفظهم الله تعالى | (May Allāh preserve him / her / them both / them) |

## Qurʾān: ayah blocks

Give the reference. The build fetches the Arabic from the bundled Ḥafṣ text and adds the citation after your translation:

```markdown
::: {.ayah ref="21:107"}
We have not sent you except as a mercy to the worlds.
:::
```

This produces the Arabic with its ayah number, then *We have not sent you except as a mercy to the worlds. (Q21:107)*.

### What `ref` can say

| Reference | Quotes |
|---|---|
| `21:107` | one ayah |
| `2:1-3` | a range (inside one surah) |
| `112` | a whole surah |
| `2:1-3; 2:5` | several references, joined with `;` |
| `21:107\|prefix-3` | the first 3 words |
| `21:107\|suffix-2` | the last 2 words |
| `2:255\|prefix-10\|suffix-4` | slices apply left to right: the last 4 of the first 10 words, i.e. words 7–10 |
| `2:1-3\|suffix-8` | a slice on a range counts words across all its ayat |

Write the `|` inside the quotes as a plain `|`. The backslash in the table above is only Markdown table escaping.

Rules the build follows:

- Only words are counted. Ayah numbers and the ۞ mark never are.
- A cut is shown with `…`. A cut ayah reads *words … number*.
- Ayat that are not next to each other are joined with ` … `.
- ۞ is dropped. Waqf signs (ۚ ۖ ۗ …) are always kept.
- Citations merge where they can: `2:1-3; 2:4` cites as `(Q2:1–4)`.
- `cite=false` leaves out the citation: `::: {.ayah ref="112" cite=false}`.

The build stops on a surah or ayah that doesn't exist, a backwards range, a range that crosses surahs (use `;`), or a slice longer than the quoted text.

### Seeing the Arabic while you review

```
pandoc lua build.lua resolve            write the Arabic into every ayah block that has none
pandoc lua build.lua resolve --refresh  … and replace Arabic that differs from the Qurʾān text
pandoc lua build.lua unresolve          take the Arabic out again
```

`resolve` writes the Arabic as the first paragraph inside the block. Nothing else in the file changes. Arabic written in an ayah block is always checked word for word against the Qurʾān text, and a difference stops the build. Your editor normalising the Unicode doesn't count as a difference. The book itself is always printed from the data.

### Inline citations

`[21:107]{.q}` becomes `(Q21:107)`. Every reference form above works.

## Hadith, Arabic quotes and translation pairs

These three share one shape: Arabic paragraph(s) first, then the translation, inside one block. The build tells them apart by script.

```markdown
::: hadith
إنما الأعمال بالنيات.

“Deeds are by intention.”
:::

::: arabic-quote
العلم قبل القول والعمل.

Knowledge precedes speech and action.
:::

::: trans
هو أبو القاسم محمد.

He is Abū al-Qāsim Muḥammad [pbuh]{.hon}.
:::
```

- Either part may be missing (Arabic only, or translation only). When both are present, **Arabic comes first**, and the build stops if it doesn't.
- `hadith` is for hadith text. Type its reference at the end of the translation.
- `arabic-quote` is for other quoted Arabic: sayings, poetry.
- `trans` is a **drafting** pair: the source passage next to your translation. A final edition keeps only the English.

Inside a numbered or bulleted list, ayah and hadith blocks automatically use their list styles.

## Editorial marks

```markdown
[check the date]{.note}     shown as "NOTE: check the date"
[text]{.c1} … {.c4}         four highlight colours
[text]{.warn}               warning highlight
```

These are for drafts. **A final edition stops on any mark that's left.**

## Other formatting

| You write | You get |
|---|---|
| `[Term]{.smallcaps}` | small caps |
| `# Preface {.unnumbered}` | a heading without a number |
| `[@saadi02, 12]` | a footnote citation from `utils/master.bib` (a missing key stops the build) |
| `::: signature` … `:::` | a left-aligned author signature at the end of front matter |

### Your own styles

Any Pandoc Markdown works, including your own Word/ODT/ICML styles:

```markdown
::: {custom-style="Basmalah"}
بسم الله الرحمن الرحيم
:::
```

You're responsible for adding the style to `utils/templates/template.docx` (and `.odt`). If the template doesn't define it, the build warns once, because it would come out unstyled. A near-miss of one of the template's own style names (`quran-arabc`) is treated as a typo and stops the build.

### Your own classes

You can use your own classes, like `::: poem`. The build passes them through unchanged and mentions each one once as a warning, so a final edition will ask about them. If a class is one or two letters away from a construct name (`hadeeth`, `ayat`), the build treats it as a typo and stops.

## Options and editions

`metadata.yaml` holds the book's settings under `template:`. Any of them can be changed for one build with `name=value`.

| Option | Values | Default |
|---|---|---|
| `edition` | `draft`, `final` | `draft` |
| `honorifics` | `arabic`, `english` | `arabic` |
| `quran-citation` | `short` (Q21:107), `long` (al-Anbiyāʾ, Q21:107) | `short` |
| `ayah-numbers` | `always`, `ended` (only where an ayah ends), `never` | `always` |
| `translation-lang` | a language code such as `en`, `fr` or `ur` | the book's `lang` |
| `timestamp` | `false` (each build overwrites the last), `true` (date and time in file names) | `false` |

A **format section** changes options for one format only:

```yaml
template:
  honorifics: arabic
  epub:
    honorifics: english
```

Which value wins: the command line, then the format section, then the book-wide value, then the default.

A **final** edition does three extra things. It keeps only the English of `trans` pairs. It stops on leftover editorial marks. It treats every warning as an error.

## When the build stops

Each message names the file and line and usually suggests the fix. Exit codes, for scripts:

| Code | Meaning |
|---|---|
| 0 | built (there may be warnings) |
| 1 | problems in the content; nothing was written |
| 2 | problems in the setup (a missing file, an unknown option); nothing was built |
| 3 | a bug in the template; please report it with the command you ran (`TEMPLATE_DEBUG=1` prints details) |
