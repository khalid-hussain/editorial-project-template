# EDITORIAL-PROJECT-TEMPLATE

## Dependencies

This is an editorial template which can be used to manage Islamic book projects.
It relies on the following:

1. [Pandoc]
2. [GPP]

## Preprocessor macros

The template makes use of a lot of macros to simplify repetitive tasks.
We use [GPP] for this task.
There are macros for different tasks:

1. Honorifics;
2. *Āyah* reference helpers; and
3. Paragraph and character styles.

### Honorifics

...

### *Āyah* reference helpers

...

### Paragraph and character styles

...

## References

It uses Pandoc's citation processor.
The citation style is [Chicago fullnote (shortitle subsequent)];
It is preferred over styles which used “Ibid.” for subsequent mentions because it is inconvenient for digital formats such as EPUB3.
It also allows adding other content to the footnote along with the reference.

## Starting checklist

1. Clone the repo.
2. Type in book details in `./metadata.yaml`
3. Start creating Markdown files in `content/frontmatter` and `content/mainmatter`.
   a. For files in `frontmatter`, consider using using the `unnumbered` attribute for headers so that they are not numbered; usually, numbering starts with the first chapter.

## Cons

For other than syntax errors, macro expansion from [GPP] usually, if not always, fails silently.

[Pandoc]: https://pandoc.org/
[GPP]: https://files.nothingisreal.com/software/gpp/gpp.html
[Chicago fullnote (shortitle subsequent)]: https://www.zotero.org/styles/chicago-fullnote-bibliography-short-title-subsequent

