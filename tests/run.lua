-- Template self-test. Run from the repository root:
--
--   pandoc lua tests/run.lua
--
-- 1. Ayah grammar: fixed references resolve to known Arabic and citations.
-- 2. Options: validation catches bad names and values.
-- 3. Error cases: every file in tests/errors/ produces exactly the problems
--    its "<!-- expect: severity@line: text -->" comments list.
-- 4. Sample book: tests/sample/ builds in every format with no errors.

local script_directory = (arg and arg[0] or "tests/run.lua"):match("^(.*)[/\\]") or "."
local root = pandoc.path.normalize(pandoc.path.join({ script_directory, ".." }))
package.path = pandoc.path.join({ root, "utils", "lua", "?.lua" }) .. ";" .. package.path

local grammar = require("ayah_grammar")
local quran = require("quran")
local options = require("options")
local construct_filter = require("construct_filter")
local Problems = require("problems")

local data_directory = pandoc.path.join({ root, "utils", "quran" })
local failures = 0
local checks = 0

local function check(condition, description)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL: ", description, "\n")
  end
end

local function read_file(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("a"):gsub("\r\n", "\n")
  handle:close()
  return text
end

---------------------------------------------------------------------------
-- 1. Ayah grammar
---------------------------------------------------------------------------

local data = quran.load(data_directory)
local NBSP = quran.NBSP
local grammar_cases = {
  { "21:107", "always", "short", "(Q21:107)", "وَمَآ أَرۡسَلۡنَٰكَ إِلَّا رَحۡمَةٗ لِّلۡعَٰلَمِينَ" .. NBSP .. "١٠٧" },
  { "21:107|prefix-3", "always", "short", "(Q21:107)", "وَمَآ أَرۡسَلۡنَٰكَ إِلَّا …" .. NBSP .. "١٠٧" },
  { "21:107|prefix-3", "ended", "short", "(Q21:107)", "وَمَآ أَرۡسَلۡنَٰكَ إِلَّا …" },
  { "2:255|prefix-10|suffix-4", "always", "short", "(Q2:255)", "… ٱلۡقَيُّومُۚ لَا تَأۡخُذُهُۥ سِنَةٞ …" .. NBSP .. "٢٥٥" },
  { "2:1-3; 2:4", "always", "short", "(Q2:1–4)", nil },
  { "2:1-3; 2:5", "always", "short", "(Q2:1–3, 5)", nil },
  { "1:7; 2:1-2", "always", "long", "(al-Fātiḥah, Q1:7; al-Baqarah, Q2:1–2)", nil },
  { "112", "always", "short", "(Q112)", nil },
}
for _, case in ipairs(grammar_cases) do
  local reference, ayah_numbers, citation_style, citation, arabic = table.unpack(case)
  local result = grammar.resolve(reference, data, { ayah_numbers = ayah_numbers, citation_style = citation_style })
  check(#result.errors == 0, reference .. ": unexpected errors " .. table.concat(result.errors, "; "))
  check(result.citation == citation, reference .. ": citation " .. tostring(result.citation) .. " ~= " .. citation)
  if arabic then
    check(result.arabic and quran.canonical(result.arabic) == quran.canonical(arabic), reference .. ": Arabic was " .. tostring(result.arabic))
  end
end
local gap_result = grammar.resolve("2:1-3; 2:5", data, {})
check(gap_result.arabic and gap_result.arabic:find(" … ", 1, true) ~= nil, "2:1-3; 2:5 marks the gap with …")
local hizb_result = grammar.resolve("2:26|prefix-2", data, {})
check(hizb_result.arabic and not hizb_result.arabic:find(quran.HIZB_MARK, 1, true), "the hizb mark is dropped")
check(quran.canonical("\u{644}\u{651}\u{650}") == quran.canonical("\u{644}\u{650}\u{651}"),
  "canonical ordering of shadda and kasra")
check(quran.canonical("\u{622}") == quran.canonical("\u{627}\u{653}"), "canonical decomposition of alef madda")

---------------------------------------------------------------------------
-- 2. Options
---------------------------------------------------------------------------

local function messages(errors)
  local list = {}
  for _, item in ipairs(errors) do list[#list + 1] = item.message .. " " .. (item.hint or "") end
  return table.concat(list, " | ")
end

check(#options.validate({ edition = "final", epub = { honorifics = "english" } }, { ["ayah-numbers"] = "ended" }) == 0,
  "valid options pass")
check(messages(options.validate({ edition = "finall" })):find('did you mean "final"', 1, true) ~= nil,
  "bad option value gets a suggestion")
check(messages(options.validate({ honorific = "english" })):find('did you mean "honorifics"', 1, true) ~= nil,
  "bad option name gets a suggestion")
check(messages(options.validate({}, { colour = "red" })):find("command line", 1, true) ~= nil,
  "bad command-line option is reported")
local resolved = options.resolve({ honorifics = "arabic", epub = { honorifics = "english" } }, "epub", { edition = "final" }, "en-US")
check(resolved.honorifics == "english" and resolved.edition == "final" and resolved["translation-lang"] == "en-US",
  "precedence: command line > format section > book-wide > default")

---------------------------------------------------------------------------
-- 3. Error cases
---------------------------------------------------------------------------

local errors_directory = pandoc.path.join({ root, "tests", "errors" })
local error_files = pandoc.system.list_directory(errors_directory)
table.sort(error_files)
for _, name in ipairs(error_files) do
  if name:match("%.md$") then
    local relative_path = "tests/errors/" .. name
    local source = read_file(pandoc.path.join({ errors_directory, name }))
    local doc = pandoc.read({ { relative_path, source } }, "markdown")
    local problems = Problems.new()
    local template_block = options.plain(doc.meta.template) or {}
    local option_values = options.resolve(template_block, "docx", {}, "en-US")
    construct_filter.apply(doc, {
      file = relative_path, source = source, format = "docx", options = option_values,
      data_directory = data_directory, problems = problems,
    })

    local expectations = {}
    for severity, line, text in source:gmatch("<!%-%- expect: (%a+)@(%d+): (.-) %-%->") do
      expectations[#expectations + 1] = { severity = severity, line = tonumber(line), text = text }
    end

    local unmatched = {}
    for _, problem in ipairs(problems.items) do unmatched[#unmatched + 1] = problem end
    for _, expectation in ipairs(expectations) do
      local found_index
      for problem_index, problem in ipairs(unmatched) do
        if problem.severity == expectation.severity and problem.line == expectation.line
          and problem.message:find(expectation.text, 1, true) then
          found_index = problem_index
          break
        end
      end
      if found_index then
        table.remove(unmatched, found_index)
      else
        check(false, ("%s: expected %s@%d: %s"):format(relative_path, expectation.severity, expectation.line, expectation.text))
      end
    end
    for _, problem in ipairs(unmatched) do
      check(false, relative_path .. ": unexpected " .. Problems.format(problem))
    end
    checks = checks + 1
  end
end

---------------------------------------------------------------------------
-- 4. Sample book (only once build.lua exists)
---------------------------------------------------------------------------

local build_script = pandoc.path.join({ root, "build.lua" })
if io.open(build_script, "rb") then
  local sample = pandoc.path.join({ root, "tests", "sample" })
  pandoc.system.with_temporary_directory("template-test", function(directory)
    local ok, output = pcall(pandoc.system.command, "pandoc",
      { "lua", build_script, "all", "--book=" .. sample, "--dist=" .. directory })
    check(ok, "sample book builds in every format" .. (ok and "" or (": " .. tostring(output))))
    if ok then
      local produced = pandoc.system.list_directory(directory)
      check(#produced == 5, "sample book produced 5 outputs, got " .. #produced)
    end
  end)
end

io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
