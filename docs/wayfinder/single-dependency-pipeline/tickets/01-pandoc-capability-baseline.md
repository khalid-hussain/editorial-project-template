---
id: 01
title: Pandoc capability baseline
labels: [wayfinder:research]
status: closed
assignee: research-agent
blocked_by: []
---

## Question

What can Pandoc alone (with its built-in Lua) do for us, and what minimum Pandoc version do we pin? Specifically:

1. `pandoc lua` as a build runner: listing directories (`pandoc.system`), reading/writing files, invoking reader → filters → citeproc → writer from Lua (`pandoc.read`, `pandoc.utils.citeproc`, `pandoc.write` with `reference-doc`, EPUB fonts/CSS, `--file-scope`-equivalent per-file reading). Which options are only reachable via the CLI or a defaults file?
2. Source positions: can a Lua filter know the file and line of an element? Compare `markdown` vs `commonmark_x` (`+sourcepos`), and whether `commonmark_x` supports everything we use (citations, footnotes, fenced divs, bracketed spans, attributes, smallcaps, YAML metadata).
3. Error behaviour: what does `error()` inside a filter produce (exit code, message), and can we emit warnings (`pandoc.log`)?
4. Data: built-in JSON (`pandoc.json`) and any CSV help; is parsing `utils/quran/hafsData_v18.csv` in pure Lua feasible and fast enough per build?
5. Date/time and environment access from Lua (replacing `\NOW` and `date`).
6. Cross-platform gotchas (Windows paths, UTF-8 file names, line endings).

Findings: [research/01-pandoc-capability-baseline.md](../research/01-pandoc-capability-baseline.md)

## Resolution

Pandoc alone can do everything: nothing forces another dependency. **Pin pandoc ≥ 3.9.0.1** (3.8 is the hard floor for Unicode-safe Windows paths; 3.9.0.1 lets `pandoc.read` carry the file name into source positions). `pandoc lua` can be the whole build runner. It reads each file separately (replacing `--file-scope`) and runs citeproc and every writer, but the script must re-do what the CLI did for us: default templates, CSS/bibliography/CSL as variables/metadata, de-duplicating heading IDs across files, CRLF on Windows, unzipping chunkedhtml, and treating warnings as errors.

Key trade-off surfaced: **line numbers (`sourcepos`) need the `commonmark_x` reader, which has no `[@key]` citations** (upstream jgm/commonmark-hs#15 open); the `markdown` reader has citations but no positions. Filters report errors via our own message + `os.exit` (raw `error()` gives exit 84 with a Lua traceback); `pandoc.log.warn` points at the Lua line, not the document. `pandoc.json` exists (3.1.1+); a pure-Lua CSV parse of the Qur'an data is cheap. Dates come from `os.date`/`os.getenv`; reproducible builds must pass `SOURCE_DATE_EPOCH` themselves. Details: [findings](../research/01-pandoc-capability-baseline.md).
