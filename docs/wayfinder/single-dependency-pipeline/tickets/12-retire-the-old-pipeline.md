---
id: 12
title: Retire the old pipeline
labels: [wayfinder:task]
status: closed
assignee: khawarizmus
blocked_by: [10, 11, 13]
---

## Question

Once the new build produces every current output format from converted content, delete:
- `utils/gpp/` (including `gpp.exe`)
- `makefile` (no alias survives, per [Build command and layout](06-build-command-and-layout.md))
- `utils/python/`
- `utils/quran/quran-ayah-getter.ipynb`
- `utils/lua_filters/inject-date.lua`, if the build replaces it

Then update the README's Dependencies section to "Pandoc ≥ 3.9.0.1".

## Resolution

Deleted from the working tree with `rm` (stage the deletions yourself):
- `utils/gpp/` (including `gpp.exe`)
- `makefile`
- `utils/python/`
- `utils/quran/quran-ayah-getter.ipynb`
- `utils/lua_filters/inject-date.lua`

`.gitignore` drops `utils/gpp/tests/*.*`. `utils/lua/convert-gpp.lua` is kept (see [Convert existing content to the new constructs](10-convert-existing-content.md)). The README's dependencies are now just Pandoc ≥ 3.9.0.1.
