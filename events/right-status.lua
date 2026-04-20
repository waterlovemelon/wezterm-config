---@type Wezterm
local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local performance = require('utils.performance')
local backdrops = require('utils.backdrops')

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   date      = { fg = '#fab387', bg = 'rgba(0, 0, 0, 0.4)' },
   mode      = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
   battery   = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   separator = { fg = '#74c7ec', bg = 'rgba(0, 0, 0, 0.4)' }
}

local cells = Cells:new()

cells
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('mode_text', '', colors.mode, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))

---@return string?, string?
local function battery_info()
   -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/battery_info.html

   local charge = nil
   local icon = nil

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   if not charge or not icon then
      return nil, nil
   end

   return charge, icon .. ' '
end

M.setup = function()
   wezterm.on('update-status', function(window, _pane)
      performance:maybe_apply_auto_profile(window, backdrops)

      local perf = performance:state()
      local battery_text, battery_icon = battery_info()
      local segment_ids = { 'date_icon', 'date_text', 'separator', 'mode_text' }

      cells
         :update_segment_text('date_text', wezterm.strftime(perf.profile.date_format))
         :update_segment_text('mode_text', performance:label(perf.selector))

      if battery_text and battery_icon then
         cells
            :update_segment_text('battery_icon', battery_icon)
            :update_segment_text('battery_text', battery_text)

         table.insert(segment_ids, 'separator')
         table.insert(segment_ids, 'battery_icon')
         table.insert(segment_ids, 'battery_text')
      else
         cells
            :update_segment_text('battery_icon', '')
            :update_segment_text('battery_text', '')
      end

      window:set_right_status(
         wezterm.format(cells:render(segment_ids))
      )
   end)
end

return M
