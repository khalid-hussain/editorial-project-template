---
id: 02
title: Ayah reference grammar
labels: [wayfinder:prototype]
status: closed
assignee: khawarizmus
blocked_by: []
---

## Question

What is the exact grammar of an ayah reference, and how does each form resolve to Arabic text? It must cover: a single ayah (`21:107`), a range (`2:1-3`), several references in one block, and word slices from the start or end of an ayah or range (e.g. `21:107|suffix-5`), with slices that compose (prefix and suffix together, slices on a range). Also decide: what happens to the ayah-number marker (e.g. ١٠٧) when slicing, how an ellipsis is shown for partial quotes, how the English citation like `(Q21:107)` / long form with surah name is derived, and which inputs are errors (ayah out of range, slice longer than the ayah). Prototype the grammar with worked examples against the real CSV.

Prototype: [PROTOTYPE-ayah-reference-grammar.html](../prototypes/PROTOTYPE-ayah-reference-grammar.html), a single self-contained page with the full Ḥafṣ text embedded.

## Resolution

Validated with the prototype against the full Ḥafṣ data.

**Grammar**
```
reference = part ( ";" part )*          2:1-3; 2:5
part      = location ( "|" slice )*     21:107|suffix-5
location  = surah | surah ":" ayah | surah ":" ayah "-" ayah    (a range stays inside one surah)
slice     = "prefix-" N | "suffix-" N   first / last N words of what is selected so far
```
- Slices compose left to right: `2:255|prefix-10|suffix-4` gives words 7–10. A slice on a range counts words across all its ayat.
- Only words count. The ayah number and the ۞ hizb mark never count. Waqf signs stay attached to their word and are always kept, including on the word at a cut.

**Rendering**
- **Ayah numbers:** by default the number follows every quoted ayah, even a cut one. A preference can switch to "only where the ayah ends" or "never" (it belongs in [Edition options model](04-edition-options-model.md)).
- **Ellipsis:** `…` marks every cut. A cut ayah reads *words … number*: the ellipsis comes **before** the number, joined by a non-breaking space so a line can't break between them.
- **Hizb mark:** ۞ is dropped.
- **Joining parts:** non-adjacent parts are joined with ` … `. Adjacent ones (including the last ayah of one surah and the first of the next) are joined with a space. No extra gap mark is added where a cut ellipsis is already there.

**Citation**
- Same as for the whole ayah; partial quotes are not marked.
- Ranges in the same surah merge: `2:1-3; 2:4` → `(Q2:1–4)`, `2:1-3; 2:5` → `(Q2:1–3, 5)`.
- Different surahs are separated with `;`. The long form prefixes the surah name, e.g. `(al-Fātiḥah, Q1:7; al-Baqarah, Q2:1–2)`.

**Errors (build stops):**
- surah outside 1–114
- ayah beyond the surah's length
- backwards range
- range crossing surahs (message suggests `;`)
- slice of 0 words, or more words than are selected
- unknown slice name, with a suggestion (`sufix` → `suffix`)
- empty part (stray `;`)

**Data facts:** each CSV `aya_text` is an optional `۞` + NBSP, then words separated by U+0020, then NBSP and the Arabic-Indic ayah number. This holds for all 6,236 ayat; 199 start with ۞.

The pure logic module in the prototype (`AyahGrammar`) is the reference for the Lua port.
