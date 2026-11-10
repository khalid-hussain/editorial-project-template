-- Minimal RFC 4180 CSV parser: quoted fields, doubled quotes, embedded commas
-- and newlines, CRLF or LF line endings. Pure Lua, no dependencies.

local csv = {}

--- Parse CSV text into a list of rows, each row a list of field strings.
function csv.parse(text)
  text = text:gsub("\r\n", "\n")
  if text:sub(1, 3) == "\239\187\191" then text = text:sub(4) end -- UTF-8 BOM

  local rows = {}
  local row = {}
  local position = 1
  local length = #text

  while position <= length do
    local field
    if text:sub(position, position) == '"' then
      local pieces = {}
      local cursor = position + 1
      while true do
        local quote = text:find('"', cursor, true)
        if not quote then
          error(("CSV: unterminated quoted field starting at byte %d"):format(position))
        end
        pieces[#pieces + 1] = text:sub(cursor, quote - 1)
        if text:sub(quote + 1, quote + 1) == '"' then
          pieces[#pieces + 1] = '"'
          cursor = quote + 2
        else
          cursor = quote + 1
          break
        end
      end
      field = table.concat(pieces)
      position = cursor
    else
      local stop = text:find("[,\n]", position) or (length + 1)
      field = text:sub(position, stop - 1)
      position = stop
    end

    row[#row + 1] = field
    local delimiter = text:sub(position, position)
    if delimiter == "," then
      position = position + 1
      if position > length then row[#row + 1] = "" end
    elseif delimiter == "\n" or delimiter == "" then
      rows[#rows + 1] = row
      row = {}
      position = position + 1
    else
      error(("CSV: unexpected character after quoted field at byte %d"):format(position))
    end
  end

  if #row > 0 then rows[#rows + 1] = row end
  return rows
end

--- Parse CSV text with a header row into a list of records keyed by column name.
function csv.records(text)
  local rows = csv.parse(text)
  local header = table.remove(rows, 1) or {}
  local records = {}
  for _, row in ipairs(rows) do
    local record = {}
    for column_index, column_name in ipairs(header) do
      record[column_name] = row[column_index]
    end
    records[#records + 1] = record
  end
  return records
end

return csv
