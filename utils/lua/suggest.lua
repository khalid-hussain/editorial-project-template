-- "Did you mean …?" helpers: edit distance and near-miss detection.

local suggest = {}

local function utf8_characters(text)
  local characters = {}
  for _, codepoint in utf8.codes(text) do characters[#characters + 1] = codepoint end
  return characters
end

--- Levenshtein distance between two UTF-8 strings.
function suggest.distance(first_text, second_text)
  local first = utf8_characters(first_text)
  local second = utf8_characters(second_text)
  local previous_row = {}
  for column = 0, #second do previous_row[column] = column end
  for row = 1, #first do
    local current_row = { [0] = row }
    for column = 1, #second do
      local substitution_cost = first[row] == second[column] and 0 or 1
      current_row[column] = math.min(
        previous_row[column] + 1,
        current_row[column - 1] + 1,
        previous_row[column - 1] + substitution_cost
      )
    end
    previous_row = current_row
  end
  return previous_row[#second]
end

--- Normalise a name for near-miss comparison: lower case, no "-" or "_",
--- no trailing "s".
function suggest.normalise(name)
  local normalised = name:lower():gsub("[-_]", "")
  if #normalised > 3 then normalised = normalised:gsub("s$", "") end
  return normalised
end

--- Edits allowed before a name stops counting as a typo of a candidate.
--- Up to 2, but fewer for short names so that unrelated short classes
--- (e.g. "en", "rtl") are not mistaken for "q" or "hon".
local function allowed_edits(candidate)
  local length = utf8.len(candidate) or #candidate
  if length <= 2 then return 0 end
  if length <= 5 then return 1 end
  return 2
end

--- Closest candidate (by edit distance) or nil.
function suggest.closest(name, candidates)
  local best_candidate, best_distance
  for _, candidate in ipairs(candidates) do
    local distance = suggest.distance(name, candidate)
    if not best_distance or distance < best_distance then
      best_candidate, best_distance = candidate, distance
    end
  end
  return best_candidate, best_distance
end

--- The candidate that name is a near miss of, or nil. An exact match is not
--- a near miss.
function suggest.near_miss(name, candidates)
  if name == "" then return nil end
  local normalised_name = suggest.normalise(name)
  for _, candidate in ipairs(candidates) do
    if name == candidate then return nil end
  end
  local best_candidate, best_distance
  for _, candidate in ipairs(candidates) do
    local distance = suggest.distance(normalised_name, suggest.normalise(candidate))
    if distance <= allowed_edits(candidate) and (not best_distance or distance < best_distance) then
      best_candidate, best_distance = candidate, distance
    end
  end
  return best_candidate
end

return suggest
