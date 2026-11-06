-- Word: the landscape page keeps the paper, margins and running head of the
-- document. Quarto's .landscape writes an A4 section without them, and leaves
-- the pages before it without size or running head, which Google Docs breaks

local margins = '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>'
local header = '<w:headerReference r:id="rId11" w:type="default"/>'

local function section(size)
  return pandoc.RawBlock("openxml", "<w:p><w:pPr><w:sectPr>" .. header .. size .. margins .. "</w:sectPr></w:pPr></w:p>")
end

function Div(el)
  if FORMAT:match("docx") and el.classes:includes("landscape") then
    local blocks = pandoc.List({ section('<w:pgSz w:w="12240" w:h="15840"/>') })
    blocks:extend(el.content)
    blocks:insert(section('<w:pgSz w:w="15840" w:h="12240" w:orient="landscape"/>'))
    return blocks
  end
end
