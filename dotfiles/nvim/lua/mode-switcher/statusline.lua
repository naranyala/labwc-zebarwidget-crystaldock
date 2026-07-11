-- Mode indicator for statusline
-- Shows current mode in the statusline
local M = {}

-- State file path
local state_file = vim.fn.stdpath("data") .. "/mode-switcher.json"

-- Get current mode for statusline
function M.get_mode()
  local f = io.open(state_file, "r")
  if not f then return "full-ide" end
  local content = f:read("*a")
  f:close()

  local ok, data = pcall(vim.json.decode, content)
  if ok and data and data.mode then return data.mode end
  return "full-ide"
end

-- Get mode icon
function M.get_icon(mode)
  local icons = {
    ["minimal"] = " ",
    ["full-ide"] = " ",
    ["writing"] = "✏️ ",
    ["ai-assisted"] = " ",
    ["beautiful-ui"] = "✨",
    ["vim-purist"] = "⚙️ ",
    ["terminal-heavy"] = " ",
    ["zettelkasten"] = " ",
    ["project-centric"] = " ",
    ["debug-heavy"] = " ️",
    ["performance"] = "⚡",
    ["remote-dev"] = " ",
    ["database"] = " ️",
    ["git-centric"] = " ",
    ["multilanguage"] = " ",
    ["search-replace"] = " ",
    ["popup-everything"] = " ",
    ["notes-knowledge"] = " ",
    ["motion-textobjects"] = " ",
    ["kitchen-sink"] = " ",
  }
  return icons[mode] or " "
end

-- Lualine component
function M.lualine_component()
  local mode = M.get_mode()
  local icon = M.get_icon(mode)
  return icon .. " " .. mode
end

-- Heirline component (if using heirline)
function M.heirline_component()
  local mode = M.get_mode()
  local icon = M.get_icon(mode)
  return {
    provider = icon .. " " .. mode,
    hl = { fg = "#7aa2f7", bold = true },
  }
end

return M
