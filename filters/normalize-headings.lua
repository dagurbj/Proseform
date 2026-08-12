-- File: normalize-headings.lua
-- Removes leading heading numbers and normalizes heading levels so the
-- shallowest heading in the document becomes level 1.

local min_heading_level = math.huge

-- Recursive function to find and clean the first string in a list of elements.
local function remove_leading_number(inlines)
  -- Stop if list is empty
  if not inlines or #inlines == 0 then return end

  local first = inlines[1]

  -- CASE A: We found the actual text string
  if first.t == "Str" then
    local original_text = first.text
    
    -- Regex: Start with digits, optional dots/digits, optional space
    local new_text = original_text:gsub("^%d+[%d%.]*%s*", "")

    if new_text ~= original_text then
      if new_text == "" then
        -- 1. Remove the number element entirely
        table.remove(inlines, 1)
        
        -- 2. Clean up the immediate following space (e.g. "**7.** Title")
        if inlines[1] and inlines[1].t == "Space" then
          table.remove(inlines, 1)
        end
      else
        -- 3. Just update the text (e.g. "**7.Title**")
        first.text = new_text
      end
    end

  -- CASE B: The first element is a container (Strong, Emph, Span, etc.)
  -- We recurse deeper into its content.
  elseif first.content then
    remove_leading_number(first.content)
  end
end

-- First pass: record the shallowest heading level in the document.
local function record_heading_level(header)
  if header.level < min_heading_level then
    min_heading_level = header.level
  end
  return header
end

-- Second pass: strip leading numbers and shift heading levels.
local function normalize_heading(header, shift)
  remove_leading_number(header.content)

  if shift > 0 then
    header.level = math.max(1, header.level - shift)
  end

  return header
end

local function walk_blocks(blocks, filter)
  local wrapped = pandoc.walk_block(pandoc.Div(blocks), filter)
  return wrapped.content
end

function Pandoc(doc)
  min_heading_level = math.huge
  walk_blocks(doc.blocks, { Header = record_heading_level })

  local shift = 0
  if min_heading_level ~= math.huge then
    shift = min_heading_level - 1
  end

  doc.blocks = walk_blocks(doc.blocks, {
    Header = function(header)
      return normalize_heading(header, shift)
    end,
  })

  return doc
end
