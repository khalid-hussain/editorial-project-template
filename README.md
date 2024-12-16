
# Editorial Project Template

## Dependencies

This is an editorial template which can be used to manage Islamic book projects.
It relies on the following:

1. [Pandoc]
2. [GPP] - a binary for Windows systems is provided in `utils/gpp`. For other systems, follow instructions on the official website.

## Preprocessor macros

The template makes use of a lot of macros to simplify repetitive tasks.
We use [GPP] for this task.
There are macros for different tasks:

1. Honorifics;
2. *Āyah* reference helpers; and
3. Paragraph and character styles.

## Fonts

For Arabic content, we use the fonts provided by the King Fahad Glorious Quran Printing Complex (KFGQPC).
This combination is recommended so as to maintain the same line height for Arabic content.
Using other combinations is not an issue if line height can be maintained, e.g. using InDesign.
This is harder if not impossible to achieve in the EPUB format.

## Helpers for Honorifics

Use `\hon{SHORTCODE}{LOCATION}` where `SHORTCODE` is one of the shortcodes found
in `utils/gpp/honorifics.pp` and `LOCATION` is one of the following: `HEADER`,
`BODY`, or `FOOTER`. So to send salutations on the Prophet in the body text, use
`\hon{PBUH}{BODY}`.

## Helpers for *Āyah* reference

...

## Helpers for paragraph and character styles

For [small caps], use `\SC{term}`.
Internally, this expands to `[term]{.smallcaps}`.

## References

It uses Pandoc's citation processor.
The citation style is [Chicago fullnote (shortitle subsequent)];
It is preferred over styles which used “Ibid.” for subsequent mentions because it is inconvenient for digital formats such as EPUB3.
It also allows adding other content to the footnote along with the reference.

## Starting checklist

1. Clone the repo.

2. Type in book details in `./metadata.yaml`

3. Start creating Markdown files in `content/frontmatter` and `content/mainmatter`.
   a.  For files in `frontmatter`, consider using using the `unnumbered` attribute for headers so that they are not numbered; usually, numbering starts with the first chapter. E.g. `# Heading Title {.unnumbered}`

   b.  Most books can be split easily into chapters. For those that cannot,
   arbitrary division into separate Markdown files is recommended if the book is long.

4. To generate a draft, type `make` followed by the required format: `make EPUB` or `make DOCX`.

## Cons

For other than syntax errors, macro expansion from [GPP] usually, if not always, fails silently.

[Pandoc]: https://pandoc.org/
[GPP]: https://files.nothingisreal.com/software/gpp/gpp.html
[Chicago fullnote (shortitle subsequent)]: https://www.zotero.org/styles/chicago-fullnote-bibliography-short-title-subsequent
[small caps]: https://en.wikipedia.org/wiki/Small_caps
