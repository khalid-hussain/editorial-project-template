---
title: Pandoc capability baseline
ticket: ../tickets/01-pandoc-capability-baseline.md
researched: 2026-11-09
pandoc-latest-at-time-of-research: 3.13 (2026-10-26)
---

# Pandoc capability baseline

Research for [ticket 01](../tickets/01-pandoc-capability-baseline.md). Pandoc was not installed, so nothing here was run against a real pandoc binary. Every claim comes from the pandoc manual, the Lua filter docs, the changelog, or the `jgm/pandoc` source on `main` as of 2026-11-09. The CSV timing was measured with a different Lua interpreter (LuaJIT), so treat it as a rough estimate (see Q4).

Primary sources used throughout:

- Manual: <https://pandoc.org/MANUAL.html> (source: [`MANUAL.txt`](https://github.com/jgm/pandoc/blob/main/MANUAL.txt))
- Lua API: <https://pandoc.org/lua-filters.html> (source: [`doc/lua-filters.md`](https://github.com/jgm/pandoc/blob/main/doc/lua-filters.md))
- Changelog: [`changelog.md`](https://github.com/jgm/pandoc/blob/main/changelog.md)
- `pandoc lua` man page: [`doc/pandoc-lua.md`](https://github.com/jgm/pandoc/blob/main/doc/pandoc-lua.md)

> **Version caveat.** The `*Since:*` tags in lua-filters.md for the newer `pandoc.system` functions say "3.7.1". That is the version of the `lua-module-system` package, not a pandoc release. The pandoc changelog lists `read_file`, `write_file`, `command`, `copy`, `rename`, `remove`, `times` and `xdg` under **pandoc 3.8 (2025-09-06)**. This document uses pandoc release numbers from the changelog.

---

## 1. `pandoc lua` as a build runner

**Short answer:** yes. One `pandoc lua build.lua` script can list content, read files, parse each one, run our filters and citeproc, write every output format, and write the result files. You have to build the writer options yourself, though. Some things the CLI does automatically are not done for you by `pandoc.write` (listed below).

| Need | API | Min pandoc | Source |
|---|---|---|---|
| Run a Lua script with the whole pandoc API, plus `lpeg`/`re`, using Lua 5.4 semantics | `pandoc lua script.lua args…` | 3.0 | [MANUAL "Running pandoc as a Lua interpreter"](https://pandoc.org/MANUAL.html#running-pandoc-as-a-lua-interpreter); changelog 3.0 (#8311) |
| List a directory | `pandoc.system.list_directory(dir)` (returns a `List` since 3.8) | 2.19 | [lua-filters#pandoc.system.list_directory](https://pandoc.org/lua-filters.html#pandoc.system.list_directory) |
| Create directories (with parents) | `pandoc.system.make_directory(dir, true)` | 2.19 | [lua-filters#pandoc.system.make_directory](https://pandoc.org/lua-filters.html#pandoc.system.make_directory) |
| Read and write files (UTF-8-safe paths) | `pandoc.system.read_file`, `pandoc.system.write_file` | **3.8** | [lua-filters#pandoc.system.read_file](https://pandoc.org/lua-filters.html#pandoc.system.read_file); changelog 3.8 |
| Check that a path exists | `pandoc.path.exists` | 3.8 | [lua-filters#pandoc.path.exists](https://pandoc.org/lua-filters.html#pandoc.path.exists) |
| Path joining and splitting | `pandoc.path.join/split_extension/…` | 2.12 | [lua-filters#module-pandoc.path](https://pandoc.org/lua-filters.html#module-pandoc.path) |
| Parse text into an AST | `pandoc.read(markup, format, reader_options, read_env)` | 2.17 (Sources input 2.18, sandbox 3.7) | [lua-filters#pandoc.read](https://pandoc.org/lua-filters.html#pandoc.read) |
| Attach a file name to the parsed text (for `data-pos`, see Q2) | `pandoc.read({{name = path, text = content}}, …)` | **3.9.0.1** | [`Marshal/Sources.hs`](https://github.com/jgm/pandoc/blob/main/pandoc-lua-engine/src/Text/Pandoc/Lua/Marshal/Sources.hs); changelog 3.9.0.1 (#11441). At tag 3.9 a table input had to hold `Source` userdata; the `{name, text}` form first appears in 3.9.0.1 |
| Apply our filters in-process | `doc:walk(filter_table)`, or `pandoc.utils.run_lua_filter(doc, path, env)` | walk 2.17; run_lua_filter 3.2.1 | [lua-filters#pandoc.utils.run_lua_filter](https://pandoc.org/lua-filters.html#pandoc.utils.run_lua_filter) |
| Citations (what `--citeproc` does) | `pandoc.utils.citeproc(doc)`, which reads `bibliography`, `csl` etc. from `doc.meta` | 2.19.1 | [lua-filters#pandoc.utils.citeproc](https://pandoc.org/lua-filters.html#pandoc.utils.citeproc) |
| Write any format, including binary ones | `pandoc.write(doc, format, writer_options)` returns a Lua string, which holds raw bytes for docx/odt/epub/chunkedhtml | 2.17 | [lua-filters#pandoc.write](https://pandoc.org/lua-filters.html#pandoc.write); [`Module/Pandoc.hs`](https://github.com/jgm/pandoc/blob/main/pandoc-lua-engine/src/Text/Pandoc/Lua/Module/Pandoc.hs) handles both `TextWriter` and `ByteStringWriter` |
| Writer options | `reference_doc`, `epub_fonts`, `epub_metadata`, `epub_title_page`, `number_sections`, `split_level`, `chunk_template`, `template`, `variables`, `toc_depth`, … | 2.17 (field set has grown since) | [lua-filters#type-writeroptions](https://pandoc.org/lua-filters.html#type-writeroptions); full field list in [`Marshal/WriterOptions.hs`](https://github.com/jgm/pandoc/blob/main/pandoc-lua-engine/src/Text/Pandoc/Lua/Marshal/WriterOptions.hs) |
| Unpack the zip that `chunkedhtml` produces | `pandoc.zip.Archive(bytes):extract{ destination = dir }` | 3.0 | [lua-filters#pandoc.zip.Archive.extract](https://pandoc.org/lua-filters.html#pandoc.zip.Archive.extract) |
| Default templates | `pandoc.template.compile(pandoc.template.default("epub3"))` | 2.17 / 3.0 | [lua-filters#module-pandoc.template](https://pandoc.org/lua-filters.html#module-pandoc.template) |
| Set the resource path or data dir | `pandoc.with_state({resource_path = …, user_data_dir = …}, fn)` | 2.x | [lua-filters#pandoc.with_state](https://pandoc.org/lua-filters.html#pandoc.with_state) |
| Turn CLI-style args into an options table | `pandoc.cli.parse_options(arg)` | 3.0 | [lua-filters#pandoc.cli.parse_options](https://pandoc.org/lua-filters.html#pandoc.cli.parse_options) |
| Run a subprocess (escape hatch, including `pandoc` itself) | `pandoc.system.command(cmd, args, stdin)` | 3.8 | [lua-filters#pandoc.system.command](https://pandoc.org/lua-filters.html#pandoc.system.command) |

**Replacing `--file-scope`.** Read each file with its own `pandoc.read` call, then concatenate the results. Footnote labels then belong to their own file, which is what `--file-scope` gives you. Metadata does not merge on its own. In Haskell, `Pandoc <> Pandoc` uses `Meta (M.union m2 m1)`, so later files win ([`pandoc-types` Definition.hs](https://github.com/jgm/pandoc-types/blob/master/src/Text/Pandoc/Definition.hs)). The script has to do this merge itself.

```lua
local combined = pandoc.Pandoc({}, {})
for _, source_path in ipairs(content_paths) do
  local source_text = pandoc.system.read_file(source_path)
  local parsed = pandoc.read({ { name = source_path, text = source_text } }, reader_format)
  combined.blocks:extend(parsed.blocks)
  for meta_key, meta_value in pairs(parsed.meta) do combined.meta[meta_key] = meta_value end
end
```

**What only the CLI (or a defaults file) does for you.** These come from [`App/OutputSettings.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/App/OutputSettings.hs), [`App/Input.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/App/Input.hs) and [`App.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/App.hs). In each case the script has to do the same thing itself:

1. **Default template for binary and standalone output.** The CLI forces `standalone` for odt/docx/epub/chunkedhtml (`isBinaryFormat`) and compiles the default template. `pandoc.write` uses `template = nil` unless you pass one. We must pass `template = pandoc.template.compile(pandoc.template.default(format))` for epub3, chunkedhtml and html5 (`-s`). Inference from the source, not run: an EPUB written without a template will have chapter files that are bare fragments.
2. **`--css`.** The CLI turns `--css` into the template variable `css`. The EPUB writer reads stylesheets from meta `css`/`stylesheet` or from the `css` variable ([`Writers/EPUB.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Writers/EPUB.hs)). Set `variables = { css = {…} }` or `doc.meta.css`.
3. **`--bibliography`, `--csl`, `-M`, `--metadata-file`.** The CLI copies these into `doc.meta`. Set the meta fields ourselves before calling `pandoc.utils.citeproc`.
4. **`--epub-metadata FILE` and `--epub-cover-image`.** The CLI reads the metadata file into a string, and turns the cover image into the variable `epub-cover-image`. Pass `epub_metadata = read_file(...)` and set the variable ourselves.
5. **Identifier prefixing under `--file-scope`.** With several files, the CLI runs `adjustLinksAndIds`, which turns `foo` into `subdir__file1.txt__foo` ([MANUAL `--file-scope`](https://pandoc.org/MANUAL.html#option--file-scope)). Lua cannot call this function. If we want the same behaviour we write it ourselves, and `pandoc.structure.unique_identifier` (3.8) can help.
6. **`--eol`.** The CLI default is `native`, so Windows gets CRLF ([MANUAL `--eol`](https://pandoc.org/MANUAL.html#option--eol)). It is applied in `App.hs` `writerFn` when the output file is written. `pandoc.write` returns LF text, so add CRLF ourselves if we want it.
7. **`--fail-if-warnings` and `--verbosity`.** Lua cannot set these (`PANDOC_STATE` is read-only). Use `pandoc.log.silence` to capture messages and decide what to do with them (Q3).
8. **`-o dir` for `chunkedhtml`.** The CLI unpacks the zip into the directory. Use `pandoc.zip`.
9. **Automatic variables.** The CLI sets `sourcefile`, `outputfile`, `pandoc-version` and `curdir`. They only matter if a template uses them.

Every CLI option can still be reached without leaving pandoc: `pandoc.system.command("pandoc", {...})` runs the CLI as a subprocess (3.8+). This is an escape hatch, not the main path.

---

## 2. Source positions

**Short answer:**

- **`markdown` (pandoc Markdown): no.** Lua filters get no line or file information. The `sourcepos` extension works only for `commonmark`, `gfm`, `commonmark_x` and `djot`. The [MANUAL `sourcepos`](https://pandoc.org/MANUAL.html#extension-sourcepos) entry says "commonmark or djot", and changelog 2.11.3 says "No other readers are affected". Djot support was noted in the manual in 3.11. The markdown reader does track the source file internally (changelog 3.12, #11888, about `rebase_relative_paths`), but it never puts that in the AST.
- **`commonmark_x+sourcepos`: yes.** Each element gets a `data-pos` attribute. Elements that cannot take attributes (`Str`, `Space`, …) are wrapped in a `Span`/`Div` with `wrapper="1"` ([`commonmark-pandoc` Pandoc.hs](https://github.com/jgm/commonmark-hs/blob/master/commonmark-pandoc/src/Commonmark/Pandoc.hs)). The value looks like `[name@]startLine:startCol-endLine:endCol`. The file name is included when the source has one ([`commonmark` Types.hs `prettyRange`](https://github.com/jgm/commonmark-hs/blob/master/commonmark/src/Commonmark/Types.hs)). The CommonMark reader takes the name from the `Sources` it is given ([`Readers/CommonMark.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Readers/CommonMark.hs)). From Lua, a named source needs **3.9.0.1** (see Q1). On older versions we still know the file, because we read files one at a time, so only the line numbers come from `data-pos`.
  - Available since **2.11.3** (#4565). A bug where YAML metadata shifted line numbers ([#7863](https://github.com/jgm/pandoc/issues/7863)) was fixed in January 2022, so it ships in 2.17.1 and later.
  - Cost: wrapper spans around every word make the AST much larger. They also break filters that match neighbouring `Str` nodes. The build has to strip `wrapper` spans and `data-pos` before writing (inference). There have been bugs specific to sourcepos, e.g. code-block attributes were dropped ([#8895](https://github.com/jgm/pandoc/issues/8895), closed).

**Does `commonmark_x` support what we use?** Its default and supported extensions come from [`Extensions.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Extensions.hs) (`getDefaultExtensions "commonmark_x"`, `getAll "commonmark"`).

| Feature | `commonmark_x` | Note |
|---|---|---|
| Footnotes | yes (default) | |
| Fenced divs `:::` | yes (default) | |
| Bracketed spans `[x]{…}` | yes (default) | |
| Attributes `{#id .class key=val}` | yes (`attributes`, default) | |
| YAML metadata | yes (default) | Only at the very start of the input, and only one block ([MANUAL `yaml_metadata_block`](https://pandoc.org/MANUAL.html#extension-yaml_metadata_block)). Fine if each file is read separately. |
| **Citations `[@key]`** | **no** | `Ext_citations` is not among the extensions supported for commonmark. Upstream issue [jgm/commonmark-hs#15 "Implement citations extension"](https://github.com/jgm/commonmark-hs/issues/15) is still **open**. |
| **Small caps `[x]{.smallcaps}`** | **partly** | The markdown reader turns a `.smallcaps` span into a `SmallCaps` node ([`Readers/Markdown.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Readers/Markdown.hs)). commonmark leaves it as a plain `Span`. The DOCX writer applies `w:smallCaps` only to `SmallCaps` nodes ([`Docx/OpenXML.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Writers/Docx/OpenXML.hs)). A three-line filter fixes this. |

**What this means:** we cannot have both line numbers and `[@key]` citations from pandoc's own readers. The current content has no citations yet, but the build relies on citeproc and Chicago full-note CSL, so citations are clearly planned. The options:

- **(a)** Use `markdown`. Errors then carry the file plus the text that caused them, with no line number. We could search the source text for that snippet to estimate a line (inference).
- **(b)** Use `commonmark_x+sourcepos`, and turn literal `[@key; …]` text into `Cite` nodes with our own filter. That is a custom reimplementation of citation syntax.
- **(c)** Parse each file twice: `markdown` builds the AST, and `commonmark_x+sourcepos` is only used to look up positions when reporting an error.

This choice belongs in tickets 03 and 05.

---

## 3. Error behaviour and warnings

**Short answer:** an `error()` call aborts the run with a non-zero exit code and prints the message to stderr. The exit code depends on how the Lua code is running:

| Context | What happens | Exit code | Source |
|---|---|---|---|
| `error()` in a filter run with `pandoc --lua-filter f.lua` | Wrapped in `PandocFilterError`; stderr shows `Error running filter f.lua:` followed by the message and a Lua traceback | **83** | [`Lua/Engine.hs` `forceResult`](https://github.com/jgm/pandoc/blob/main/pandoc-lua-engine/src/Text/Pandoc/Lua/Engine.hs); [`Error.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Error.hs); [MANUAL Exit codes](https://pandoc.org/MANUAL.html#exit-codes) |
| Uncaught `error()` in a `pandoc lua build.lua` script (including errors from filters it applies with `doc:walk`) | `PandocLuaError`; stderr shows `Error running Lua:` followed by the message and traceback (the script runs under `pcallTrace`) | **84** | [`pandoc-cli/lua/PandocCLI/Lua.hs`](https://github.com/jgm/pandoc/blob/main/pandoc-cli/lua/PandocCLI/Lua.hs) (`handleError`); [`hslua-cli` CLI.hs](https://github.com/hslua/hslua/blob/main/hslua-cli/src/HsLua/CLI.hs) |
| Script writes to `io.stderr` itself, then calls `os.exit(n)` | We pick the message format and the exit code | any | Lua 5.4 standard library, opened via `Lua.openlibs` in [`Lua/Init.hs`](https://github.com/jgm/pandoc/blob/main/pandoc-lua-engine/src/Text/Pandoc/Lua/Init.hs) |

For clean errors aimed at authors, the build script should collect problems itself and finish with `io.stderr:write(...)` and `os.exit(1)`. Otherwise authors see a Lua traceback.

**Warnings:** `pandoc.log.warn(msg)` and `pandoc.log.info(msg)` exist since **3.2** ([lua-filters#module-pandoc.log](https://pandoc.org/lua-filters.html#module-pandoc.log)). A warning prints `[WARNING] Scripting warning at <lua-file>:<line>: msg` to stderr unless verbosity is ERROR ([`Logging.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Logging.hs); `report` in [`PandocMonad.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Class/PandocMonad.hs)). Two things to know:

- The position in the message is the **Lua call site**, not a document position. Put the source file and line in the message text ourselves.
- `pandoc.log.silence(fn)` (3.2) runs `fn` and returns the warnings it produced instead of printing them. With that, the script can enforce a "warnings are errors" policy without `--fail-if-warnings` (CLI only, exit 3). `PANDOC_STATE.log` also holds every message logged so far (3.8 made it a table in time order).

---

## 4. Data: JSON and CSV

- **JSON:** `pandoc.json.decode(str[, pandoc_types])` and `pandoc.json.encode(obj)` exist since **3.1.1** ([lua-filters#module-pandoc.json](https://pandoc.org/lua-filters.html#module-pandoc.json)). Decoded arrays behave like pandoc Lists since 3.2.1. Pass `pandoc_types = false` so plain data is never decoded as AST nodes.
- **CSV:** there is no Lua CSV module. Pandoc has a `csv` *reader* (since **2.9.2**, changelog), so `pandoc.read(text, "csv")` returns a `Table` AST. For a lookup table this is clumsy: every cell comes back as Inlines and has to be passed through `stringify`.
- **Is parsing `utils/quran/hafsData_v18.csv` in pure Lua feasible?** Yes. Checks on the file: 2,441,337 bytes, 6,237 lines (a header plus 6,236 ayat), 11 columns on every row, no BOM, no CR characters, no escaped `""` quotes, and no newlines inside fields (Python's `csv` module returns 6,237 rows with 11 fields each). That means a simple split on quotes and commas is correct for this file. A 20-line parser that builds a `"sura:ayah" → text` table ran in **15–30 ms** (LuaJIT with `-joff`, which is the plain interpreter, on this Mac). Pandoc embeds PUC Lua 5.4, which should be in the same range, perhaps twice as slow. That is still well under a tenth of a second per build. *This was not measured inside pandoc.* Let the parser accept `\r\n` anyway, in case a Windows checkout converts line endings (Q6).
- Another option: convert the CSV to JSON once, and load it with `pandoc.json.decode`. That parser is Haskell's aeson, so it is likely as fast or faster. Whether to do this is a question for ticket 08.

---

## 5. Date/time and environment

**Short answer:** the full Lua 5.4 standard library is available (`Lua.openlibs`, [`Lua/Init.hs`](https://github.com/jgm/pandoc/blob/main/pandoc-lua-engine/src/Text/Pandoc/Lua/Init.hs); [MANUAL](https://pandoc.org/MANUAL.html#running-pandoc-as-a-lua-interpreter)). So:

- `\NOW` / `date '+%a %d %b %Y %I:%M%p'` becomes `os.date("%a %d %b %Y %I:%M%p")`. The `$(TODAY)` file stamp becomes `os.date("%Y%m%d-%H%M")`. The existing `utils/lua_filters/inject-date.lua` already uses `os.date`/`os.time`.
- Environment variables: `os.getenv(name)`, or `pandoc.system.environment()` for the whole table (2.7.3). Use `pandoc.system.with_environment` (2.7.3) to run code with a modified environment.
- File timestamps: `pandoc.system.times(path)` (3.8) returns ISO 8601 times.
- Platform: `pandoc.system.os` (`darwin`/`linux`/`mingw32`) and `pandoc.system.arch`.
- **Reproducible builds:** pandoc's own timestamps (EPUB modified date, docx properties) come from `SOURCE_DATE_EPOCH` when it is set ([MANUAL "Reproducible builds"](https://pandoc.org/MANUAL.html#reproducible-builds)). Our `os.date` calls do not read it. If we want reproducible output, read `os.getenv("SOURCE_DATE_EPOCH")` and pass it to `os.date(fmt, epoch)`.

---

## 6. Cross-platform gotchas

1. **Non-ASCII paths on Windows.** Lua's `io.open`/`os.remove` take bytes, which Windows reads in the ANSI code page. A path with Arabic characters would fail. Pandoc 3.8 added `pandoc.system.read_file/write_file/copy/rename/remove/command` because "functions that expect UTF-8-encoded filenames should make it easier to write platform-independent scripts" (changelog 3.8). **Rule: never use `io.open`, `os.remove` or `os.rename` on content paths. Use `pandoc.system.*`.** `pandoc.text.toencoding`/`fromencoding` (3.0, default `CP0` on Windows) exist for any string that has to cross that boundary.
2. **Line endings in.** Every `Sources` input has `\r` stripped before parsing ([`Sources.hs`](https://github.com/jgm/pandoc/blob/main/src/Text/Pandoc/Sources.hs)), so a CRLF checkout parses exactly like LF. Our own Lua parsers (CSV, config) do not get this, so strip `\r` there too.
3. **Line endings out.** `pandoc.write` returns LF. The CLI would write CRLF on Windows (`--eol=native`). For text formats this is cosmetic. Binary formats are unaffected.
4. **Path separators.** Use `pandoc.path.join` and `pandoc.path.separator`. `pandoc.path.split_search_path` treats blank items differently per OS ([lua-filters#pandoc.path.split_search_path](https://pandoc.org/lua-filters.html#pandoc.path.split_search_path)).
5. **Lua patterns depend on the locale.** `%a`, `%p` and similar classes match differently under CP-1252 than under a UTF-8 locale. The docs recommend `os.setlocale 'C'` at the top of the script ([lua-filters "Pattern behavior is locale dependent"](https://pandoc.org/lua-filters.html#common-pitfalls)). For Arabic text, use `pandoc.text` (`len`, `sub`, `upper`, …) or `lpeg`/`re` rather than byte-oriented `string.*` functions.
6. **`os.date("%Z")`** gives a long, localised time-zone name on Windows, possibly in the ANSI code page. `inject-date.lua` uses it, so it could emit non-UTF-8 bytes there (inference from how the Windows C runtime behaves; not checked against a pandoc source). Prefer a numeric offset.
7. **Unpacking chunkedhtml on Windows.** `pandoc.zip` `extract` only sets modification times correctly on POSIX (lua-filters). Harmless here.
8. **`pandoc lua` with no script on Windows** always acts as if attached to a terminal ([pandoc-lua.md](https://github.com/jgm/pandoc/blob/main/doc/pandoc-lua.md)). `pandoc.cli.repl` exits immediately on Windows (lua-filters). Always pass a script path.
9. **Unicode normalisation of macOS file names** (inference): HFS+ stores names in NFD, and Arabic letters with hamza, such as أ (U+0623), have canonical decompositions. If content is looked up by file name, keep file names ASCII. The current names already are.

---

## Recommended minimum pandoc version

**Pin to pandoc ≥ 3.9.0.1.** In CI and the README, pin an exact recent release; 3.13 was the latest on 2026-11-09.

Why each recent version matters:

| Version | What we need from it |
|---|---|
| 3.0 | `pandoc lua`, `pandoc.zip`, `pandoc.cli` |
| 3.1.1 | `pandoc.json` |
| 3.2 | `pandoc.log.warn/info/silence` |
| 3.2.1 | `pandoc.utils.run_lua_filter` |
| **3.8** | UTF-8-safe `pandoc.system.read_file/write_file/command/copy/remove/rename/times`, `pandoc.path.exists`, `pandoc.structure.unique_identifier`. **This is the hard floor for Windows.** |
| **3.9.0.1** | `pandoc.read({{name=…, text=…}})`, so `data-pos` includes the file name. Only needed if we choose `commonmark_x+sourcepos`. If we stay on `markdown`, 3.8 is enough. |

Guard at the top of the build script, to fail fast:

```lua
PANDOC_VERSION:must_be_at_least("3.9.0.1", "This template needs pandoc 3.9.0.1 or newer.")
```

([lua-filters#Version.must_be_at_least](https://pandoc.org/lua-filters.html#Version.must_be_at_least))

## Anything that forces us outside pure pandoc?

**Nothing found that is required.** Everything the current makefile does (GPP macros, `date`, `mktemp`/FIFOs, the file loop, `--file-scope`, citeproc, reference-doc, EPUB fonts/CSS, chunkedhtml) has a pandoc-only equivalent above. Things to watch:

- **Citations together with line-numbered errors** cannot both come from pandoc's own readers (Q2). This is not an external dependency, but it is a real trade-off: either custom citation parsing, a double parse, or no line numbers.
- **Writing the reference DOCX/ODT templates** still needs Word or LibreOffice. That is an authoring tool for template maintainers, not a build dependency.
- **PDF output later** (`typst`, LaTeX) would need an external engine. Out of scope here, and the Lua pipeline does not block it.
- `pandoc.system.command` makes it easy to call other programs. To keep the single-dependency guarantee, use it only to call `pandoc` itself.
