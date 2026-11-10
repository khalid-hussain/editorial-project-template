---
id: 14
title: Rewrite README and authoring guide
labels: [wayfinder:task]
status: closed
assignee: khawarizmus
blocked_by: [11, 13]
---

## Question

Rewrite the README for the new pipeline. Setup is "install Pandoc ≥ 3.9.0.1, run `pandoc lua build.lua`". Then add an authoring guide in `docs/` covering:
- every construct, with examples
- the ayah-reference grammar
- edition options and per-format sections
- what errors look like and how to fix them

The audience is non-developer translators and editors first, and developers second. Keep the editorial guidelines and the roadmap that are already in the README.

## Resolution

Done.

**`README.md`** now covers:
- setup for each OS
- the one command, and what errors look like
- starting a book, a writing cheat sheet, options
- moving an older GPP book over
- notes for developers

It keeps the existing Fonts, References, Guidelines and Roadmap sections and the TODOs about Word template design. A new TODO lists the styles the build emits that `template.docx` and `template.odt` don't define yet.

**`docs/authoring-guide.md`** is written for translators first. It covers every construct and the honorific key table, the ayah reference grammar and its rules, `resolve`/`unresolve`, options and format sections, editions, and exit codes. It is linked from `docs/README.md`.
