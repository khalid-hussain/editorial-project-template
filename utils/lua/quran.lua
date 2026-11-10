-- Qur'an data: loads the KFGQPC Hafs CSV (shipped unmodified) and the
-- project's surah-name transliterations, and splits an ayah into its parts.

local csv = require("csv")

local quran = {}

quran.NBSP = "\u{A0}"
quran.HIZB_MARK = "۞"
local HIZB_PREFIX = quran.HIZB_MARK .. quran.NBSP

local function read_text(path)
  local handle, open_error = io.open(path, "rb")
  if not handle then error(("cannot read %s: %s"):format(path, open_error)) end
  local text = handle:read("a")
  handle:close()
  return text
end

local cache = {}

--- Load the Qur'an data from a directory holding hafsData_v18.csv and
--- surah-names.csv. Returns { ayat = {[surah] = {raw_text, ...}}, names = {...} }.
function quran.load(data_directory)
  if cache[data_directory] then return cache[data_directory] end

  local ayat = {}
  for _, record in ipairs(csv.records(read_text(data_directory .. "/hafsData_v18.csv"))) do
    local surah = tonumber(record.sora)
    local ayah = tonumber(record.aya_no)
    ayat[surah] = ayat[surah] or {}
    ayat[surah][ayah] = record.aya_text
  end

  local names = {}
  for _, record in ipairs(csv.records(read_text(data_directory .. "/surah-names.csv"))) do
    names[tonumber(record.number)] = record.name
  end

  local data = { ayat = ayat, names = names }
  cache[data_directory] = data
  return data
end

--- Split one ayah's raw text into { has_hizb_mark, words, number }.
--- Every ayah is: optional "۞" + NBSP, words separated by U+0020, NBSP, Arabic-Indic number.
function quran.tokenize(raw_text)
  local body = raw_text
  local has_hizb_mark = false
  if body:sub(1, #HIZB_PREFIX) == HIZB_PREFIX then
    has_hizb_mark = true
    body = body:sub(#HIZB_PREFIX + 1)
  end
  local words_text, number = body:match("^(.*)" .. quran.NBSP .. "(.-)$")
  if not words_text then words_text, number = body, "" end
  local words = {}
  for word in words_text:gmatch("[^ ]+") do words[#words + 1] = word end
  return { has_hizb_mark = has_hizb_mark, words = words, number = number }
end

--- Reduce Arabic text to its words for a words-only comparison: drops ayah
--- numbers, ellipses, the hizb mark, ornate brackets and whitespace differences.
--- Waqf signs and diacritics stay, because they are part of each word.
local IGNORED_SEQUENCES = { quran.NBSP, "…", "...", quran.HIZB_MARK, "﴿", "﴾" }

local function replace_plain(text, needle, replacement)
  local pieces = {}
  local cursor = 1
  while true do
    local start, stop = text:find(needle, cursor, true)
    if not start then break end
    pieces[#pieces + 1] = text:sub(cursor, start - 1)
    pieces[#pieces + 1] = replacement
    cursor = stop + 1
  end
  pieces[#pieces + 1] = text:sub(cursor)
  return table.concat(pieces)
end

local function is_arabic_indic_number(word)
  for _, codepoint in utf8.codes(word) do
    if codepoint < 0x0660 or codepoint > 0x0669 then return false end
  end
  return true
end

-- Canonical equivalence for Arabic, so text typed in an editor that
-- normalises to NFC still matches the data: decompose the precomposed
-- hamza/madda letters, then order each run of combining marks by its
-- canonical combining class (as Unicode NFD does).
local DECOMPOSITIONS = {
  [0x0622] = { 0x0627, 0x0653 }, [0x0623] = { 0x0627, 0x0654 }, [0x0624] = { 0x0648, 0x0654 },
  [0x0625] = { 0x0627, 0x0655 }, [0x0626] = { 0x064A, 0x0654 }, [0x06C0] = { 0x06D5, 0x0654 },
  [0x06C2] = { 0x06C1, 0x0654 }, [0x06D3] = { 0x06D2, 0x0654 },
}

local COMBINING_CLASSES = {
  [0x0618] = 30, [0x0619] = 31, [0x061A] = 32,
  [0x064B] = 27, [0x064C] = 28, [0x064D] = 29, [0x064E] = 30, [0x064F] = 31, [0x0650] = 32,
  [0x0651] = 33, [0x0652] = 34, [0x0655] = 220, [0x0656] = 220, [0x065C] = 220, [0x065F] = 220,
  [0x0670] = 35, [0x06E3] = 220, [0x06EA] = 220, [0x06ED] = 220,
  [0x08D3] = 220, [0x08E3] = 220, [0x08E6] = 220, [0x08E9] = 220, [0x08ED] = 220, [0x08EE] = 220,
  [0x08EF] = 220, [0x08F0] = 27, [0x08F1] = 28, [0x08F2] = 29, [0x08F6] = 220, [0x08F9] = 220, [0x08FA] = 220,
}

local function combining_class(codepoint)
  local known = COMBINING_CLASSES[codepoint]
  if known then return known end
  local is_mark = (codepoint >= 0x0610 and codepoint <= 0x061A)
    or (codepoint >= 0x064B and codepoint <= 0x065F)
    or (codepoint >= 0x06D6 and codepoint <= 0x06DC)
    or (codepoint >= 0x06DF and codepoint <= 0x06E4)
    or codepoint == 0x06E7 or codepoint == 0x06E8
    or (codepoint >= 0x06EA and codepoint <= 0x06ED)
    or (codepoint >= 0x08D3 and codepoint <= 0x08FF and codepoint ~= 0x08E2)
  return is_mark and 230 or 0
end

function quran.canonical(text)
  local decomposed = {}
  for _, codepoint in utf8.codes(text) do
    local parts = DECOMPOSITIONS[codepoint]
    if parts then
      decomposed[#decomposed + 1] = parts[1]
      decomposed[#decomposed + 1] = parts[2]
    else
      decomposed[#decomposed + 1] = codepoint
    end
  end
  -- Stable insertion sort of each run of non-starters by combining class.
  for index = 2, #decomposed do
    local codepoint = decomposed[index]
    local class = combining_class(codepoint)
    if class > 0 then
      local position = index
      while position > 1 do
        local previous_class = combining_class(decomposed[position - 1])
        if previous_class <= class then break end
        decomposed[position] = decomposed[position - 1]
        position = position - 1
      end
      decomposed[position] = codepoint
    end
  end
  return utf8.char(table.unpack(decomposed))
end

function quran.comparable_words(text)
  local cleaned = text
  for _, sequence in ipairs(IGNORED_SEQUENCES) do
    cleaned = replace_plain(cleaned, sequence, " ")
  end
  local words = {}
  for word in cleaned:gmatch("[^ \t\r\n]+") do
    if not is_arabic_indic_number(word) then words[#words + 1] = quran.canonical(word) end
  end
  return words
end

local function is_arabic_codepoint(codepoint)
  return (codepoint >= 0x0600 and codepoint <= 0x06FF and not (codepoint >= 0x0660 and codepoint <= 0x0669))
    or (codepoint >= 0x0750 and codepoint <= 0x077F)
    or (codepoint >= 0x08A0 and codepoint <= 0x08FF)
    or (codepoint >= 0xFB50 and codepoint <= 0xFDFF)
    or (codepoint >= 0xFE70 and codepoint <= 0xFEFF)
end

local function is_other_letter(codepoint)
  return (codepoint >= 0x41 and codepoint <= 0x5A)
    or (codepoint >= 0x61 and codepoint <= 0x7A)
    or (codepoint >= 0xC0 and codepoint ~= 0xD7 and codepoint ~= 0xF7 and codepoint < 0x0600)
    or (codepoint >= 0x0700 and codepoint < 0x0750)
    or (codepoint >= 0x0780 and codepoint < 0x08A0)
    or (codepoint >= 0x0900 and codepoint < 0x2000)
    or (codepoint >= 0x3000 and codepoint < 0xFB50)
end

--- Which script a piece of text is mostly in: "arabic", "translation"
--- (any other script), or "neutral" (no letters at all).
function quran.script_of(text)
  local arabic_count, other_count = 0, 0
  local valid = pcall(function()
    for _, codepoint in utf8.codes(text) do
      if is_arabic_codepoint(codepoint) then
        arabic_count = arabic_count + 1
      elseif is_other_letter(codepoint) then
        other_count = other_count + 1
      end
    end
  end)
  if not valid then return "translation" end
  if arabic_count == 0 and other_count == 0 then return "neutral" end
  return arabic_count > other_count and "arabic" or "translation"
end

return quran
