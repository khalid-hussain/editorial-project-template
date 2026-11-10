-- Problem collector. Nothing here prints or exits: the build decides how and
-- when problems are reported.
--
-- A problem is { file, line, severity = "error"|"warning", message, hint, snippet }.

local Problems = {}
Problems.__index = Problems

function Problems.new()
  return setmetatable({ items = {}, warned_once = {} }, Problems)
end

function Problems:add(problem)
  self.items[#self.items + 1] = problem
  return problem
end

function Problems:error(location, message, hint)
  return self:add({
    file = location and location.file, line = location and location.line,
    snippet = location and location.snippet, severity = "error", message = message, hint = hint,
  })
end

function Problems:warning(location, message, hint)
  return self:add({
    file = location and location.file, line = location and location.line,
    snippet = location and location.snippet, severity = "warning", message = message, hint = hint,
  })
end

--- Record a warning only the first time key is seen; later calls bump its count.
function Problems:warning_once(key, location, message, hint)
  local existing = self.warned_once[key]
  if existing then
    existing.uses = existing.uses + 1
    return existing
  end
  local problem = self:warning(location, message, hint)
  problem.uses = 1
  self.warned_once[key] = problem
  return problem
end

function Problems:extend(other_items)
  for _, problem in ipairs(other_items) do self:add(problem) end
end

function Problems:count(severity)
  local total = 0
  for _, problem in ipairs(self.items) do
    if problem.severity == severity then total = total + 1 end
  end
  return total
end

--- Turn every warning into an error (final editions and --strict).
function Problems:promote_warnings()
  for _, problem in ipairs(self.items) do
    if problem.severity == "warning" then
      problem.severity = "error"
      problem.promoted = true
    end
  end
end

--- Format one problem as a compiler-style line (plus an optional quote).
function Problems.format(problem)
  local location = problem.file or "(unknown file)"
  if problem.line then location = location .. ":" .. problem.line end
  local message = problem.message
  if problem.uses and problem.uses > 1 then message = message .. (" (%d uses)"):format(problem.uses) end
  if problem.hint then message = message .. " (" .. problem.hint .. ")" end
  if problem.promoted then message = message .. " [warning treated as error]" end
  local text = ("%s: %s: %s"):format(location, problem.severity, message)
  if not problem.line and problem.snippet then
    text = text .. "\n    near: " .. problem.snippet
  end
  return text
end

---------------------------------------------------------------------------
-- Source locator: finds the line of a construct by searching the source
-- text, because the markdown reader keeps no positions.
---------------------------------------------------------------------------

local Locator = {}
Locator.__index = Locator

function Problems.locator(file, source_text)
  local line_starts = { 1 }
  if source_text then
    for position in source_text:gmatch("()\n") do line_starts[#line_starts + 1] = position + 1 end
  end
  return setmetatable({ file = file, source = source_text, line_starts = line_starts, cursors = {} }, Locator)
end

function Locator:line_of(byte_position)
  local low, high = 1, #self.line_starts
  while low < high do
    local middle = (low + high + 1) // 2
    if self.line_starts[middle] <= byte_position then low = middle else high = middle - 1 end
  end
  return low
end

--- Locate the next occurrence of any of the needles (plain text). Repeated
--- lookups of the same needle move forward, so identical constructs map to
--- successive lines. Returns { file, line, snippet }.
function Locator:find(needles, snippet)
  if type(needles) == "string" then needles = { needles } end
  if self.source then
    for _, needle in ipairs(needles) do
      if needle and needle ~= "" then
        local cursor = self.cursors[needle] or 1
        local position = self.source:find(needle, cursor, true)
        if not position and cursor > 1 then position = self.source:find(needle, 1, true) end
        if position then
          self.cursors[needle] = position + #needle
          return { file = self.file, line = self:line_of(position), snippet = snippet }
        end
      end
    end
  end
  return { file = self.file, snippet = snippet or needles[1] }
end

--- Location of the first line (1-based) without searching.
function Locator:at_line(line, snippet)
  return { file = self.file, line = line, snippet = snippet }
end

return Problems
