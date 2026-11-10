-- The construct filter: validates authoring constructs and turns them into
-- styled output. It never prints and never exits; every problem goes into
-- context.problems so the build can report everything at once.
--
-- Constructs (see docs/authoring-guide.md):
--   [pbuh]{.hon}                         honorific (style picked from context)
--   ::: {.ayah ref="83:26"}              ayah: Arabic fetched from the data
--   ::: hadith / arabic-quote / trans    Arabic paragraph(s), then translation
--   [text]{.note} .c1–.c4 .warn          editorial highlights (draft only)
--   [21:107]{.q}                         inline Qur'an citation
--   ::: signature                        left-ragged author signature

local grammar = require("ayah_grammar")
local quran = require("quran")
local suggest = require("suggest")
local Problems = require("problems")

local construct_filter = {}

---------------------------------------------------------------------------
-- Vocabulary
---------------------------------------------------------------------------

local HONORIFIC_KEYS = {
  "swt", "azwjl", "pbuh", "pbuhs",
  "s-him", "s-her", "s-two", "s-thm",
  "ss-him", "ss-her", "ss-two", "ss-thm",
  "p-him", "p-her", "p-two", "p-thm",
  "m-him", "m-her", "m-two", "m-thm",
  "h-him", "h-her", "h-two", "h-thm",
}

local HONORIFICS = {
  arabic = {
    swt = "سبحانه وتعالى",
    azwjl = "عزَّ وجلَّ",
    pbuh = "صلى الله عليه وسلم",
    pbuhs = "صلى الله عليه وسلم",
    ["s-him"] = "عليه السلام",
    ["s-her"] = "عليها السلام",
    ["s-two"] = "عليهما السلام",
    ["s-thm"] = "عليهم السلام",
    ["ss-him"] = "عليه الصلاة والسلام",
    ["ss-her"] = "عليها الصلاة والسلام",
    ["ss-two"] = "عليهما الصلاة والسلام",
    ["ss-thm"] = "عليهم الصلاة والسلام",
    ["p-him"] = "رضي الله عنه",
    ["p-her"] = "رضي الله عنها",
    ["p-two"] = "رضي الله عنهما",
    ["p-thm"] = "رضي الله عنهم",
    ["m-him"] = "رحمه الله تعالى",
    ["m-her"] = "رحمها الله تعالى",
    ["m-two"] = "رحمهما الله تعالى",
    ["m-thm"] = "رحمهم الله تعالى",
    ["h-him"] = "حفظه الله تعالى",
    ["h-her"] = "حفظها الله تعالى",
    ["h-two"] = "حفظهما الله تعالى",
    ["h-thm"] = "حفظهم الله تعالى",
  },
  english = {
    swt = "(Exalted be He)",
    azwjl = "(Exalted and Glorified be He)",
    pbuh = "(May peace and blessings be on him)",
    pbuhs = "(Peace be on him)",
    ["s-him"] = "(Peace be on him)",
    ["s-her"] = "(Peace be on her)",
    ["s-two"] = "(Peace be on them both)",
    ["s-thm"] = "(Peace be on them)",
    ["ss-him"] = "(Prayers and peace be on him)",
    ["ss-her"] = "(Prayers and peace be on her)",
    ["ss-two"] = "(Prayers and peace be on them both)",
    ["ss-thm"] = "(Prayers and peace be on them)",
    ["p-him"] = "(May Allāh be pleased with him)",
    ["p-her"] = "(May Allāh be pleased with her)",
    ["p-two"] = "(May Allāh be pleased with them both)",
    ["p-thm"] = "(May Allāh be pleased with them)",
    ["m-him"] = "(May Allāh have mercy on him)",
    ["m-her"] = "(May Allāh have mercy on her)",
    ["m-two"] = "(May Allāh have mercy on them both)",
    ["m-thm"] = "(May Allāh have mercy on them)",
    ["h-him"] = "(May Allāh preserve him)",
    ["h-her"] = "(May Allāh preserve her)",
    ["h-two"] = "(May Allāh preserve them both)",
    ["h-thm"] = "(May Allāh preserve them)",
  },
}

-- Word (DOCX/ODT) paragraph/character style names, kept exactly as the
-- previous macros emitted them.
local HONORIFIC_STYLES = {
  header = "Char Header Honorifics",
  body = "Char Body Honorifics",
  footer = "Char Footer Honorifics",
}
local HONORIFIC_HTML_CLASSES = { header = "in-text-honorifics", body = "in-text-honorifics", footer = "in-fn-honorifics" }

local BLOCK_CONSTRUCTS = {
  ayah = {
    arabic_style = "quran-arabic", translation_style = "quran-trans",
    list_arabic_style = "list-quran-arabic", list_translation_style = "list-quran-trans",
    wrapper_class = "quran", attributes = { ref = true, cite = true },
  },
  hadith = {
    arabic_style = "hadith-arabic", translation_style = "hadith-trans",
    list_arabic_style = "list-hadith-arabic", list_translation_style = "list-hadith-trans",
    wrapper_class = "hadith", attributes = {},
  },
  ["arabic-quote"] = {
    arabic_style = "arabic-text", translation_style = "arabic-text-trans",
    wrapper_class = "arabic-quote", attributes = {},
  },
  trans = {
    arabic_style = "Arabic Source", translation_style = "English Target",
    wrapper_class = "trans", attributes = {},
  },
}

local SIGNATURE_STYLE = "left-ragged"

local HIGHLIGHT_STYLES = {
  note = "Highlight C1",
  c1 = "Highlight C1",
  c2 = "Highlight C2",
  c3 = "Highlight C3",
  c4 = "Highlight C4",
  warn = "Highlight Warn",
}

local DIV_CONSTRUCTS = { ayah = true, hadith = true, ["arabic-quote"] = true, trans = true, signature = true }
local SPAN_CONSTRUCTS = { hon = true, q = true, note = true, c1 = true, c2 = true, c3 = true, c4 = true, warn = true }
local BUILTIN_CLASSES = { smallcaps = true, underline = true, mark = true, unnumbered = true, unlisted = true }

local KNOWN_CLASS_NAMES = {}
for name in pairs(DIV_CONSTRUCTS) do KNOWN_CLASS_NAMES[#KNOWN_CLASS_NAMES + 1] = name end
for name in pairs(SPAN_CONSTRUCTS) do KNOWN_CLASS_NAMES[#KNOWN_CLASS_NAMES + 1] = name end
for name in pairs(BUILTIN_CLASSES) do KNOWN_CLASS_NAMES[#KNOWN_CLASS_NAMES + 1] = name end
table.sort(KNOWN_CLASS_NAMES)

-- Old GPP syntax and what replaces it.
local LEGACY_SYNTAX = {
  { "\\hon{", "write [pbuh]{.hon}" },
  { "\\trans{", "write ::: trans with the Arabic paragraph first" },
  { "\\SC{", "write [term]{.smallcaps}" },
  { "\\surahref{", "write [21:107]{.q}" },
  { "\\note{", "write [text]{.note}" },
  { "\\c1{", "write [text]{.c1}" },
  { "\\c2{", "write [text]{.c2}" },
  { "\\c3{", "write [text]{.c3}" },
  { "\\c4{", "write [text]{.c4}" },
  { "\\warn{", "write [text]{.warn}" },
  { "\\NOW", "leave date: out of metadata.yaml and the build fills it in" },
  { "\\LIST_AYAH_", 'write ::: {.ayah ref="83:26"}' },
  { "\\AYAH_", 'write ::: {.ayah ref="83:26"}' },
  { "\\LIST_HADITH_", "write ::: hadith" },
  { "\\HADITH_", "write ::: hadith" },
  { "\\AR_START", "write ::: arabic-quote" },
  { "\\AR_END", "write ::: arabic-quote" },
  { "\\EN_START", "write ::: arabic-quote" },
  { "\\EN_END", "write ::: arabic-quote" },
  { "\\BINT", "write bint in full" },
  { "\\BIN", "write ibn in full" },
}

local RTL_LANGUAGES = {
  ar = true, arc = true, ckb = true, dv = true, fa = true, he = true,
  ku = true, ps = true, sd = true, ug = true, ur = true, yi = true,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function trim(text)
  return (text:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function html_class(style_name)
  return (style_name:lower():gsub("[^%w]+", "-"))
end

local function is_rtl_language(language)
  local primary = (language or ""):match("^(%a+)")
  return primary ~= nil and RTL_LANGUAGES[primary:lower()] == true
end

--- "arabic", "translation", or "neutral" (no letters at all).
local function classify_block(block)
  return quran.script_of(pandoc.utils.stringify(block))
end

local function attributes_list(element)
  local list = {}
  for key, value in pairs(element.attributes) do list[#list + 1] = { key, value } end
  table.sort(list, function(first, second) return first[1] < second[1] end)
  return list
end

local function construct_classes(element, constructs)
  local found = {}
  for _, class in ipairs(element.classes) do
    if constructs[class] then found[#found + 1] = class end
  end
  return found
end

local function append_inlines(blocks, inlines)
  local last_block = blocks[#blocks]
  if last_block and (last_block.t == "Para" or last_block.t == "Plain") then
    last_block.content:insert(pandoc.Space())
    last_block.content:extend(inlines)
  else
    blocks[#blocks + 1] = pandoc.Para(inlines)
  end
end

---------------------------------------------------------------------------
-- The filter
---------------------------------------------------------------------------

--- Apply the construct filter to one document (one source file).
--- context = {
---   file, source,          -- path and text of the source file (for line numbers)
---   format,                -- one of options.FORMATS
---   options,               -- resolved option values (options.resolve)
---   data_directory,        -- utils/quran
---   problems,              -- a Problems collector
--- }
function construct_filter.apply(doc, context)
  local problems = context.problems or Problems.new()
  local locator = Problems.locator(context.file, context.source)
  local option_values = context.options
  local family = (context.format == "docx" or context.format == "odt") and "word" or "html"
  local is_final = option_values.edition == "final"
  local honorific_language = option_values.honorifics == "english" and "english" or "arabic"
  local translation_language = option_values["translation-lang"] or "en"
  local grammar_options = {
    ayah_numbers = option_values["ayah-numbers"],
    citation_style = option_values["quran-citation"],
  }

  local quran_data
  local function data()
    quran_data = quran_data or quran.load(context.data_directory)
    return quran_data
  end

  -- 1. Leftover GPP syntax, found in the source text so lines are exact.
  if context.source then
    local line_number = 0
    for line in (context.source .. "\n"):gmatch("([^\n]*)\n") do
      line_number = line_number + 1
      for _, legacy in ipairs(LEGACY_SYNTAX) do
        local needle, hint = legacy[1], legacy[2]
        if line:find(needle, 1, true) then
          problems:error(locator:at_line(line_number, trim(line)), ("old GPP syntax %s…"):format(needle), hint)
          break
        end
      end
    end
  end

  -- 2. Validate classes and attributes on every Div, Span and Header.
  local function check_element(element, kind)
    if element.attributes["custom-style"] then
      local style = element.attributes["custom-style"]
      problems:error(locator:find({ 'custom-style="' .. style .. '"', "custom-style=" .. style, "custom-style" }),
        ('raw custom-style "%s" in content'):format(style),
        style == SIGNATURE_STYLE and "use ::: signature" or "content names what something is; only the filter knows Word style names")
    end

    local constructs_here = {}
    for _, class in ipairs(element.classes) do
      local needles = { "." .. class, "::: " .. class, class }
      if DIV_CONSTRUCTS[class] or SPAN_CONSTRUCTS[class] then
        constructs_here[#constructs_here + 1] = class
        if kind == "Header" then
          problems:error(locator:find(needles), ('"%s" cannot be used on a heading'):format(class))
        elseif kind == "Span" and DIV_CONSTRUCTS[class] then
          problems:error(locator:find(needles), ('"%s" is a block construct'):format(class),
            class == "ayah" and 'write ::: {.ayah ref="…"} on its own line' or ("write ::: " .. class .. " on its own line"))
        elseif kind == "Div" and SPAN_CONSTRUCTS[class] then
          problems:error(locator:find(needles), ('"%s" is an inline construct'):format(class),
            ("write [text]{.%s} inside a paragraph"):format(class))
        end
      elseif not BUILTIN_CLASSES[class] then
        local near = suggest.near_miss(class, KNOWN_CLASS_NAMES)
        if near then
          problems:error(locator:find(needles), ('unknown class "%s"'):format(class), ('did you mean "%s"?'):format(near))
        else
          problems:warning_once("class:" .. class, locator:find(needles), ('custom class "%s"'):format(class),
            "passed through unchanged; DOCX/ODT ignore it")
        end
      end
    end
    if #constructs_here > 1 then
      problems:error(locator:find("." .. constructs_here[2]),
        ("one element cannot be both %s"):format(table.concat(constructs_here, " and ")))
    end
  end

  doc:walk({
    Div = function(div) check_element(div, "Div") end,
    Span = function(span) check_element(span, "Span") end,
    Header = function(header) check_element(header, "Header") end,
  })

  -- 3. Block constructs. Inside list items they use the list- styles.
  local function render_signature(div)
    for key in pairs(div.attributes) do
      problems:warning(locator:find("::: signature"), ('signature ignores attribute "%s"'):format(key))
    end
    if family == "word" then
      return pandoc.Div(div.content, pandoc.Attr("", {}, { { "custom-style", SIGNATURE_STYLE } }))
    end
    return pandoc.Div(div.content, pandoc.Attr("", { html_class(SIGNATURE_STYLE) }))
  end

  local function render_block_construct(div, name, in_list)
    local spec = BLOCK_CONSTRUCTS[name]
    local ref = div.attributes.ref
    local location = name == "ayah" and ref and locator:find({ 'ref="' .. ref .. '"', "ref=" .. ref, ref })
      or locator:find({ "::: " .. name, "{." .. name, "." .. name })

    for key in pairs(div.attributes) do
      if not spec.attributes[key] then
        problems:warning(location, ('%s ignores attribute "%s"'):format(name, key))
      end
    end

    -- Split the paragraphs into Arabic (first) and translation (after).
    local arabic_blocks, translation_blocks = {}, {}
    local seen_translation = false
    local reported_order = false
    for _, block in ipairs(div.content) do
      local script = classify_block(block)
      if script == "arabic" then
        if seen_translation then
          if not reported_order then
            problems:error(location, ("Arabic after the translation in a %s block"):format(name),
              "put the Arabic paragraph(s) first")
            reported_order = true
          end
          translation_blocks[#translation_blocks + 1] = block
        else
          arabic_blocks[#arabic_blocks + 1] = block
        end
      else
        if script == "translation" then seen_translation = true end
        translation_blocks[#translation_blocks + 1] = block
      end
    end

    if name == "ayah" then
      if not ref or trim(ref) == "" then
        problems:error(location, "ayah block without a ref", 'write ::: {.ayah ref="83:26"}')
        return translation_blocks
      end
      local result = grammar.resolve(ref, data(), grammar_options)
      for _, message in ipairs(result.errors) do problems:error(location, message) end
      if #result.errors > 0 then return translation_blocks end

      if #arabic_blocks > 0 then
        local written = quran.comparable_words(pandoc.utils.stringify(pandoc.Blocks(arabic_blocks)))
        local matches = #written == #result.selected_words
        if matches then
          for word_index, word in ipairs(written) do
            if word ~= quran.canonical(result.selected_words[word_index]) then matches = false break end
          end
        end
        if not matches then
          problems:error(location,
            ("the Arabic written for %s differs from the Qur'an text\n    written: %s\n    data:    %s")
              :format(ref, table.concat(written, " "), table.concat(result.selected_words, " ")),
            "fix it, or run: pandoc lua build.lua resolve --refresh")
        end
      end
      arabic_blocks = { pandoc.Para(pandoc.Inlines(result.arabic)) }

      local cite = div.attributes.cite
      if cite ~= nil and cite ~= "true" and cite ~= "false" then
        problems:error(location, ('cite must be true or false, not "%s"'):format(cite))
      end
      if cite ~= "false" then append_inlines(translation_blocks, pandoc.Inlines(result.citation)) end
    elseif #arabic_blocks == 0 and #translation_blocks == 0 then
      problems:error(location, ("empty %s block"):format(name))
      return {}
    end

    if name == "trans" and is_final then
      if #translation_blocks == 0 then
        problems:warning(location, "translation pair without a translation is dropped from the final edition")
      end
      return translation_blocks
    end

    local arabic_style = in_list and spec.list_arabic_style or spec.arabic_style
    local translation_style = in_list and spec.list_translation_style or spec.translation_style
    local translation_attributes = { { "lang", translation_language } }
    if is_rtl_language(translation_language) then translation_attributes[#translation_attributes + 1] = { "dir", "rtl" } end

    local output = {}
    if family == "word" then
      if #arabic_blocks > 0 then
        output[#output + 1] = pandoc.Div(arabic_blocks,
          pandoc.Attr("", {}, { { "custom-style", arabic_style }, { "lang", "ar" }, { "dir", "rtl" } }))
      end
      if #translation_blocks > 0 then
        local attributes = { { "custom-style", translation_style } }
        for _, attribute in ipairs(translation_attributes) do attributes[#attributes + 1] = attribute end
        output[#output + 1] = pandoc.Div(translation_blocks, pandoc.Attr("", {}, attributes))
      end
      return output
    end

    if #arabic_blocks > 0 then
      output[#output + 1] = pandoc.Div(arabic_blocks,
        pandoc.Attr("", { html_class(arabic_style) }, { { "lang", "ar" }, { "dir", "rtl" } }))
    end
    if #translation_blocks > 0 then
      output[#output + 1] = pandoc.Div(translation_blocks,
        pandoc.Attr("", { html_class(translation_style) }, translation_attributes))
    end
    return pandoc.Div(output, pandoc.Attr(div.identifier, { spec.wrapper_class }))
  end

  local function block_renderer(in_list)
    return function(div)
      local found = construct_classes(div, DIV_CONSTRUCTS)
      local name = found[1]
      if not name then return nil end
      if name == "signature" then return render_signature(div) end
      return render_block_construct(div, name, in_list)
    end
  end

  local function render_in_list(list)
    return list:walk({ Div = block_renderer(true) })
  end

  doc = doc:walk({ BulletList = render_in_list, OrderedList = render_in_list })
  doc = doc:walk({ Div = block_renderer(false) })

  -- 4. Honorifics: heading, footnote, then body.
  local function honorific_renderer(placement)
    return function(span)
      if not span.classes:includes("hon") then return nil end
      local key = trim(pandoc.utils.stringify(span.content)):lower()
      local location = locator:find({ "[" .. pandoc.utils.stringify(span.content) .. "]{.hon", "{.hon" })
      for attribute_key in pairs(span.attributes) do
        problems:error(location, ('honorifics take no attributes (found "%s")'):format(attribute_key),
          "the language comes from the honorifics option")
      end
      local phrase = HONORIFICS[honorific_language][key]
      if not phrase then
        local near = suggest.closest(key, HONORIFIC_KEYS)
        problems:error(location, ('unknown honorific "%s"'):format(key),
          near and suggest.distance(key, near) <= 3 and ('did you mean "%s"?'):format(near)
            or ("known: " .. table.concat(HONORIFIC_KEYS, ", ")))
        return span.content
      end
      local is_arabic = honorific_language == "arabic"
      local attributes = {}
      if family == "word" then attributes[#attributes + 1] = { "custom-style", HONORIFIC_STYLES[placement] } end
      if is_arabic then
        attributes[#attributes + 1] = { "lang", "ar" }
        attributes[#attributes + 1] = { "dir", "rtl" }
      end
      local classes = family == "html" and { HONORIFIC_HTML_CLASSES[placement] } or {}
      return pandoc.Span(pandoc.Inlines(phrase), pandoc.Attr("", classes, attributes))
    end
  end

  doc = doc:walk({ Header = function(header) return header:walk({ Span = honorific_renderer("header") }) end })
  doc = doc:walk({ Note = function(note) return note:walk({ Span = honorific_renderer("footer") }) end })
  doc = doc:walk({ Span = honorific_renderer("body") })

  -- 5. Inline citations and highlights.
  doc = doc:walk({
    Span = function(span)
      local found = construct_classes(span, SPAN_CONSTRUCTS)
      local name = found[1]
      if not name then return nil end

      if name == "q" then
        local reference = trim(pandoc.utils.stringify(span.content))
        local location = locator:find({ "[" .. reference .. "]{.q", "{.q" })
        local result = grammar.resolve(reference, data(), grammar_options)
        for _, message in ipairs(result.errors) do problems:error(location, message) end
        if #result.errors > 0 then return span.content end
        return pandoc.Inlines(result.citation)
      end

      local style = HIGHLIGHT_STYLES[name]
      if not style then return nil end
      local location = locator:find({ "{." .. name .. "}", "{." .. name })
      if is_final then
        problems:error(location, ('leftover %s in a final edition'):format(name == "note" and "note" or ("highlight ." .. name)),
          "resolve it and remove the mark")
      end
      local content = span.content
      if name == "note" then
        content = pandoc.Inlines({ pandoc.Str("NOTE:"), pandoc.Space() }) .. content
      end
      if family == "word" then
        return pandoc.Span(content, pandoc.Attr("", {}, { { "custom-style", style } }))
      end
      return pandoc.Span(content, pandoc.Attr("", { html_class(style), name }))
    end,
  })

  return doc
end

construct_filter.HONORIFIC_KEYS = HONORIFIC_KEYS
construct_filter.HONORIFICS = HONORIFICS
construct_filter.attributes_list = attributes_list

return construct_filter
