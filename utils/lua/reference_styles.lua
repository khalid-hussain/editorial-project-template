-- Style names defined in a reference document (template.docx / template.odt),
-- so the build can warn about custom styles the template does not define.

local reference_styles = {}

local function read_bytes(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local bytes = handle:read("a")
  handle:close()
  return bytes
end

local function entry_contents(archive, entry_path)
  for _, entry in ipairs(archive.entries) do
    if entry.path == entry_path then return entry:contents() end
  end
  return nil
end

local function decode_odt_name(name)
  -- ODF encodes characters in style names as _XX_ hex, e.g. "Body_20_Text".
  return (name:gsub("_(%x%x)_", function(hex) return string.char(tonumber(hex, 16)) end))
end

--- Set of style names in a .docx or .odt file, or nil if it can't be read.
function reference_styles.load(path)
  local bytes = path and read_bytes(path)
  if not bytes then return nil end
  local ok, archive = pcall(pandoc.zip.Archive, bytes)
  if not ok then return nil end

  local names = {}
  local docx_styles = entry_contents(archive, "word/styles.xml")
  if docx_styles then
    for name in docx_styles:gmatch('<w:name w:val="([^"]+)"') do names[name] = true end
    return names
  end
  for _, entry_path in ipairs({ "styles.xml", "content.xml" }) do
    local odt_styles = entry_contents(archive, entry_path)
    if odt_styles then
      for name in odt_styles:gmatch('style:name="([^"]+)"') do names[decode_odt_name(name)] = true end
      for name in odt_styles:gmatch('style:display%-name="([^"]+)"') do names[name] = true end
    end
  end
  return names
end

return reference_styles
