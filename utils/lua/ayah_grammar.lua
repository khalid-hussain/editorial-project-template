-- Ayah references: parsing, resolving to Arabic text, and citations.
--
--   reference = part ( ";" part )*          2:1-3; 2:5
--   part      = location ( "|" slice )*     21:107|suffix-5
--   location  = surah | surah ":" ayah | surah ":" ayah "-" ayah
--   slice     = "prefix-" N | "suffix-" N   (applied left to right)
--
-- Only words are counted; ayah numbers and the hizb mark never are. A cut is
-- marked with "…"; a cut ayah reads "words … number". Non-adjacent parts are
-- joined with " … ". Pure functions over the data from quran.lua.

local quran = require("quran")

local grammar = {}

local ELLIPSIS = "…"
local NBSP = quran.NBSP
local SLICE_KINDS = { prefix = true, suffix = true }
local SLICE_SUGGESTIONS = {
  sufix = "suffix", suffex = "suffix", sufex = "suffix", sufix_ = "suffix",
  prefex = "prefix", perfix = "prefix", prefx = "prefix",
  first = "prefix", start = "prefix", last = "suffix", ["end"] = "suffix",
}

local function trim(text)
  return (text:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function split_plain(text, separator)
  local pieces = {}
  local cursor = 1
  while true do
    local position = text:find(separator, cursor, true)
    if not position then
      pieces[#pieces + 1] = text:sub(cursor)
      return pieces
    end
    pieces[#pieces + 1] = text:sub(cursor, position - 1)
    cursor = position + #separator
  end
end

--- Parse reference text. Returns parts, errors (list of message strings).
function grammar.parse(text)
  local parts = {}
  local errors = {}

  for _, piece in ipairs(split_plain(text, ";")) do
    local trimmed = trim(piece)
    if trimmed == "" then
      errors[#errors + 1] = 'empty reference: check for a stray ";"'
    else
      local segments = split_plain(trimmed, "|")
      local location_text = trim(segments[1])
      local surah, first_ayah, last_ayah
      local whole_surah = location_text:match("^(%d+)$")
      local single_surah, single_ayah = location_text:match("^(%d+):(%d+)$")
      local range_surah, range_first, range_last = location_text:match("^(%d+):(%d+)[ \t]*%-[ \t]*(%d+)$")

      if whole_surah then
        surah = tonumber(whole_surah)
      elseif single_surah then
        surah, first_ayah = tonumber(single_surah), tonumber(single_ayah)
        last_ayah = first_ayah
      elseif range_surah then
        surah, first_ayah, last_ayah = tonumber(range_surah), tonumber(range_first), tonumber(range_last)
      end

      if not surah then
        if location_text:match("^%d+:%d+[ \t]*%-[ \t]*%d+:%d+$") then
          errors[#errors + 1] = ('"%s": a range must stay inside one surah; join surahs with ";" (e.g. 1:7; 2:1)'):format(location_text)
        else
          errors[#errors + 1] = ('"%s" is not an ayah location; expected surah, surah:ayah, or surah:ayah-ayah'):format(location_text)
        end
      else
        local slices = {}
        for segment_index = 2, #segments do
          local slice_text = trim(segments[segment_index])
          local kind, count = slice_text:match("^([%a_]+)%-(%d+)$")
          if not kind then
            errors[#errors + 1] = ('"|%s" is not a word slice; use prefix-N or suffix-N'):format(slice_text)
          else
            kind = kind:lower()
            if SLICE_KINDS[kind] then
              slices[#slices + 1] = { kind = kind, count = tonumber(count) }
            else
              local suggestion = SLICE_SUGGESTIONS[kind]
              errors[#errors + 1] = ('unknown slice "%s"'):format(kind)
                .. (suggestion and ('; did you mean "%s"?'):format(suggestion) or "; use prefix or suffix")
            end
          end
        end
        parts[#parts + 1] = {
          source = trimmed, surah = surah, first_ayah = first_ayah, last_ayah = last_ayah, slices = slices,
        }
      end
    end
  end

  return parts, errors
end

local function render_words(words, start_index, stop_index, ayah_numbers)
  local pieces = {}
  if start_index > 1 then pieces[#pieces + 1] = ELLIPSIS end
  for word_index = start_index, stop_index do
    local word = words[word_index]
    local next_word = word_index < stop_index and words[word_index + 1] or nil
    local last_selected_of_ayah = (next_word == nil) or (next_word.ayah ~= word.ayah)
    local text = word.text
    local ayah_cut_here = last_selected_of_ayah and not word.ends_ayah
    if ayah_cut_here then text = text .. " " .. ELLIPSIS end
    local show_number
    if ayah_numbers == "always" then
      show_number = last_selected_of_ayah
    elseif ayah_numbers == "ended" then
      show_number = word.ends_ayah
    else
      show_number = false
    end
    if show_number then text = text .. NBSP .. word.number end
    pieces[#pieces + 1] = text
  end
  return table.concat(pieces, " ")
end

--- Resolve one parsed part against the data.
function grammar.resolve_part(part, data, options)
  local errors = {}
  local surah_ayat = data.ayat[part.surah]
  if not surah_ayat then
    return { part = part, errors = { ("surah %d does not exist (1–114)"):format(part.surah) } }
  end
  local surah_name = data.names[part.surah] or ("surah " .. part.surah)
  local ayah_count = #surah_ayat
  local whole_surah = part.first_ayah == nil
  local first_ayah = part.first_ayah or 1
  local last_ayah = whole_surah and ayah_count or part.last_ayah

  if first_ayah < 1 or first_ayah > ayah_count then
    errors[#errors + 1] = ("%s (surah %d) has %d ayat; there is no ayah %d"):format(surah_name, part.surah, ayah_count, first_ayah)
  elseif last_ayah > ayah_count then
    errors[#errors + 1] = ("%s (surah %d) has %d ayat; the range ends at %d"):format(surah_name, part.surah, ayah_count, last_ayah)
  end
  if last_ayah < first_ayah then
    errors[#errors + 1] = ('"%s": the range runs backwards'):format(part.source)
  end
  if #errors > 0 then return { part = part, errors = errors } end

  local words = {}
  for ayah = first_ayah, last_ayah do
    local tokens = quran.tokenize(surah_ayat[ayah])
    for word_index, text in ipairs(tokens.words) do
      words[#words + 1] = {
        text = text, ayah = ayah, number = tokens.number, ends_ayah = word_index == #tokens.words,
      }
    end
  end

  local start_index, stop_index = 1, #words
  for _, slice in ipairs(part.slices) do
    local available = stop_index - start_index + 1
    if slice.count < 1 then
      errors[#errors + 1] = ("%s-%d: a slice needs at least 1 word"):format(slice.kind, slice.count)
      break
    end
    if slice.count > available then
      errors[#errors + 1] = ("%s-%d asks for %d words, but only %d are selected at that point")
        :format(slice.kind, slice.count, slice.count, available)
      break
    end
    if slice.kind == "prefix" then
      stop_index = start_index + slice.count - 1
    else
      start_index = stop_index - slice.count + 1
    end
  end
  if #errors > 0 then return { part = part, errors = errors } end

  local selected_words = {}
  for word_index = start_index, stop_index do selected_words[#selected_words + 1] = words[word_index].text end

  return {
    part = part,
    errors = {},
    arabic = render_words(words, start_index, stop_index, options.ayah_numbers or "always"),
    selected_words = selected_words,
    cut_at_start = start_index > 1,
    cut_at_end = stop_index < #words,
    first_ayah = first_ayah,
    last_ayah = last_ayah,
    whole_surah = whole_surah,
  }
end

local function is_adjacent(previous, following, data)
  if previous.cut_at_end or following.cut_at_start then return false end
  local previous_surah = previous.part.surah
  local following_surah = following.part.surah
  if following_surah == previous_surah then
    return following.first_ayah == previous.last_ayah + 1
  end
  return following_surah == previous_surah + 1
    and previous.last_ayah == #data.ayat[previous_surah]
    and following.first_ayah == 1
end

local function join_parts(resolved_parts, data)
  local pieces = {}
  for part_index, resolved in ipairs(resolved_parts) do
    if part_index > 1 then
      local previous = resolved_parts[part_index - 1]
      local gap_already_marked = previous.cut_at_end or resolved.cut_at_start
      local show_gap = not gap_already_marked and not is_adjacent(previous, resolved, data)
      pieces[#pieces + 1] = show_gap and (" " .. ELLIPSIS .. " ") or " "
    end
    pieces[#pieces + 1] = resolved.arabic
  end
  return table.concat(pieces)
end

--- Format the citation, merging adjacent ranges in the same surah.
function grammar.citation(resolved_parts, data, style)
  local groups = {}
  for _, resolved in ipairs(resolved_parts) do
    local last_group = groups[#groups]
    local same_surah = last_group and last_group.surah == resolved.part.surah
      and not last_group.whole_surah and not resolved.whole_surah
    if same_surah then
      local last_range = last_group.ranges[#last_group.ranges]
      if resolved.first_ayah <= last_range.last + 1 then
        last_range.last = math.max(last_range.last, resolved.last_ayah)
      else
        last_group.ranges[#last_group.ranges + 1] = { first = resolved.first_ayah, last = resolved.last_ayah }
      end
    else
      groups[#groups + 1] = {
        surah = resolved.part.surah,
        whole_surah = resolved.whole_surah,
        ranges = resolved.whole_surah and {} or { { first = resolved.first_ayah, last = resolved.last_ayah } },
      }
    end
  end

  local group_texts = {}
  for _, group in ipairs(groups) do
    local range_texts = {}
    for _, range in ipairs(group.ranges) do
      range_texts[#range_texts + 1] = range.first == range.last and tostring(range.first)
        or (range.first .. "–" .. range.last)
    end
    local location = group.whole_surah and ("Q" .. group.surah)
      or ("Q" .. group.surah .. ":" .. table.concat(range_texts, ", "))
    if style == "long" then location = (data.names[group.surah] or "") .. ", " .. location end
    group_texts[#group_texts + 1] = location
  end
  return "(" .. table.concat(group_texts, "; ") .. ")"
end

--- Resolve reference text fully. Returns { errors, parts, arabic, citation, selected_words }.
--- options: { ayah_numbers = "always"|"ended"|"never", citation_style = "short"|"long" }
function grammar.resolve(text, data, options)
  options = options or {}
  local parts, errors = grammar.parse(text)
  if #errors > 0 then return { errors = errors, parts = {} } end
  if #parts == 0 then return { errors = { "empty reference" }, parts = {} } end

  local resolved_parts = {}
  local part_errors = {}
  for _, part in ipairs(parts) do
    local resolved = grammar.resolve_part(part, data, options)
    resolved_parts[#resolved_parts + 1] = resolved
    for _, message in ipairs(resolved.errors) do part_errors[#part_errors + 1] = message end
  end
  if #part_errors > 0 then return { errors = part_errors, parts = resolved_parts } end

  local selected_words = {}
  for _, resolved in ipairs(resolved_parts) do
    for _, word in ipairs(resolved.selected_words) do selected_words[#selected_words + 1] = word end
  end

  return {
    errors = {},
    parts = resolved_parts,
    arabic = join_parts(resolved_parts, data),
    citation = grammar.citation(resolved_parts, data, options.citation_style or "short"),
    selected_words = selected_words,
  }
end

return grammar
