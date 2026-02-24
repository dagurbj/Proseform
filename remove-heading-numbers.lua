-- File: remove-heading-numbers.lua

-- Recursive function to find and clean the first string in a list of elements
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

function Header (header)
  -- Start the recursive process on the header's content
  remove_leading_number(header.content)
  return header
end
