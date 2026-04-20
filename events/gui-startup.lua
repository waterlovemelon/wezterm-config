---@type Wezterm
local wezterm = require('wezterm')
local mux = wezterm.mux
local performance = require('utils.performance')

local M = {}

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      if performance:normalize_selector() == 'auto' then
         performance:start_async_detection()
      end

      local _, _, window = mux.spawn_window(cmd or {})
      window:gui_window():maximize()
   end)
end

return M
