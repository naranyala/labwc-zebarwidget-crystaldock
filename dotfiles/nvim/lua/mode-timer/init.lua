-- ═══════════════════════════════════════════════════════════════
-- Mode Timer: auto-switch modes based on time of day
-- Work hours → full-ide, Evening → writing, etc.
-- ═══════════════════════════════════════════════════════════════
local M = {}

local state_file = vim.fn.stdpath("data") .. "/mode-timer.json"

-- Time-based mode schedule
local default_schedule = {
  { start = "06:00", stop = "09:00", mode = "minimal",      desc = "Morning (light)" },
  { start = "09:00", stop = "12:00", mode = "full-ide",     desc = "Morning work" },
  { start = "12:00", stop = "13:00", mode = "writing",      desc = "Lunch break" },
  { start = "13:00", stop = "17:00", mode = "full-ide",     desc = "Afternoon work" },
  { start = "17:00", stop = "19:00", mode = "terminal-heavy", desc = "Evening terminal" },
  { start = "19:00", stop = "22:00", mode = "writing",      desc = "Evening writing" },
  { start = "22:00", stop = "06:00", mode = "minimal",      desc = "Night" },
}

-- Load schedule
local function load_schedule()
  local f = io.open(state_file, "r")
  if not f then return { schedule = default_schedule, enabled = false } end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  return ok and data or { schedule = default_schedule, enabled = false }
end

local function save_state(state)
  local f = io.open(state_file, "w")
  if not f then return end
  state.timestamp = os.time()
  f:write(vim.json.encode(state))
  f:close()
end

-- Get current time as HH:MM
local function get_current_time()
  return os.date("%H:%M")
end

-- Check if time is between start and stop
local function time_in_range(time, start, stop)
  if start <= stop then
    return time >= start and time < stop
  else
    -- Overnight range (e.g., 22:00 to 06:00)
    return time >= start or time < stop
  end
end

-- Get mode for current time
function M.get_mode_for_time()
  local state = load_schedule()
  local current_time = get_current_time()

  for _, entry in ipairs(state.schedule) do
    if time_in_range(current_time, entry.start, entry.stop) then
      return entry.mode, entry.desc
    end
  end

  return "full-ide", "default"
end

-- Auto-switch based on time
function M.auto_switch()
  local state = load_schedule()
  if not state.enabled then
    vim.notify("[mode-timer] Timer is disabled. Use :ModeTimerEnable to enable.", vim.log.levels.INFO)
    return
  end

  local suggested_mode, desc = M.get_mode_for_time()
  local current_mode = require("mode-switcher").get_mode()

  if suggested_mode == current_mode then
    return -- Already in the right mode
  end

  vim.notify(
    string.format("[mode-timer] Time to switch!\nCurrent: %s → Suggested: %s\n(%s)", current_mode, suggested_mode, desc),
    vim.log.levels.INFO
  )

  local choice = vim.fn.confirm(
    string.format("Switch to %s mode?\n(%s)", suggested_mode, desc),
    "&Yes\n&No",
    1
  )

  if choice == 1 then
    require("mode-switcher").set(suggested_mode)
  end
end

-- Show current schedule
function M.show_schedule()
  local state = load_schedule()
  local lines = {
    "# Mode Timer Schedule",
    "",
    "Status: " .. (state.enabled and "ENABLED" or "DISABLED"),
    "Current time: " .. get_current_time(),
    "",
    "## Schedule",
  }

  for _, entry in ipairs(state.schedule) do
    local marker = time_in_range(get_current_time(), entry.start, entry.stop) and " (NOW)" or ""
    table.insert(lines, string.format("- %s to %s: **%s**%s (%s)", entry.start, entry.stop, entry.mode, marker, entry.desc))
  end

  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Update schedule entry
function M.update_entry(index, entry)
  local state = load_schedule()
  state.schedule[index] = entry
  save_state(state)
  vim.notify("[mode-timer] Schedule updated", vim.log.levels.INFO)
end

-- Add schedule entry
function M.add_entry(start, stop, mode, desc)
  local state = load_schedule()
  table.insert(state.schedule, { start = start, stop = stop, mode = mode, desc = desc or "" })
  save_state(state)
  vim.notify("[mode-timer] Entry added: " .. start .. "-" .. stop .. " → " .. mode, vim.log.levels.INFO)
end

-- Remove schedule entry
function M.remove_entry(index)
  local state = load_schedule()
  table.remove(state.schedule, index)
  save_state(state)
  vim.notify("[mode-timer] Entry removed", vim.log.levels.INFO)
end

-- Enable/disable timer
function M.enable()
  local state = load_schedule()
  state.enabled = true
  save_state(state)
  vim.notify("[mode-timer] Enabled", vim.log.levels.INFO)
end

function M.disable()
  local state = load_schedule()
  state.enabled = false
  save_state(state)
  vim.notify("[mode-timer] Disabled", vim.log.levels.INFO)
end

-- Setup
function M.setup(opts)
  opts = opts or {}

  -- Auto-check on VimEnter and every 5 minutes
  if opts.auto_check ~= false then
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        vim.schedule(function() M.auto_switch() end)
      end,
    })

    -- Check every 5 minutes
    vim.fn.timer_start(5 * 60 * 1000, function()
      vim.schedule(function() M.auto_switch() end)
    end)
  end

  -- Commands
  vim.api.nvim_create_user_command("ModeTimer", function() M.auto_switch() end, { desc = "Check time and switch" })
  vim.api.nvim_create_user_command("ModeTimerShow", function() M.show_schedule() end, { desc = "Show schedule" })
  vim.api.nvim_create_user_command("ModeTimerEnable", function() M.enable() end, { desc = "Enable timer" })
  vim.api.nvim_create_user_command("ModeTimerDisable", function() M.disable() end, { desc = "Disable timer" })
  vim.api.nvim_create_user_command("ModeTimerAdd", function(a)
    local args = vim.split(a.args, " ")
    if #args < 3 then
      vim.notify("[mode-timer] Usage: :ModeTimerAdd <start> <stop> <mode> [desc]", vim.log.levels.WARN)
      return
    end
    M.add_entry(args[1], args[2], args[3], args[4])
  end, { desc = "Add schedule entry", nargs = "+" })

  -- Keymaps
  vim.keymap.set("n", "<leader>mT", M.auto_switch, { desc = "  Timer check" })
  vim.keymap.set("n", "<leader>mS", M.show_schedule, { desc = "  Show schedule" })
end

return M
