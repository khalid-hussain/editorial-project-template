-- `resolve`, `resolve --refresh` and `unresolve`: write ayah Arabic into the
-- source for review, or take it out again. Edits are made on the text,
-- line by line; Pandoc's writer is never used, so every other byte of the
-- file stays as the author wrote it.

local grammar = require("ayah_grammar")
local quran = require("quran")

local resolve = {}

local function split_lines(text)
  local newline = text:find("\r\n", 1, true) and "\r\n" or "\n"
  local normalised = text:gsub("\r\n", "\n")
  local lines = {}
  for line in (normalised .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
  local had_final_newline = normalised:sub(-1) == "\n"
  if had_final_newline then table.remove(lines) end
  return lines, newline, had_final_newline
end

local function is_blank(line)
  return line:match("^[ \t]*$") ~= nil
end

local function is_closing_fence(line)
  return line:match("^[ \t]*:::+[ \t]*$") ~= nil
end

local function is_opening_fence(line)
  return line:match("^[ \t]*:::+[ \t]*[^ \t:]") ~= nil
end

--- Parse an opening fence line of an ayah div. Returns indent, ref (ref may be nil).
local function parse_ayah_fence(line)
  local indent, attributes = line:match("^([ \t]*):::+[ \t]*{(.-)}[ \t]*$")
  if not attributes then return nil end
  if not (" " .. attributes .. " "):find("[ \t]%.ayah[ \t]") then return nil end
  local ref = attributes:match('ref="([^"]*)"') or attributes:match("ref='([^']*)'")
    or attributes:match("ref=([^ \t}]+)")
  return indent, ref
end

local function words_match(text, expected_words)
  local written = quran.comparable_words(text)
  if #written ~= #expected_words then return false end
  for word_index, word in ipairs(written) do
    if word ~= quran.canonical(expected_words[word_index]) then return false end
  end
  return true
end

--- Process one file's text.
--- mode: "resolve" | "refresh" | "unresolve"
--- Returns new_text (or nil if unchanged), changes, problems.
---   changes:  { { line, action, ref } }
---   problems: { { line, message, hint } }
function resolve.process(text, data, grammar_options, mode)
  local lines, newline, had_final_newline = split_lines(text)
  local changes, problems = {}, {}
  local output = {}
  local line_index = 1

  while line_index <= #lines do
    local line = lines[line_index]
    local indent, ref = parse_ayah_fence(line)
    output[#output + 1] = line
    if not indent then
      line_index = line_index + 1
    else
      local fence_line = line_index
      -- Find the end of this div, counting nested fences.
      local depth = 0
      local end_index = #lines + 1
      for scan_index = line_index + 1, #lines do
        local scanned = lines[scan_index]
        if is_closing_fence(scanned) then
          if depth == 0 then end_index = scan_index break end
          depth = depth - 1
        elseif is_opening_fence(scanned) then
          depth = depth + 1
        end
      end

      -- The first paragraph inside the div, if it is Arabic.
      local paragraph_start = line_index + 1
      while paragraph_start < end_index and is_blank(lines[paragraph_start]) do paragraph_start = paragraph_start + 1 end
      local paragraph_end = paragraph_start - 1
      while paragraph_end + 1 < end_index and not is_blank(lines[paragraph_end + 1])
        and not is_opening_fence(lines[paragraph_end + 1]) do
        paragraph_end = paragraph_end + 1
      end
      local existing_text
      if paragraph_end >= paragraph_start then
        local paragraph_lines = {}
        for index = paragraph_start, paragraph_end do paragraph_lines[#paragraph_lines + 1] = lines[index] end
        local candidate = table.concat(paragraph_lines, " ")
        if quran.script_of(candidate) == "arabic" then existing_text = candidate end
      end

      local result = ref and grammar.resolve(ref, data, grammar_options) or { errors = { "ayah block without a ref" } }
      local next_index = line_index + 1

      if #result.errors > 0 then
        for _, message in ipairs(result.errors) do
          problems[#problems + 1] = { line = fence_line, message = message }
        end
      elseif mode == "unresolve" then
        if existing_text then
          if words_match(existing_text, result.selected_words) then
            -- Drop the Arabic paragraph and the blank line after it.
            for index = line_index + 1, paragraph_start - 1 do output[#output + 1] = lines[index] end
            next_index = paragraph_end + 1
            if next_index < end_index and is_blank(lines[next_index]) then next_index = next_index + 1 end
            changes[#changes + 1] = { line = fence_line, action = "removed", ref = ref }
          else
            problems[#problems + 1] = {
              line = paragraph_start, message = ("the Arabic written for %s differs from the Qur'an text; left in place"):format(ref),
              hint = "fix it, or run: pandoc lua build.lua resolve --refresh",
            }
          end
        end
      elseif not existing_text then
        output[#output + 1] = indent .. result.arabic
        if paragraph_end >= paragraph_start or paragraph_start < end_index then output[#output + 1] = "" end
        changes[#changes + 1] = { line = fence_line, action = "inserted", ref = ref }
      elseif not words_match(existing_text, result.selected_words) then
        if mode == "refresh" then
          for index = line_index + 1, paragraph_start - 1 do output[#output + 1] = lines[index] end
          output[#output + 1] = indent .. result.arabic
          next_index = paragraph_end + 1
          changes[#changes + 1] = { line = fence_line, action = "replaced", ref = ref }
        else
          problems[#problems + 1] = {
            line = paragraph_start, message = ("the Arabic written for %s differs from the Qur'an text"):format(ref),
            hint = "fix it, or run: pandoc lua build.lua resolve --refresh",
          }
        end
      end
      line_index = next_index
    end
  end

  if #changes == 0 then return nil, changes, problems end
  local new_text = table.concat(output, newline)
  if had_final_newline then new_text = new_text .. newline end
  return new_text, changes, problems
end

return resolve
