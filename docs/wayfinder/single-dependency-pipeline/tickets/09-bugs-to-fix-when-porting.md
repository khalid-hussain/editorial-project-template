---
id: 09
title: Bugs to fix when porting
labels: [wayfinder:task]
status: closed
assignee: khawarizmus
blocked_by: [03]
---

## Question

The old pipeline is not patched; its makefile bugs die with it (they are listed as requirements in [Build command and layout](06-build-command-and-layout.md)). This ticket tracks bugs in **data and content that carry into the new pipeline**, fixed as they are ported:

1. Honorifics (English): `S_TWO` is defined twice. The second definition should be `S_THM` ("Peace be on them").
2. Honorifics (English): the `SS_*` entries are still Arabic text and need English renderings.
3. Honorifics (both languages): `SS_HER` uses the masculine form (عليه); it should be feminine (عليها الصلاة والسلام).
4. `\trans` is defined twice in `misc.pp`, and only one variant sets `lang="ar"`. Port the one with `lang="ar"`.
5. `AR_START`/`EN_START` styles diverge: `paraCharStyles.pp` uses `arabic-text`/`arabic-text-trans`, while the stale `_macros.pp` uses `hadith-arabic`/`hadith-trans`. Check `template.docx` for the right ones.
6. `content/frontmatter/03-preface.md`: stray "it1" in the ayah translation.
7. `content/mainmatter/01-lineage.md`: the Muḍar/Nizār and Maʿadd/ʿAdnān paragraphs reuse the Kilāb translation. Flag them to the translator; don't invent text.

Bugs found later that would carry over get appended here, or fixed in the ticket that finds them.

## Resolution

1. **`S_THM`:** the English table now has `s-thm` = "(Peace be on them)".
2. **English `SS_*`:** given English renderings: "(Prayers and peace be on him / her / them both / them)". **Owner to confirm the wording.**
3. **`SS_HER`:** now feminine in Arabic (عليها الصلاة والسلام) and in English.
4. **`\trans`:** ported as `::: trans` with `lang="ar"` on the Arabic block.
5. **`AR_`/`EN_` styles:** `arabic-text` / `arabic-text-trans` were kept. They are the names in the latest commit ("Fixed custom style name for regular Arabic text").
6. **Preface:** "it1" → "it".
7. **Lineage:** the Muḍar/Nizār and Maʿadd/ʿAdnān paragraphs are flagged with a `.note` saying the translation is missing. Drafts show it, and a final edition fails until the translator replaces them.

**Found while porting:**
- **`pbuhs`** existed only in the English table ("(Peace be on him)"). It is kept, and its Arabic is set to the `pbuh` text. **Owner to confirm.**
- **`template.docx` lacks most of the styles the build emits.** It defines `honorifics_body`, not `Char … Honorifics`, and it has no `arabic-text*`, `Arabic Source`/`English Target`, `Highlight *` or `list-*` styles. `template.odt` defines almost none. Word creates them unstyled. This was already true with GPP. Styling the template is out of scope, so it is listed in the README TODO.
- **EPUB citations:** the old makefile passed no `--bibliography` to EPUB/HTML, so citations there never resolved. Every format now gets the bibliography.
