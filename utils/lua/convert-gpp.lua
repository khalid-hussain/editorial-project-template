-- Convert a book written with the old GPP macros to the constructs.
--
--   pandoc lua utils/lua/convert-gpp.lua [--book=DIR] [files…]
--
-- Rewrites the files in place (default: every Markdown file under content/)
-- and reports anything it could not convert. Review the diff afterwards.
--
--   \hon{\PBUH}{\BODY}             → [pbuh]{.hon}
--   \AYAH_AR_START … \AYAH_END     → ::: {.ayah ref="…"}  (ref found from the
--                                    "(Q83:26)" at the end of the translation,
--                                    or by looking the Arabic up in the data)
--   \HADITH_AR_START … \HADITH_END → ::: hadith
--   \AR_START … \EN_END            → ::: arabic-quote
--   \trans{arabic}{english}        → ::: trans
--   \note{…} \c1{…}–\c4{…} \warn{…} → [text]{.note} …
--   \SC{term}                      → [term]{.smallcaps}
--   \surahref{21}{107}             → [21:107]{.q}
--   ::: {custom-style="left-ragged"} → ::: signature

local script_path = (arg and arg[0]) or "utils/lua/convert-gpp.lua"
local script_directory = script_path:match("^(.*)[/\\]") or "."
package.path = script_directory .. "/?.lua;" .. package.path

local quran = require("quran")

local working_directory = pandoc.system.get_working_directory()
local function absolute(path)
  if pandoc.path.is_absolute(path) then return pandoc.path.normalize(path) end
  return pandoc.path.normalize(pandoc.path.join({ working_directory, path }))
end
local data_directory = pandoc.path.join({ absolute(script_directory), "..", "quran" })

local function trim(text)
  return (text:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function read_text(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("a")
  handle:close()
  return text
end

---------------------------------------------------------------------------
-- Finding an ayah reference from Arabic text
---------------------------------------------------------------------------

local surah_words -- [surah] = { { word = canonical, ayah = n }, ... }
local function index_quran()
  if surah_words then return surah_words end
  local data = quran.load(data_directory)
  surah_words = {}
  for surah = 1, 114 do
    local words = {}
    for ayah, raw_text in ipairs(data.ayat[surah]) do
      for _, word in ipairs(quran.tokenize(raw_text).words) do
        words[#words + 1] = { word = quran.canonical(word), ayah = ayah }
      end
    end
    surah_words[surah] = words
  end
  return surah_words
end

--- Find the reference for some Arabic text. Returns ref, match_count.
local function find_reference(arabic_text)
  local written = quran.comparable_words(arabic_text)
  if #written == 0 then return nil, 0 end
  local matches = {}
  for surah, words in ipairs(index_quran()) do
    for start_index = 1, #words - #written + 1 do
      if words[start_index].word == written[1] then
        local is_match = true
        for offset = 2, #written do
          if words[start_index + offset - 1].word ~= written[offset] then is_match = false break end
        end
        if is_match then
          local stop_index = start_index + #written - 1
          local first_ayah, last_ayah = words[start_index].ayah, words[stop_index].ayah
          local location_start, location_stop = start_index, stop_index
          while location_start > 1 and words[location_start - 1].ayah == first_ayah do location_start = location_start - 1 end
          while location_stop < #words and words[location_stop + 1].ayah == last_ayah do location_stop = location_stop + 1 end
          local ref = first_ayah == last_ayah and ("%d:%d"):format(surah, first_ayah)
            or ("%d:%d-%d"):format(surah, first_ayah, last_ayah)
          local cut_start, cut_end = start_index > location_start, stop_index < location_stop
          if cut_start and cut_end then
            ref = ref .. ("|prefix-%d|suffix-%d"):format(stop_index - location_start + 1, #written)
          elseif cut_end then
            ref = ref .. ("|prefix-%d"):format(#written)
          elseif cut_start then
            ref = ref .. ("|suffix-%d"):format(#written)
          end
          matches[#matches + 1] = ref
        end
      end
    end
  end
  return matches[1], #matches
end

---------------------------------------------------------------------------
-- Block markers (\AYAH_AR_START … on their own lines)
---------------------------------------------------------------------------

local BLOCK_MARKERS = {
  AYAH_AR = { construct = "ayah", side = "arabic" },
  AYAH = { construct = "ayah", side = "translation" },
  LIST_AYAH_AR = { construct = "ayah", side = "arabic" },
  LIST_AYAH = { construct = "ayah", side = "translation" },
  HADITH_AR = { construct = "hadith", side = "arabic" },
  HADITH = { construct = "hadith", side = "translation" },
  LIST_HADITH_AR = { construct = "hadith", side = "arabic" },
  LIST_HADITH = { construct = "hadith", side = "translation" },
  AR = { construct = "arabic-quote", side = "arabic" },
  EN = { construct = "arabic-quote", side = "translation" },
}

local function convert_blocks(text, file, report)
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
  if lines[#lines] == "" then table.remove(lines) end

  -- Collect marked regions.
  local regions = {}
  local line_index = 1
  while line_index <= #lines do
    local marker = trim(lines[line_index]):match("^\\([%u_]+)_START$")
    local spec = marker and BLOCK_MARKERS[marker]
    if spec then
      local body = {}
      local end_index
      for scan_index = line_index + 1, #lines do
        if trim(lines[scan_index]) == "\\" .. marker .. "_END" then end_index = scan_index break end
        body[#body + 1] = lines[scan_index]
      end
      if not end_index then
        report(file, line_index, ("\\%s_START has no matching \\%s_END; left unchanged"):format(marker, marker))
        line_index = line_index + 1
      else
        regions[#regions + 1] = {
          start_line = line_index, end_line = end_index, construct = spec.construct, side = spec.side,
          text = trim(table.concat(body, "\n")), indent = lines[line_index]:match("^([ \t]*)"),
        }
        line_index = end_index + 1
      end
    else
      line_index = line_index + 1
    end
  end

  -- Pair an Arabic region with the translation region right after it.
  local replacements = {}
  local region_index = 1
  while region_index <= #regions do
    local region = regions[region_index]
    local following = regions[region_index + 1]
    local arabic, translation, last_region = nil, nil, region
    if region.side == "arabic" then
      arabic = region
      if following and following.side == "translation" and following.construct == region.construct then
        local only_blank_between = true
        for index = region.end_line + 1, following.start_line - 1 do
          if trim(lines[index]) ~= "" then only_blank_between = false end
        end
        if only_blank_between then translation, last_region = following, following end
      end
    else
      translation = region
    end
    region_index = region_index + (last_region == region and 1 or 2)

    local indent = region.indent
    local output = {}
    local translation_text = translation and translation.text or nil
    if region.construct == "ayah" then
      local ref
      if translation_text then
        local surah, ayah_text = translation_text:match("%(Q(%d+):([%d%-–,]+)%)%s*$")
        if surah then
          ref = surah .. ":" .. ayah_text:gsub("–", "-")
          translation_text = trim(translation_text:gsub("%(Q%d+:[%d%-–,]+%)%s*$", ""))
        end
      end
      local keep_arabic = false
      if not ref and arabic then
        local found, match_count = find_reference(arabic.text)
        if found then
          ref = found
          report(file, region.start_line, ("ayah reference %s found from the Arabic text%s"):format(found,
            match_count > 1 and (" (the text occurs %d times; check it)"):format(match_count) or ""), "info")
        end
      end
      if not ref then
        ref = "FIXME"
        keep_arabic = arabic ~= nil
        report(file, region.start_line, 'could not work out the ayah reference; wrote ref="FIXME" for you to fill in')
      end
      output[#output + 1] = indent .. ('::: {.ayah ref="%s"}'):format(ref)
      if keep_arabic then
        output[#output + 1] = arabic.text
        if translation_text then output[#output + 1] = "" end
      end
    else
      output[#output + 1] = indent .. "::: " .. region.construct
      if arabic then
        output[#output + 1] = arabic.text
        if translation_text then output[#output + 1] = "" end
      end
    end
    if translation_text and translation_text ~= "" then output[#output + 1] = translation_text end
    output[#output + 1] = indent .. ":::"
    replacements[#replacements + 1] = { start_line = region.start_line, end_line = last_region.end_line, lines = output }
  end

  -- Apply replacements from the bottom up.
  for replacement_index = #replacements, 1, -1 do
    local replacement = replacements[replacement_index]
    for _ = replacement.start_line, replacement.end_line do table.remove(lines, replacement.start_line) end
    for offset, line in ipairs(replacement.lines) do table.insert(lines, replacement.start_line + offset - 1, line) end
  end
  return table.concat(lines, "\n") .. "\n"
end

---------------------------------------------------------------------------
-- Inline macros (\hon{…}{…}, \trans{…}{…}, …)
---------------------------------------------------------------------------

local MACRO_ARGUMENTS = {
  hon = 2, trans = 2, surahref = 2, SC = 1, note = 1, c1 = 1, c2 = 1, c3 = 1, c4 = 1, warn = 1,
}

local function line_of(text, position)
  local _, newline_count = text:sub(1, position):gsub("\n", "")
  return newline_count + 1
end

--- Read a {…} group starting at position; returns content, position after it.
local function read_group(text, position)
  if text:sub(position, position) ~= "{" then return nil end
  local depth = 0
  for index = position, #text do
    local character = text:sub(index, index)
    if character == "{" then
      depth = depth + 1
    elseif character == "}" then
      depth = depth - 1
      if depth == 0 then return text:sub(position + 1, index - 1), index + 1 end
    end
  end
  return nil
end

local convert_inline

local function convert_macro(name, arguments, file, report, line)
  if name == "hon" then
    local key = trim(arguments[1]):gsub("^\\", ""):lower():gsub("_", "-")
    return ("[%s]{.hon}"):format(key)
  elseif name == "trans" then
    local arabic = trim(convert_inline(arguments[1], file, report, line))
    local english = trim(convert_inline(arguments[2], file, report, line))
    return ("::: trans\n%s\n\n%s\n:::"):format(arabic, english)
  elseif name == "surahref" then
    return ("[%s:%s]{.q}"):format(trim(arguments[1]), trim(arguments[2]))
  elseif name == "SC" then
    return ("[%s]{.smallcaps}"):format(convert_inline(arguments[1], file, report, line))
  end
  return ("[%s]{.%s}"):format(convert_inline(arguments[1], file, report, line), name)
end

function convert_inline(text, file, report, base_line)
  local pieces = {}
  local cursor = 1
  while true do
    local start, stop, name = text:find("\\([%a%d_]+)", cursor)
    if not start then break end
    local argument_count = MACRO_ARGUMENTS[name]
    pieces[#pieces + 1] = text:sub(cursor, start - 1)
    if argument_count then
      local arguments, position = {}, stop + 1
      for _ = 1, argument_count do
        local content, next_position = read_group(text, position)
        if not content then break end
        arguments[#arguments + 1] = content
        position = next_position
      end
      if #arguments == argument_count then
        pieces[#pieces + 1] = convert_macro(name, arguments, file, report, base_line + line_of(text, start) - 1)
        cursor = position
      else
        report(file, base_line + line_of(text, start) - 1, ("\\%s is missing an argument; left unchanged"):format(name))
        pieces[#pieces + 1] = text:sub(start, stop)
        cursor = stop + 1
      end
    else
      pieces[#pieces + 1] = text:sub(start, stop)
      cursor = stop + 1
    end
  end
  pieces[#pieces + 1] = text:sub(cursor)
  return table.concat(pieces)
end

local function report_leftovers(text, file, report)
  local line_number = 0
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line_number = line_number + 1
    for name in line:gmatch("\\(%u[%u%d_]+)") do
      report(file, line_number, ("\\%s could not be converted; replace it by hand"):format(name))
    end
  end
end

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------

local book_directory = working_directory
local files = {}
for _, argument in ipairs(arg or {}) do
  local book = argument:match("^%-%-book=(.*)$")
  if book then book_directory = absolute(book) else files[#files + 1] = absolute(argument) end
end
if #files == 0 then
  local content_directory = pandoc.path.join({ book_directory, "content" })
  local copyright = pandoc.path.join({ content_directory, "copyright.md" })
  if io.open(copyright, "rb") then files[#files + 1] = copyright end
  for _, section in ipairs({ "frontmatter", "mainmatter", "backmatter" }) do
    local directory = pandoc.path.join({ content_directory, section })
    local ok, names = pcall(pandoc.system.list_directory, directory)
    if ok then
      table.sort(names)
      for _, name in ipairs(names) do
        if name:match("%.md$") then files[#files + 1] = pandoc.path.join({ directory, name }) end
      end
    end
  end
end

local problem_count, changed_count = 0, 0
local function report(file, line, message, kind)
  if kind ~= "info" then problem_count = problem_count + 1 end
  io.stderr:write(("%s:%d: %s: %s\n"):format(file, line, kind or "needs review", message))
end

for _, path in ipairs(files) do
  local relative = pandoc.path.make_relative(path, book_directory)
  local original = read_text(path)
  local uses_crlf = original:find("\r\n", 1, true) ~= nil
  local text = original:gsub("\r\n", "\n")
  local had_final_newline = text:sub(-1) == "\n"
  text = convert_blocks(text, relative, report)
  if not had_final_newline then text = text:gsub("\n$", "") end
  text = text:gsub('::: *{ *custom%-style="left%-ragged" *}', "::: signature")
  text = convert_inline(text, relative, report, 1)
  report_leftovers(text, relative, report)
  if uses_crlf then text = text:gsub("\n", "\r\n") end
  if text ~= original then
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
    changed_count = changed_count + 1
    io.stdout:write("converted ", relative, "\n")
  end
end
io.stdout:write(("%d file(s) converted, %d item(s) need review.\n"):format(changed_count, problem_count))
