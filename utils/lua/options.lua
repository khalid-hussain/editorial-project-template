-- Edition options: the `template:` block of metadata.yaml, per-format
-- sections, and command-line overrides.
--
-- Precedence: command line > format section > book-wide value > default.

local suggest = require("suggest")

local options = {}

options.FORMATS = { "docx", "odt", "icml", "epub", "chunkedhtml", "html5" }

options.ORDER = { "edition", "honorifics", "quran-citation", "ayah-numbers", "translation-lang", "timestamp" }

options.CHOICES = {
  edition = { "draft", "final" },
  honorifics = { "arabic", "english" },
  ["quran-citation"] = { "short", "long" },
  ["ayah-numbers"] = { "always", "ended", "never" },
  timestamp = { "false", "true" },
}

options.DEFAULTS = {
  edition = "draft",
  honorifics = "arabic",
  ["quran-citation"] = "short",
  ["ayah-numbers"] = "always",
  timestamp = "false",
}

local DESCRIPTIONS = {
  edition = "draft for translators and editors; final drops Arabic source text and fails on leftover marks",
  honorifics = "language of honorifics",
  ["quran-citation"] = "short (Q21:107) or long (al-Anbiyāʾ, Q21:107)",
  ["ayah-numbers"] = "after every quoted ayah, only where an ayah ends, or never",
  ["translation-lang"] = "language of translation blocks; defaults to the book's lang",
  timestamp = "put the build date and time in output file names (otherwise each build overwrites the last)",
}
options.DESCRIPTIONS = DESCRIPTIONS

local function is_format(name)
  for _, format in ipairs(options.FORMATS) do
    if format == name then return true end
  end
  return false
end

local function is_option(name)
  for _, option_name in ipairs(options.ORDER) do
    if option_name == name then return true end
  end
  return false
end

local function all_names()
  local names = {}
  for _, option_name in ipairs(options.ORDER) do names[#names + 1] = option_name end
  for _, format in ipairs(options.FORMATS) do names[#names + 1] = format end
  return names
end

--- Map a pandoc writer name (FORMAT) to one of options.FORMATS.
function options.format_name(writer_name)
  writer_name = (writer_name or ""):lower()
  if writer_name == "epub" or writer_name == "epub3" or writer_name == "epub2" then return "epub" end
  if writer_name == "html" or writer_name == "html5" or writer_name == "html4" then return "html5" end
  if is_format(writer_name) then return writer_name end
  return nil
end

--- "word" for formats styled through custom-style, "html" otherwise.
function options.family(format)
  if format == "docx" or format == "odt" or format == "icml" then return "word" end
  return "html"
end

--- Convert a pandoc MetaValue into plain Lua strings and tables.
function options.plain(value)
  if value == nil then return nil end
  local value_type = pandoc.utils.type(value)
  if value_type == "string" or value_type == "boolean" or value_type == "number" then
    return tostring(value)
  end
  if value_type == "Inlines" or value_type == "Blocks" or value_type == "Inline" or value_type == "Block" then
    return pandoc.utils.stringify(value)
  end
  if value_type == "List" then
    local list = {}
    for item_index, item in ipairs(value) do list[item_index] = options.plain(item) end
    return list
  end
  if type(value) == "table" then
    local map = {}
    for key, item in pairs(value) do map[key] = options.plain(item) end
    return map
  end
  return pandoc.utils.stringify(value)
end

local function validate_value(name, value, origin, errors)
  if name == "translation-lang" then
    if type(value) ~= "string" or not value:match("^%a%a%a?$") and not value:match("^%a%a%a?%-[%w%-]+$") then
      errors[#errors + 1] = {
        message = ('%s: translation-lang "%s" is not a language code'):format(origin, tostring(value)),
        hint = "e.g. en, en-US, fr, ur",
      }
      return false
    end
    return true
  end
  local choices = options.CHOICES[name]
  for _, choice in ipairs(choices) do
    if choice == value then return true end
  end
  local closest = suggest.closest(tostring(value), choices)
  errors[#errors + 1] = {
    message = ('%s: %s cannot be "%s"'):format(origin, name, tostring(value)),
    hint = ("use one of: %s; did you mean %q?"):format(table.concat(choices, ", "), closest),
  }
  return false
end

local function unknown_name_error(name, origin, errors)
  local closest, distance = suggest.closest(name, all_names())
  errors[#errors + 1] = {
    message = ('%s: unknown option "%s"'):format(origin, name),
    hint = distance and distance <= 3 and ("did you mean %q?"):format(closest)
      or ("options are: " .. table.concat(options.ORDER, ", ")),
  }
end

--- Validate the whole template block. Returns a list of { message, hint }.
function options.validate(template_block, overrides)
  local errors = {}
  template_block = template_block or {}
  if type(template_block) ~= "table" then
    errors[#errors + 1] = { message = "metadata.yaml: `template:` must be a map of options" }
    return errors
  end
  for name, value in pairs(template_block) do
    if is_format(name) then
      if type(value) ~= "table" then
        errors[#errors + 1] = { message = ("metadata.yaml: template.%s must be a map of options"):format(name) }
      else
        for section_name, section_value in pairs(value) do
          if is_option(section_name) then
            validate_value(section_name, section_value, "metadata.yaml template." .. name, errors)
          else
            unknown_name_error(section_name, "metadata.yaml template." .. name, errors)
          end
        end
      end
    elseif is_option(name) then
      validate_value(name, value, "metadata.yaml template", errors)
    else
      unknown_name_error(name, "metadata.yaml template", errors)
    end
  end
  for name, value in pairs(overrides or {}) do
    if is_option(name) then
      validate_value(name, value, "command line", errors)
    else
      unknown_name_error(name, "command line", errors)
    end
  end
  return errors
end

--- Resolve options for one format. Returns values, origins.
function options.resolve(template_block, format, overrides, book_lang)
  template_block = type(template_block) == "table" and template_block or {}
  overrides = overrides or {}
  local section = format and type(template_block[format]) == "table" and template_block[format] or {}
  local values, origins = {}, {}
  for _, name in ipairs(options.ORDER) do
    if overrides[name] ~= nil then
      values[name], origins[name] = overrides[name], "command line"
    elseif section[name] ~= nil then
      values[name], origins[name] = section[name], "metadata.yaml template." .. format
    elseif template_block[name] ~= nil and type(template_block[name]) ~= "table" then
      values[name], origins[name] = template_block[name], "metadata.yaml template"
    elseif name == "translation-lang" then
      values[name], origins[name] = book_lang or "en", book_lang and "metadata.yaml lang" or "default"
    else
      values[name], origins[name] = options.DEFAULTS[name], "default"
    end
  end
  return values, origins
end

return options
