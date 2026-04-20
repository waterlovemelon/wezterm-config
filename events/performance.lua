---@type Wezterm
local wezterm = require('wezterm')
local performance = require('utils.performance')
local backdrops = require('utils.backdrops')
local act = wezterm.action

local M = {}

---@param window Window
---@param selector 'auto'|'high'|'low'
local function apply_mode(window, selector)
   local ok, err = performance:write_selector(selector)

   if not ok then
      wezterm.log_error('Failed to persist performance mode: ' .. tostring(err))
      return
   end

   local overrides = performance:window_overrides(backdrops, selector)
   overrides.enable_tab_bar = window:effective_config().enable_tab_bar

   window:set_config_overrides(overrides)

   if selector == 'auto' then
      performance:start_async_detection()
   end

   wezterm.log_info('Performance mode set to ' .. performance:label(selector))
end

M.setup = function()
   wezterm.on('performance.cycle-mode', function(window, _pane)
      apply_mode(window, performance:next_selector())
   end)

   wezterm.on('performance.select-mode', function(window, pane)
      window:perform_action(
         act.InputSelector({
            title = 'InputSelector: Performance Mode',
            choices = performance:choices(),
            fuzzy = false,
            action = wezterm.action_callback(function(_window, _pane, id, _label)
               if not id then
                  return
               end

               apply_mode(window, id)
            end),
         }),
         pane
      )
   end)
end

return M
