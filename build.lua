-- Editorial project template: the build.
--
--   pandoc lua build.lua                       DOCX draft
--   pandoc lua build.lua docx epub edition=final
--   pandoc lua build.lua all --strict
--   pandoc lua build.lua resolve [--refresh] [files…]
--   pandoc lua build.lua unresolve [files…]
--   pandoc lua build.lua clean
--   pandoc lua build.lua help
--
-- Needs only Pandoc >= 3.9.0.1. Exit codes: 0 success (warnings allowed),
-- 1 content errors, 2 configuration or usage errors, 3 a bug in the template.

local MINIMUM_PANDOC = { 3, 9, 0, 1 }

local script_path = (arg and arg[0]) or "build.lua"
local working_directory = pandoc.system.get_working_directory()
local function absolute(path)
  if pandoc.path.is_absolute(path) then return pandoc.path.normalize(path) end
  return pandoc.path.normalize(pandoc.path.join({ working_directory, path }))
end
local root = pandoc.path.directory(absolute(script_path))
package.path = pandoc.path.join({ root, "utils", "lua", "?.lua" }) .. ";" .. package.path

local construct_filter = require("construct_filter")
local options = require("options")
local Problems = require("problems")
local grammar = require("ayah_grammar")
local quran = require("quran")
local resolve = require("resolve")
local reference_styles = require("reference_styles")
local suggest = require("suggest")

---------------------------------------------------------------------------
-- Paths
---------------------------------------------------------------------------

local function utils_path(...)
  return pandoc.path.join({ root, "utils", ... })
end

local TEMPLATE_PATHS = {
  { "DOCX reference doc", utils_path("templates", "template.docx") },
  { "ODT reference doc", utils_path("templates", "template.odt") },
  { "citation style", utils_path("chicago-fullnote-bibliography-short-title-subsequent.csl") },
  { "bibliography", utils_path("master.bib") },
  { "EPUB stylesheet", utils_path("css", "boilerplate.css") },
  { "EPUB stylesheet", utils_path("css", "trueilm.css") },
  { "EPUB font", utils_path("fonts", "UthmanTN1Ver20.ttf") },
  { "EPUB font", utils_path("fonts", "UthmanicHafs_V22.ttf") },
  { "Qur'an data", utils_path("quran", "hafsData_v18.csv") },
  { "surah names", utils_path("quran", "surah-names.csv") },
}

local PATHS = {
  docx_template = TEMPLATE_PATHS[1][2],
  odt_template = TEMPLATE_PATHS[2][2],
  csl = TEMPLATE_PATHS[3][2],
  bibliography = TEMPLATE_PATHS[4][2],
  stylesheets = { TEMPLATE_PATHS[5][2], TEMPLATE_PATHS[6][2] },
  fonts = { TEMPLATE_PATHS[7][2], TEMPLATE_PATHS[8][2] },
  quran_data = utils_path("quran"),
}

local CONTENT_SECTIONS = { "frontmatter", "mainmatter", "backmatter" }
local COMMANDS = { "build", "clean", "help", "resolve", "unresolve" }
local FORMAT_EXTENSIONS = { docx = "docx", odt = "odt", icml = "icml", epub = "epub" }
local DATE_FORMAT = "%a %d %b %Y %I:%M%p"

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function stop(exit_code, message, hint)
  error({ exit_code = exit_code, message = message, hint = hint }, 0)
end

local function file_exists(path)
  local handle = io.open(path, "rb")
  if handle then handle:close() return true end
  return false
end

local function read_text(path)
  local handle, open_error = io.open(path, "rb")
  if not handle then stop(2, ("cannot read %s: %s"):format(path, open_error)) end
  local text = handle:read("a")
  handle:close()
  return text
end

local function write_bytes(path, bytes)
  pandoc.system.make_directory(pandoc.path.directory(path), true)
  local handle, open_error = io.open(path, "wb")
  if not handle then stop(2, ("cannot write %s: %s"):format(path, open_error)) end
  handle:write(bytes)
  handle:close()
end

local function list_markdown(directory)
  local ok, names = pcall(pandoc.system.list_directory, directory)
  if not ok then return {} end
  local markdown = {}
  for _, name in ipairs(names) do
    if name:match("%.md$") then markdown[#markdown + 1] = name end
  end
  table.sort(markdown)
  return markdown
end

local function relative_to(base, path)
  local relative = pandoc.path.make_relative(path, base)
  return (relative:gsub("\\", "/"))
end

local function is_windows()
  return pandoc.system.os == "mingw32" or pandoc.system.os == "windows"
end

local TRANSLITERATION = {
  ["ā"] = "a", ["ī"] = "i", ["ū"] = "u", ["ḥ"] = "h", ["ṣ"] = "s", ["ḍ"] = "d", ["ṭ"] = "t",
  ["ẓ"] = "z", ["ʿ"] = "", ["ʾ"] = "", ["Ā"] = "a", ["Ī"] = "i", ["Ū"] = "u", ["Ḥ"] = "h",
  ["Ṣ"] = "s", ["Ḍ"] = "d", ["Ṭ"] = "t", ["Ẓ"] = "z", ["á"] = "a", ["é"] = "e", ["’"] = "", ["'"] = "",
}

local function slugify(text)
  local pieces = {}
  for _, codepoint in utf8.codes(text) do
    local character = utf8.char(codepoint)
    pieces[#pieces + 1] = TRANSLITERATION[character] or character
  end
  local slug = table.concat(pieces):lower():gsub("[^a-z0-9]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
  return slug ~= "" and slug or "book"
end

local function check_pandoc_version()
  local version = PANDOC_VERSION
  for index, minimum in ipairs(MINIMUM_PANDOC) do
    local part = version[index] or 0
    if part > minimum then return end
    if part < minimum then
      stop(2, ("Pandoc %s is too old; this template needs %s or newer"):format(tostring(version), table.concat(MINIMUM_PANDOC, ".")),
        "download it from https://github.com/jgm/pandoc/releases")
    end
  end
end

---------------------------------------------------------------------------
-- Command line
---------------------------------------------------------------------------

local function parse_arguments(arguments)
  local parsed = { command = nil, formats = {}, overrides = {}, files = {}, strict = false, refresh = false }
  for _, argument in ipairs(arguments) do
    local flag_name, flag_value = argument:match("^%-%-([%w-]+)=(.*)$")
    local key, value = argument:match("^([%a][%w-]*)=(.*)$")
    if argument == "--strict" then
      parsed.strict = true
    elseif argument == "--refresh" then
      parsed.refresh = true
    elseif argument == "--help" or argument == "-h" then
      parsed.command = "help"
    elseif flag_name == "book" then
      parsed.book = flag_value
    elseif flag_name == "dist" then
      parsed.dist = flag_value
    elseif argument:match("^%-") then
      stop(2, ('unknown flag "%s"'):format(argument), "flags are --strict, --refresh, --book=DIR, --dist=DIR")
    elseif key then
      parsed.overrides[key] = value
    elseif not parsed.command and #parsed.formats == 0 and #parsed.files == 0
      and (argument == "build" or argument == "clean" or argument == "help" or argument == "resolve" or argument == "unresolve") then
      parsed.command = argument
    elseif parsed.command == "resolve" or parsed.command == "unresolve" then
      parsed.files[#parsed.files + 1] = argument
    elseif argument == "all" then
      for _, format in ipairs(options.FORMATS) do parsed.formats[#parsed.formats + 1] = format end
    elseif options.format_name(argument) then
      parsed.formats[#parsed.formats + 1] = options.format_name(argument)
    else
      local candidates = { "all" }
      for _, format in ipairs(options.FORMATS) do candidates[#candidates + 1] = format end
      for _, command in ipairs(COMMANDS) do candidates[#candidates + 1] = command end
      if argument == "pdf" or argument == "typst" then
        stop(2, "PDF output is not supported yet", "formats are: " .. table.concat(options.FORMATS, ", "))
      end
      local closest, distance = suggest.closest(argument, candidates)
      stop(2, ('unknown format or command "%s"'):format(argument),
        distance and distance <= 3 and ('did you mean "%s"?'):format(closest) or "run: pandoc lua build.lua help")
    end
  end
  parsed.command = parsed.command or "build"
  if parsed.command == "build" and #parsed.formats == 0 then parsed.formats = { "docx" } end
  -- Keep each format once, in the order given.
  local seen, unique = {}, {}
  for _, format in ipairs(parsed.formats) do
    if not seen[format] then seen[format] = true unique[#unique + 1] = format end
  end
  parsed.formats = unique
  return parsed
end

---------------------------------------------------------------------------
-- Book: metadata, options, content
---------------------------------------------------------------------------

local function load_book(book_directory)
  local metadata_path = pandoc.path.join({ book_directory, "metadata.yaml" })
  if not file_exists(metadata_path) then
    stop(2, ("no metadata.yaml in %s"):format(book_directory), "every book needs a metadata.yaml next to content/")
  end
  local metadata_text = read_text(metadata_path):gsub("\r\n", "\n")
  if not metadata_text:match("^%-%-%-") then metadata_text = "---\n" .. metadata_text .. "\n---\n" end
  local ok, metadata_doc = pcall(pandoc.read, metadata_text, "markdown")
  if not ok then stop(2, "metadata.yaml could not be read: " .. tostring(metadata_doc)) end
  local meta = metadata_doc.meta

  local content_directory = pandoc.path.join({ book_directory, "content" })
  local files = {}
  local copyright_path = pandoc.path.join({ content_directory, "copyright.md" })
  if file_exists(copyright_path) and read_text(copyright_path):match("[^ \t\r\n]") then
    files[#files + 1] = copyright_path
  end
  for _, section in ipairs(CONTENT_SECTIONS) do
    local section_directory = pandoc.path.join({ content_directory, section })
    for _, name in ipairs(list_markdown(section_directory)) do
      files[#files + 1] = pandoc.path.join({ section_directory, name })
    end
  end

  return {
    directory = book_directory,
    metadata_text = metadata_text,
    meta = meta,
    template_block = options.plain(meta.template) or {},
    lang = meta.lang and pandoc.utils.stringify(meta.lang) or nil,
    title = meta.title and pandoc.utils.stringify(meta.title) or "book",
    files = files,
  }
end

local function check_configuration(book, overrides)
  local problems = {}
  for _, entry in ipairs(TEMPLATE_PATHS) do
    if not file_exists(entry[2]) then
      problems[#problems + 1] = ("missing %s: %s"):format(entry[1], relative_to(working_directory, entry[2]))
    end
  end
  for _, config_error in ipairs(options.validate(book.template_block, overrides)) do
    problems[#problems + 1] = config_error.message .. (config_error.hint and (" (" .. config_error.hint .. ")") or "")
  end
  if #book.files == 0 then
    problems[#problems + 1] = "no content: add Markdown files to content/frontmatter, content/mainmatter or content/backmatter"
  end
  if #problems > 0 then
    for _, message in ipairs(problems) do io.stderr:write("configuration error: ", message, "\n") end
    stop(2, ("%d configuration error(s). Nothing was built."):format(#problems))
  end
end

local function build_date(meta)
  local epoch = tonumber(os.getenv("SOURCE_DATE_EPOCH") or "")
  local timestamp = epoch or os.time()
  local date_text = meta.date and pandoc.utils.stringify(meta.date) or nil
  return timestamp, (date_text == nil or date_text == "" or date_text == "DATE") and os.date(DATE_FORMAT, timestamp) or nil
end

---------------------------------------------------------------------------
-- Pandoc's own log messages
---------------------------------------------------------------------------

local function log_to_problem(message, default_file, sources)
  local entry = pandoc.json.decode(pandoc.json.encode(message))
  if entry.verbosity ~= "WARNING" and entry.verbosity ~= "ERROR" then return nil end
  local problem = {
    file = default_file, severity = entry.verbosity == "ERROR" and "error" or "warning",
    message = entry.message or entry.pretty or entry.type,
  }
  if entry.type == "CiteprocWarning" then
    local key = (entry.message or ""):match("citation (.-) not found")
    if key then
      problem.severity = "error"
      problem.message = ("citation key @%s is not in utils/master.bib"):format(key)
      for _, source in ipairs(sources or {}) do
        local position = source.text:find("@" .. key, 1, true)
        if position then
          local locator = Problems.locator(source.relative, source.text)
          problem.file, problem.line = source.relative, locator:line_of(position)
          break
        end
      end
    end
  end
  if entry.source and entry.source ~= "" and entry.line then
    problem.file, problem.line = entry.source, entry.line
  end
  return problem
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function read_sources(book)
  local sources = {}
  for _, path in ipairs(book.files) do
    local text = read_text(path):gsub("\r\n", "\n")
    sources[#sources + 1] = { path = path, relative = relative_to(book.directory, path), text = text }
  end
  return sources
end

local REFERENCE_DOCS = { docx = "docx_template", odt = "odt_template" }
local reference_style_cache = {}

--- Style names defined in the format's reference doc, or nil if it has none.
local function styles_for(format)
  local path_key = REFERENCE_DOCS[format]
  if not path_key then return nil end
  if reference_style_cache[format] == nil then
    reference_style_cache[format] = reference_styles.load(PATHS[path_key]) or false
  end
  return reference_style_cache[format] or nil, pandoc.path.filename(PATHS[path_key])
end

--- Read and filter every source for one format. Returns a list of documents.
local function filtered_documents(sources, format, option_values, problems)
  local documents = {}
  local style_names, reference_name = styles_for(format)
  for _, source in ipairs(sources) do
    local logs, doc = pandoc.log.silence(function()
      return pandoc.read({ { source.relative, source.text } }, "markdown")
    end)
    for _, message in ipairs(logs) do
      local problem = log_to_problem(message, source.relative)
      if problem then problems:add(problem) end
    end
    doc = construct_filter.apply(doc, {
      file = source.relative, source = source.text, format = format, options = option_values,
      data_directory = PATHS.quran_data, problems = problems,
      reference_styles = style_names, reference_name = reference_name,
    })
    documents[#documents + 1] = doc
  end
  return documents
end

--- Make heading identifiers unique across files (the old --file-scope did
--- this per file; reading files separately can repeat ids).
local function deduplicate_identifiers(documents)
  local used = {}
  for document_index, doc in ipairs(documents) do
    documents[document_index] = doc:walk({
      Header = function(header)
        local identifier = header.identifier
        if identifier == "" then return nil end
        if used[identifier] then
          local suffix = used[identifier]
          while used[identifier .. "-" .. suffix] do suffix = suffix + 1 end
          used[identifier] = suffix + 1
          header.identifier = identifier .. "-" .. suffix
          used[header.identifier] = 1
          return header
        end
        used[identifier] = 1
        return nil
      end,
    })
  end
end

local function book_meta(book, date_text)
  local meta = pandoc.read(book.metadata_text, "markdown").meta
  meta.template = nil
  if date_text then meta.date = pandoc.MetaInlines(pandoc.Inlines(date_text)) end
  meta.bibliography = pandoc.MetaString(PATHS.bibliography)
  meta.csl = pandoc.MetaString(PATHS.csl)
  return meta
end

local function default_template(writer_name)
  return pandoc.template.compile(pandoc.template.default(writer_name))
end

local function with_crlf_on_windows(text)
  if is_windows() then return (text:gsub("\r?\n", "\r\n")) end
  return text
end

local function cite(doc, sources, problems)
  local logs, cited = pandoc.log.silence(function() return pandoc.utils.citeproc(doc) end)
  for _, message in ipairs(logs) do
    local problem = log_to_problem(message, "(bibliography)", sources)
    if problem then problems:add(problem) end
  end
  return cited
end

--- Render one format into memory. Returns a list of outputs:
---   { path = <file under dist>, bytes = ... } or { directory = ..., files = { {path, bytes} } }
local function render_format(book, sources, format, option_values, problems, stamp, date_text, dist_directory)
  local documents = filtered_documents(sources, format, option_values, problems)
  deduplicate_identifiers(documents)
  local base_name = (option_values.timestamp == "true" and (stamp .. "-") or "")
    .. slugify(book.title) .. (option_values.edition == "final" and "-final" or "")
  local meta = book_meta(book, date_text)

  if format == "html5" then
    local files = {}
    local template = default_template("html5")
    for document_index, doc in ipairs(documents) do
      local source = sources[document_index]
      local page = pandoc.Pandoc(doc.blocks, book_meta(book, date_text))
      if not page.meta.pagetitle then page.meta.pagetitle = pandoc.MetaString(book.title) end
      page = cite(page, { source }, problems)
      local logs, html = pandoc.log.silence(function()
        return pandoc.write(page, "html5", { template = template, variables = { css = PATHS.stylesheets } })
      end)
      for _, message in ipairs(logs) do
        local problem = log_to_problem(message, source.relative)
        if problem then problems:add(problem) end
      end
      local page_name = source.relative:gsub("^content/", ""):gsub("[/\\]", "-"):gsub("%.md$", ".html")
      files[#files + 1] = { path = page_name, bytes = with_crlf_on_windows(html) }
    end
    return { { directory = pandoc.path.join({ dist_directory, base_name .. "-html" }), files = files } }
  end

  local blocks = pandoc.Blocks({})
  for _, doc in ipairs(documents) do blocks:extend(doc.blocks) end
  local combined = cite(pandoc.Pandoc(blocks, meta), sources, problems)

  local writer_name, writer_options
  if format == "docx" then
    writer_name, writer_options = "docx", { reference_doc = PATHS.docx_template, number_sections = true }
  elseif format == "odt" then
    writer_name, writer_options = "odt", { reference_doc = PATHS.odt_template, number_sections = true }
  elseif format == "icml" then
    writer_name, writer_options = "icml", { template = default_template("icml") }
  elseif format == "epub" then
    writer_name, writer_options = "epub3", {
      template = default_template("epub3"),
      variables = { css = PATHS.stylesheets },
      epub_fonts = PATHS.fonts,
    }
  elseif format == "chunkedhtml" then
    writer_name, writer_options = "chunkedhtml", {
      template = default_template("chunkedhtml"),
      variables = { css = PATHS.stylesheets },
    }
  end

  local logs, bytes = pandoc.log.silence(function()
    return pandoc.write(combined, writer_name, writer_options)
  end)
  for _, message in ipairs(logs) do
    local problem = log_to_problem(message, "(" .. format .. " writer)")
    if problem then problems:add(problem) end
  end

  if format == "chunkedhtml" then
    local files = {}
    for _, entry in ipairs(pandoc.zip.Archive(bytes).entries) do
      local contents = entry:contents()
      if entry.path:match("%.html$") then contents = with_crlf_on_windows(contents) end
      files[#files + 1] = { path = entry.path, bytes = contents }
    end
    return { { directory = pandoc.path.join({ dist_directory, base_name .. "-chunkedhtml" }), files = files } }
  end

  return { { path = pandoc.path.join({ dist_directory, base_name .. "." .. FORMAT_EXTENSIONS[format] }), bytes = bytes } }
end

--- Merge problems from several formats, dropping repeats.
local function merge_problems(collections)
  local merged = Problems.new()
  local seen = {}
  for _, problems in ipairs(collections) do
    for _, problem in ipairs(problems.items) do
      local key = table.concat({ problem.file or "", tostring(problem.line or ""), problem.message }, "\0")
      local existing = seen[key]
      if not existing then
        seen[key] = merged:add(problem)
      elseif problem.severity == "error" and existing.severity ~= "error" then
        existing.severity, existing.promoted = "error", problem.promoted
      end
    end
  end
  return merged
end

local function report(problems)
  local items = problems.items
  table.sort(items, function(first, second)
    if (first.file or "") ~= (second.file or "") then return (first.file or "") < (second.file or "") end
    return (first.line or 0) < (second.line or 0)
  end)
  for _, problem in ipairs(items) do io.stderr:write(Problems.format(problem), "\n") end
end

local function plural(count, word)
  return ("%d %s%s"):format(count, word, count == 1 and "" or "s")
end

local function command_build(parsed, book, dist_directory)
  local sources = read_sources(book)
  local timestamp, date_text = build_date(book.meta)
  local stamp = os.date("%Y%m%d-%H%M", timestamp)

  local collections, outputs = {}, {}
  for _, format in ipairs(parsed.formats) do
    local option_values = options.resolve(book.template_block, format, parsed.overrides, book.lang)
    local problems = Problems.new()
    local format_outputs = render_format(book, sources, format, option_values, problems, stamp, date_text, dist_directory)
    if option_values.edition == "final" or parsed.strict then problems:promote_warnings() end
    collections[#collections + 1] = problems
    for _, output in ipairs(format_outputs) do outputs[#outputs + 1] = output end
  end

  local problems = merge_problems(collections)
  report(problems)
  local error_count, warning_count = problems:count("error"), problems:count("warning")
  if error_count > 0 then
    io.stderr:write(("\n%s, %s. Nothing was written.\n"):format(plural(error_count, "error"), plural(warning_count, "warning")))
    return 1
  end

  for _, output in ipairs(outputs) do
    if output.directory then
      if pcall(pandoc.system.list_directory, output.directory) then
        pandoc.system.remove_directory(output.directory, true)
      end
      for _, file in ipairs(output.files) do write_bytes(pandoc.path.join({ output.directory, file.path }), file.bytes) end
      io.stdout:write("wrote ", relative_to(working_directory, output.directory), "/\n")
    else
      write_bytes(output.path, output.bytes)
      io.stdout:write("wrote ", relative_to(working_directory, output.path), "\n")
    end
  end
  if warning_count > 0 then io.stderr:write(("\n%s.\n"):format(plural(warning_count, "warning"))) end
  return 0
end

---------------------------------------------------------------------------
-- resolve / unresolve
---------------------------------------------------------------------------

local function command_resolve(parsed, book)
  local mode = parsed.command == "unresolve" and "unresolve" or (parsed.refresh and "refresh" or "resolve")
  local option_values = options.resolve(book.template_block, nil, parsed.overrides, book.lang)
  local grammar_options = { ayah_numbers = option_values["ayah-numbers"], citation_style = option_values["quran-citation"] }
  local data = quran.load(PATHS.quran_data)

  local paths = {}
  if #parsed.files > 0 then
    for _, file in ipairs(parsed.files) do paths[#paths + 1] = absolute(file) end
  else
    paths = book.files
  end

  local problem_count, change_count = 0, 0
  for _, path in ipairs(paths) do
    local relative = relative_to(book.directory, path)
    if not file_exists(path) then stop(2, ("no such file: %s"):format(relative)) end
    local new_text, changes, problems = resolve.process(read_text(path), data, grammar_options, mode)
    for _, change in ipairs(changes) do
      io.stdout:write(("%s:%d: %s %s\n"):format(relative, change.line, change.action, change.ref))
    end
    for _, problem in ipairs(problems) do
      io.stderr:write(Problems.format({ file = relative, line = problem.line, severity = "error", message = problem.message, hint = problem.hint }), "\n")
    end
    if new_text then write_bytes(path, new_text) end
    change_count, problem_count = change_count + #changes, problem_count + #problems
  end
  io.stdout:write(("%s changed, %s.\n"):format(plural(change_count, "ayah block"), plural(problem_count, "problem")))
  return problem_count > 0 and 1 or 0
end

---------------------------------------------------------------------------
-- help / clean
---------------------------------------------------------------------------

local function command_help(book)
  local lines = {
    "Usage: pandoc lua build.lua [command] [formats…] [option=value…] [flags]",
    "",
    "Commands:",
    "  build (default)        build the given formats (default: docx)",
    "  resolve [files…]       write ayah Arabic into ayah blocks that have none",
    "  resolve --refresh      … and replace Arabic that differs from the Qur'an text",
    "  unresolve [files…]     remove ayah Arabic that matches the Qur'an text",
    "  clean                  delete dist/",
    "  help                   this text",
    "",
    "Formats: " .. table.concat(options.FORMATS, ", ") .. ", or all",
    "",
    "Flags:",
    "  --strict               treat warnings as errors (always on for edition=final)",
    "  --book=DIR             build the book in DIR instead of this folder",
    "  --dist=DIR             write output to DIR instead of dist/",
    "",
    "Options (metadata.yaml `template:` block, per-format sections, or option=value here):",
  }
  for _, line in ipairs(lines) do io.stdout:write(line, "\n") end
  if book then
    local values, origins = options.resolve(book.template_block, nil, {}, book.lang)
    for _, name in ipairs(options.ORDER) do
      local choices = options.CHOICES[name] and table.concat(options.CHOICES[name], " | ") or "a language code"
      io.stdout:write(("  %-17s %-10s from %s\n      %s; one of: %s\n"):format(name, values[name], origins[name], options.DESCRIPTIONS[name], choices))
    end
    for _, format in ipairs(options.FORMATS) do
      local section = book.template_block[format]
      if type(section) == "table" then
        for name, value in pairs(section) do
          io.stdout:write(("  %s overrides %s = %s\n"):format(format, name, tostring(value)))
        end
      end
    end
  end
  return 0
end

local function command_clean(dist_directory)
  local ok = pcall(pandoc.system.list_directory, dist_directory)
  if ok then
    pandoc.system.remove_directory(dist_directory, true)
    io.stdout:write("removed ", relative_to(working_directory, dist_directory), "/\n")
  else
    io.stdout:write("nothing to clean\n")
  end
  return 0
end

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------

local function main(arguments)
  io.stdout:setvbuf("line")
  check_pandoc_version()
  local parsed = parse_arguments(arguments)
  local book_directory = parsed.book and absolute(parsed.book) or root
  local dist_directory = parsed.dist and absolute(parsed.dist) or pandoc.path.join({ book_directory, "dist" })

  if parsed.command == "clean" then return command_clean(dist_directory) end
  if parsed.command == "help" then
    local ok, book = pcall(load_book, book_directory)
    return command_help(ok and book or nil)
  end

  local book = load_book(book_directory)
  check_configuration(book, parsed.overrides)
  if parsed.command == "resolve" or parsed.command == "unresolve" then
    if #parsed.formats > 0 then stop(2, "resolve and unresolve take files, not formats") end
    return command_resolve(parsed, book)
  end
  return pandoc.system.with_working_directory(book_directory, function()
    return command_build(parsed, book, dist_directory)
  end)
end

local ok, result = xpcall(main, function(failure)
  if type(failure) == "table" and failure.exit_code then return failure end
  return { internal = true, message = tostring(failure), traceback = debug.traceback() }
end, arg or {})

if ok then os.exit(result or 0) end
if result.internal then
  io.stderr:write("internal error: this is a bug in the template, please report it.\n  ",
    (result.message:gsub("\n.*", "")), "\n")
  if os.getenv("TEMPLATE_DEBUG") then io.stderr:write(result.traceback, "\n") end
  os.exit(3)
end
io.stderr:write(result.message, result.hint and (" (" .. result.hint .. ")") or "", "\n")
os.exit(result.exit_code)
