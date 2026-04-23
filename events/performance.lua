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

---@param selector 'auto'|'high'|'low'
---@return string
local function palette_brief(selector)
   if selector == 'auto' then
      return 'Performance: Auto'
   elseif selector == 'high' then
      return 'Performance: High'
   end

   return 'Performance: Low'
end

---@param selector 'auto'|'high'|'low'
---@return string
local function palette_doc(selector)
   local docs = {
      auto = 'Let WezTerm choose between HIGH and LOW based on detected hardware.',
      high = 'Use the HIGH profile with refresh-heavy visuals and live indicators.',
      low = 'Use the LOW profile to reduce CPU/GPU usage.',
   }

   return docs[selector]
end

M.setup = function()
   for _, selector in ipairs({ 'auto', 'high', 'low' }) do
      wezterm.on('performance.set-' .. selector, function(window, _pane)
         apply_mode(window, selector)
      end)
   end

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

   wezterm.on('augment-command-palette', function(_window, _pane)
      local entries = {}

      for _, selector in ipairs({ 'auto', 'high', 'low' }) do
         table.insert(entries, {
            brief = palette_brief(selector),
            doc = palette_doc(selector),
            action = act.EmitEvent('performance.set-' .. selector),
         })
      end

      return entries
   end)
end

return M
