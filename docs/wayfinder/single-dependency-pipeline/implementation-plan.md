# Implementation plan

How the remaining tickets of [Single-dependency build pipeline](map.md) get built. Each decision lives in its ticket; this plan only orders the work and names the pieces.

## Order

```
Phase 0  Setup ─────────────┐
Phase 1  Construct filter ──┼──► Phase 3  Convert content (+ porting bugs) ──► Phase 4  Retire old pipeline
Phase 2  Build script ──────┘                                              └─► Phase 4  README + authoring guide
```

- Phases 1 and 2 can run in parallel; they share one contract (below).
- Phase 3 needs the filter, so converted files can be checked by it.
- Each phase ends at a **checkpoint**: a working state the human can review and commit. Agents never commit.

## The contract between filter and build

The filter never prints and never exits. It records each problem as:

```lua
{ file = "content/frontmatter/03-preface.md", line = 12,   -- line may be nil
  severity = "error" | "warning", message = "unknown class \"hadeeth\"",
  hint = "did you mean \"hadith\"?", snippet = "::: hadeeth" }
```

The build owns reporting, exit codes and the "nothing was written" rule ([Error policy](tickets/05-error-policy.md)).

---

## Phase 0: Setup

1. Install Pandoc ≥ 3.9.0.1:
   - macOS: `brew install pandoc`
   - Windows: `winget install JohnMacFarlane.Pandoc`
   - Linux: the `.deb` or tarball from the [Pandoc releases page](https://github.com/jgm/pandoc/releases) (distro packages lag behind)
2. Check `pandoc --version` and `pandoc lua -e "print(PANDOC_VERSION)"`.

**Checkpoint:** version confirmed. ✅ Done 2026-11-10 on macOS with Homebrew Pandoc 3.13 (Lua 5.4):
- `pandoc.system`, `utils.citeproc`, `log.silence`, `json`, `zip` and `template` are all present.
- A file name is passed to the reader as a list of pairs: `pandoc.read({{"path.md", text}}, "markdown")`. There is no `pandoc.Sources` constructor.
- `markdown` produces `Cite` nodes with no positions. `commonmark_x+sourcepos` produces `data-pos="path.md@line:col-…"`.

## Phase 1: [Implement the construct filter](tickets/11-implement-construct-filter.md)

Small Lua modules under `utils/lua/`, each runnable and checkable on its own:

| Module | Job |
|---|---|
| `csv.lua` | RFC 4180 parser: quoted fields, embedded commas, CRLF |
| `quran.lua` | Loads `hafsData_v18.csv` and `surah-names.csv`; splits an ayah into ۞ / words / number |
| `ayah_grammar.lua` | Port of the prototype's `AyahGrammar`: parse, resolve, slices, gap marks, citations, errors |
| `options.lua` | Reads the `template:` block, per-format sections and command-line overrides; precedence and validation with suggestions |
| `problems.lua` | Problem collector; finds line numbers by searching the source text; edit distance for near-miss suggestions |
| `constructs.lua` | The filter itself (details below) |

What `constructs.lua` does, per [Construct vocabulary and syntax](tickets/03-construct-vocabulary-and-syntax.md):

1. **Honorifics** (`.hon`): Arabic and English tables ported from `honorifics.pp`, fixing the honorific bugs from [Bugs to fix when porting](tickets/09-bugs-to-fix-when-porting.md). The style is picked from context: heading, footnote or body.
2. **Arabic + translation blocks** (`.ayah`, `hadith`, `arabic-quote`, `trans`):
   - Split paragraphs by script, enforcing Arabic first.
   - For `.ayah`: check any written Arabic words-only, then render from the data.
   - Emit two blocks. The translation block gets `lang`/`dir` from the book (or `translation-lang`). Use the `list-` variant inside list items.
   - Append the citation unless `cite=false`.
   - In a final edition, `trans` keeps only the English.
3. **Inline and other constructs:** highlights (fail in a final edition), `.q`, `signature`.
4. **Class checking:** near-miss classes are errors; unknown classes are warned once each; raw `custom-style` is an error; leftover GPP syntax is an error with the replacement shown.
5. **Rendering by format:** DOCX/ODT get `custom-style` with the existing style names; HTML/EPUB get classes. `.smallcaps` becomes a native SmallCaps node.

Test bed (run by hand, no CI):

- `tests/sample/`: a small book that uses every construct, option and format.
- `tests/errors/`: one small file per error case, each stating the message it expects.
- `tests/run.lua`, run as `pandoc lua tests/run.lua`: runs the filter over both folders and reports any difference from the expected messages.

**Checkpoint:** these work on the sample, and the error tests pass:
- `pandoc -f markdown --lua-filter utils/lua/constructs.lua tests/sample/… -t native`
- the same command with `-t docx`

## Phase 2: [Implement the build script](tickets/13-implement-the-build-script.md)

1. **Move files into the new `utils/` layout** ([Build command and layout](tickets/06-build-command-and-layout.md)) with plain `mv`, so the human stages the moves. Repoint every path.
2. **Command line:** commands `build` (default), `clean`, `help`, `resolve [--refresh]` and `unresolve`; formats; `key=value`; `--strict`. A usage error exits with 2.
3. **Configuration check:** every path (reference docs, CSL, bibliography, CSS, fonts, Qur'an data) must exist before any content is read. A failure exits with 2.
4. **Content:**
   - Find files in the fixed order.
   - Read each one separately with its file name (needs 3.9.0.1), so sources carry their file.
   - Apply the filter and de-duplicate heading IDs across files.
5. **Metadata:** merge `metadata.yaml`, fill in `date` if it's missing (honouring `SOURCE_DATE_EPOCH`), and wire the bibliography and CSL. Run `pandoc.utils.citeproc`. A missing citation key is an error.
6. **Writers:**
   - docx and odt use their reference docs.
   - epub3 needs its CSS and fonts, plus the default template.
   - chunkedhtml is unzipped into a folder (`pandoc.zip`).
   - html5 writes one page per file.
   - Output on Windows uses CRLF.
7. **Problems and output:** wrap everything in `pandoc.log.silence` to capture Pandoc's own warnings. Merge them with the filter's problems and apply final-edition strictness. Write to a temporary folder and move into `dist/<YYYYMMDD-HHMM>-<slug>[-final].<ext>` only if there are no errors.
8. **Resolve and unresolve:** text-level edits right after `::: {.ayah …}` lines; Pandoc's writer is never used on content files.
9. **Crash handling:** a top-level `pcall` turns any crash into one line saying it's a template bug, and never shows a traceback.

**Checkpoint:** `pandoc lua build.lua all` builds every format from `tests/sample/`, and `--strict`, `edition=final`, `clean`, `help`, `resolve` and `unresolve` behave as decided. Open the DOCX with `template.docx` styles applied to check it by eye.

## Phase 3: [Convert existing content](tickets/10-convert-existing-content.md) + [Bugs to fix when porting](tickets/09-bugs-to-fix-when-porting.md)

1. Write `utils/lua/convert-gpp.lua`. It reports anything it can't convert, and stays in the repo for other books still written with GPP.
2. Run it on `content/`. Fix the content bugs (the stray "it1"; flag the reused lineage translations to the translator).
3. Make sure `pandoc lua build.lua all` passes with zero errors on the real content.

**Checkpoint:** the human reviews the converter's report and the diff.

## Phase 4: [Retire the old pipeline](tickets/12-retire-the-old-pipeline.md) and [Rewrite README and authoring guide](tickets/14-rewrite-readme-and-authoring-guide.md)

1. Delete:
   - `utils/gpp/`
   - `makefile`
   - `utils/python/`
   - `utils/quran/quran-ayah-getter.ipynb`
   - `utils/lua_filters/inject-date.lua`
   - (`convert-gpp.lua` is kept for other books still written with GPP; see the conversion ticket)
2. **README:** dependencies are just "Pandoc ≥ 3.9.0.1", plus the one command. Keep the guidelines and the roadmap.
3. **`docs/authoring-guide.md`:** every construct, the ayah-reference grammar, edition options, and how to read errors. Written for translators first.

**Checkpoint (destination reached):** a fresh clone with only Pandoc installed builds every format with one command.

## Risks

- **Pandoc version:** Linux distro packages are too old. The README must point people to the release binaries.
- **Windows is untested.** At least one manual run is needed before the destination counts as reached.
- **Citations in Lua:** `pandoc.utils.citeproc` plus the CSL file must give the same footnotes as the CLI did. Check this early in Phase 2 with one `[@saadi02]`.
- **KFGQPC licence:** still unconfirmed. It's out of scope here, but `SOURCE.md` records it.
