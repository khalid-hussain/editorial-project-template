-- Standalone entry point for the construct filter, for use without the build:
--
--   pandoc content/mainmatter/01-lineage.md --lua-filter utils/lua/constructs.lua -t docx -o out.docx
--
-- The build (build.lua) uses construct_filter.lua directly. Here, problems are
-- printed to stderr and any error stops pandoc.

local script_directory = (PANDOC_SCRIPT_FILE or "."):match("^(.*)[/\\]") or "."
package.path = script_directory .. "/?.lua;" .. package.path

local construct_filter = require("construct_filter")
local options = require("options")
local Problems = require("problems")

local function read_source(path)
  local handle = path and io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("a"):gsub("\r\n", "\n")
  handle:close()
  return text
end

return {
  {
    Pandoc = function(doc)
      local input_files = PANDOC_STATE.input_files or {}
      local file = input_files[1] or "stdin"
      local format = options.format_name(FORMAT) or "html5"
      local template_block = options.plain(doc.meta.template) or {}
      local book_lang = doc.meta.lang and pandoc.utils.stringify(doc.meta.lang) or nil
      local problems = Problems.new()

      for _, config_error in ipairs(options.validate(template_block, {})) do
        problems:add({ file = "metadata", severity = "error", message = config_error.message, hint = config_error.hint })
      end
      local option_values = options.resolve(template_block, format, {}, book_lang)

      doc = construct_filter.apply(doc, {
        file = file,
        source = #input_files == 1 and read_source(file) or nil,
        format = format,
        options = option_values,
        data_directory = script_directory .. "/../quran",
        problems = problems,
      })

      if option_values.edition == "final" then problems:promote_warnings() end
      for _, problem in ipairs(problems.items) do io.stderr:write(Problems.format(problem), "\n") end
      local error_count = problems:count("error")
      if error_count > 0 then
        error(("%d error(s) in %s"):format(error_count, file), 0)
      end
      doc.meta.template = nil
      return doc
    end,
  },
}
