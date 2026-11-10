---
id: 13
title: Implement the build script
labels: [wayfinder:task]
status: closed
assignee: khawarizmus
blocked_by: []
---

## Question

Write `build.lua` exactly as decided in [Build command and layout](06-build-command-and-layout.md):
- the command and its housekeeping commands
- output naming, content order, date filling
- the `utils/` reorganisation
- the ODT reference doc

It also has to cover:
- the option precedence from [Edition options model](04-edition-options-model.md)
- reporting, config checks and exit codes from [Error policy](05-error-policy.md)

It applies the construct filter from [Implement the construct filter](11-implement-construct-filter.md) to each file and reports the filter's collected problems together with captured Pandoc warnings. The two tickets can proceed in parallel against a shared contract (the filter returns a list of problems with file, line, severity and message); final integration needs both.

Done when every format (docx, odt, epub, chunkedhtml, html5) builds from the sample content on macOS, and a Windows run is at least attempted.

Input from [Resolve-in-place workflow](07-resolve-in-place-workflow.md): add the `resolve [--refresh]` and `unresolve` commands. They make text-level, in-place edits to content files, never through Pandoc's writer.

## Resolution

Done: `build.lua` at the root.

**Commands, flags and exit codes**
- Commands: `build` (default), `clean`, `help`, `resolve [--refresh]`, `unresolve`.
- Arguments: formats, `all`, `key=value` overrides.
- Flags: `--strict`, plus developer flags `--book=DIR` and `--dist=DIR`, which `tests/run.lua` uses to build `tests/sample/`.
- Exit codes: 0, 1 (content), 2 (configuration or usage), 3 (internal error, one line; `TEMPLATE_DEBUG=1` prints the traceback).

**Checks before anything is built**
- Pandoc version (≥ 3.9.0.1), every configured path, and the options are all checked before content is read.
- Problems from every format are merged, de-duplicated and reported together. Nothing is written if there is any error.

**Building**
- Each file is read separately with its file name, then filtered. Heading ids are de-duplicated across files.
- citeproc runs from Lua. A missing key is an error located at its `@key` in the source.
- Pandoc's warnings are captured with `pandoc.log.silence`.
- Writers: docx and odt (both with reference docs and numbered sections), epub3 (CSS and fonts embedded), chunkedhtml (unzipped), html5 (one page per file, CRLF on Windows).
- Output names look like `dist/20261110-1736-concise-biography-of-the-prophet.docx`.
- Missing `date:` is filled with the build time, honouring `SOURCE_DATE_EPOCH`. A legacy `DATE` placeholder counts as missing.

**resolve and unresolve** (`utils/lua/resolve.lua`)
- Edits are text-only and keep list indentation and line endings.
- Plain `resolve` is idempotent. `--refresh` fixes mismatches. `unresolve` removes only Arabic that matches the data.

**Verified on macOS (Pandoc 3.13)**
- A clean copy with an empty environment builds all formats, from the repo root and from another directory.
- Every error path was exercised: bad option value or name, unknown format, `pdf`, final edition with leftover marks, `--strict`, leftover GPP syntax.

**Windows was not run** (no Windows machine in this session); see [Try the build on Windows](15-try-the-build-on-windows.md).

**Layout change:** `utils/template.docx` and `utils/template.odt` moved to `utils/templates/` (plain `mv`; stage the move yourself).
