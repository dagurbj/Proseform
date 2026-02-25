local function is_mermaid_image_para(para)
  if #para.content ~= 1 then
    return false
  end

  local item = para.content[1]
  if item.t ~= "Image" then
    return false
  end

  if item.title ~= "fig:" then
    return false
  end

  if item.identifier == nil or item.identifier == "" then
    return false
  end

  if not item.identifier:match("^fig:") then
    return false
  end

  return true
end

function Para(para)
  if not is_mermaid_image_para(para) then
    return nil
  end

  local image = para.content[1]
  local figure = pandoc.read("![tmp](/tmp/placeholder.svg){#fig:tmp}", "markdown").blocks[1]
  figure.identifier = image.identifier
  figure.caption.long = { pandoc.Plain(image.caption) }
  figure.caption.short = nil

  local inner_image = figure.content[1].content[1]
  inner_image.src = image.src
  inner_image.title = image.title
  inner_image.caption = image.caption
  inner_image.identifier = ""
  inner_image.classes = {}
  inner_image.attributes = {}
  figure.content[1].content[1] = inner_image
  return figure
end
