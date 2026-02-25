local auto_mermaid_id = 0

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function sanitize_mermaid_label_markup(code)
  -- Word SVG rendering drops HTML label content in several cases; keep plain text.
  local text = code
  text = text:gsub("</?i>", "")
  text = text:gsub("</?em>", "")
  text = text:gsub("</?b>", "")
  text = text:gsub("</?strong>", "")
  return text
end

local function has_mermaid_class(code_block)
  for _, class_name in ipairs(code_block.classes) do
    if class_name == "mermaid" then
      return true
    end
  end
  return false
end

local function normalize_mermaid_id(identifier)
  if identifier == nil or identifier == "" then
    auto_mermaid_id = auto_mermaid_id + 1
    return "fig:mermaid-" .. tostring(auto_mermaid_id)
  end
  if identifier:match("^fig:") then
    return identifier
  end
  return "fig:" .. identifier
end

local function split_caption_and_inline_id(caption)
  local raw_caption = trim(caption or "")
  if raw_caption == "" then
    return nil, nil
  end

  local cap, parsed_id = raw_caption:match("^(.-)%s+#(fig:[^%s]+)%s*$")
  if cap and parsed_id then
    cap = trim(cap)
    if cap ~= "" then
      return cap, parsed_id
    end
  end

  return raw_caption, nil
end

local function extract_caption_from_para(block)
  if not block or block.t ~= "Para" then
    return nil
  end

  local text = pandoc.utils.stringify(block)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  local caption = text:match("^[Ff]igur%s*%d*%s*:%s*(.+)$")
  if caption and caption ~= "" then
    return caption
  end

  caption = text:match("^[Ff]igure%s*%d*%s*:%s*(.+)$")
  if caption and caption ~= "" then
    return caption
  end

  return nil
end

function Pandoc(doc)
  local out = {}
  local i = 1

  while i <= #doc.blocks do
    local block = doc.blocks[i]
    if block.t == "CodeBlock" and has_mermaid_class(block) then
      block.text = sanitize_mermaid_label_markup(block.text)
      local inline_caption, inline_id = split_caption_and_inline_id(block.attributes.caption)
      local remove_next_block = false
      local caption = inline_caption

      if caption == nil then
        caption = extract_caption_from_para(doc.blocks[i + 1])
        if caption ~= nil then
          remove_next_block = true
        end
      end

      if inline_id ~= nil and (block.identifier == nil or block.identifier == "") then
        block.identifier = inline_id
      end

      if caption ~= nil then
        block.attributes.caption = caption
        block.identifier = normalize_mermaid_id(block.identifier)
      end

      table.insert(out, block)
      if remove_next_block then
        i = i + 2
      else
        i = i + 1
      end
    else
      table.insert(out, block)
      i = i + 1
    end
  end

  doc.blocks = out
  return doc
end
