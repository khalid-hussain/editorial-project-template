---
id: 15
title: Try the build on Windows
labels: [wayfinder:task]
status: open
assignee:
blocked_by: []
---

## Question

The build has only run on macOS. On a Windows machine with Pandoc ≥ 3.9.0.1 (`winget install JohnMacFarlane.Pandoc`), using PowerShell or cmd (no Git Bash, no WSL), in the repository folder:

1. `pandoc lua tests/run.lua`: expect `47 checks, 0 failed`.
2. `pandoc lua build.lua all`: expect 5 outputs in `dist\`.
3. Open the DOCX in Word. Check that the Arabic is right-to-left and the ayah, hadith and honorific styles are applied.
4. Copy a content file, save it with CRLF line endings and Unicode-normalised Arabic, and run `pandoc lua build.lua resolve` then `unresolve`. Expect no spurious changes.

Record any failure here. Path handling, CRLF output and `%Z`-free dates are the areas most likely to differ.
