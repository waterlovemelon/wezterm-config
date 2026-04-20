---@type Wezterm
local wezterm = require('wezterm')
local gpu_adapters = require('utils.gpu-adapter')
local platform = require('utils.platform')

local STATE_DIR = wezterm.config_dir .. '/state'
local STATE_FILE = wezterm.config_dir .. '/state/performance.lua'
local HARDWARE_STATE_FILE = wezterm.config_dir .. '/state/hardware.lua'
local DETECT_CPU_SCRIPT = wezterm.config_dir .. '/scripts/detect-cpu.sh'
local MIN_HIGH_CPU_LOGICAL = 12
local MIN_HIGH_CPU_LOGICAL_MAC = 8
local SELECTOR_REFRESH_INTERVAL = 1
local AUTO_REFRESH_INTERVAL = 5

local VALID_SELECTORS = {
   auto = true,
   high = true,
   low = true,
}

local PROFILES = {
   high = {
      max_fps = 120,
      animation_fps = 120,
      default_cursor_style = 'BlinkingBlock',
      status_update_interval = 1000,
      date_format = '%a %H:%M:%S',
      show_progress = true,
      background_images = true,
      webgpu_power_preference = 'HighPerformance',
   },
   low = {
      max_fps = 60,
      animation_fps = 30,
      default_cursor_style = 'SteadyBlock',
      status_update_interval = 5000,
      date_format = '%a %H:%M',
      show_progress = false,
      background_images = false,
      webgpu_power_preference = 'LowPower',
   },
}

local M = {}
M._last_selector_reload = 0
M._selector_state = nil
M._last_hardware_reload = 0
M._hardware_state = nil

local function clear_cached_module(module_name)
   package.loaded[module_name] = nil
end

---@param path string
---@return string
local function shell_quote(path)
   return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

---@return boolean
local function ensure_state_dir()
   if platform.is_win then
      return os.execute('mkdir "' .. STATE_DIR .. '" >NUL 2>NUL') == true
   end

   return os.execute('mkdir -p ' .. shell_quote(STATE_DIR)) == true
end

---@return {selector?: string}
local function load_state()
   clear_cached_module('state.performance')
   local ok, state = pcall(require, 'state.performance')

   if ok and type(state) == 'table' then
      return state
   end

   return {}
end

---@return {selector?: string}
function M:selector_state(force)
   local now = os.time()
   local should_reload = force or self._selector_state == nil

   if not should_reload then
      should_reload = (now - self._last_selector_reload) >= SELECTOR_REFRESH_INTERVAL
   end

   if should_reload then
      self._selector_state = load_state()
      self._last_selector_reload = now
   end

   return self._selector_state or {}
end

---@return {cpu_logical?: number, updated_at?: number}
local function load_hardware_state()
   clear_cached_module('state.hardware')
   local ok, state = pcall(require, 'state.hardware')

   if ok and type(state) == 'table' then
      return state
   end

   return {}
end

---@param selector string?
---@return 'auto'|'high'|'low'
function M:normalize_selector(selector)
   if selector and VALID_SELECTORS[selector] then
      return selector
   end

   local state = self:selector_state()
   if state.selector and VALID_SELECTORS[state.selector] then
      return state.selector
   end

   return 'auto'
end

---@return GpuInfo|nil
function M:adapter()
   return gpu_adapters:pick_best()
end

---@return {cpu_logical?: number, updated_at?: number}
function M:hardware_state(force)
   local now = os.time()
   local should_reload = force or self._hardware_state == nil

   if not should_reload then
      should_reload = (now - self._last_hardware_reload) >= AUTO_REFRESH_INTERVAL
   end

   if should_reload then
      self._hardware_state = load_hardware_state()
      self._last_hardware_reload = now
   end

   return self._hardware_state or {}
end

---@return 'high'|'low'
function M:auto_mode()
   local hardware = self:hardware_state()
   local adapter = self:adapter()

   if type(hardware.cpu_logical) ~= 'number' or hardware.cpu_logical <= 0 then
      return 'low'
   end

   if not adapter then
      return 'low'
   end

   if platform.is_mac and adapter.backend == 'Metal' and hardware.cpu_logical >= MIN_HIGH_CPU_LOGICAL_MAC then
      return 'high'
   end

   if adapter.device_type == 'DiscreteGpu' and hardware.cpu_logical >= MIN_HIGH_CPU_LOGICAL then
      return 'high'
   end

   return 'low'
end

---@param selector? string
---@return 'high'|'low'
function M:effective_mode(selector)
   local current = self:normalize_selector(selector)

   if current == 'auto' then
      return self:auto_mode()
   end

   return current
end

---@param selector? string
function M:profile(selector)
   return PROFILES[self:effective_mode(selector)]
end

function M:state()
   local selector = self:normalize_selector()
   local effective_mode = self:effective_mode(selector)
   local hardware = self:hardware_state()

   return {
      selector = selector,
      effective_mode = effective_mode,
      detected_mode = self:auto_mode(),
      adapter = self:adapter(),
      cpu_logical = hardware.cpu_logical,
      hardware_updated_at = hardware.updated_at,
      profile = PROFILES[effective_mode],
   }
end

---@param selector? string
---@return string
function M:label(selector)
   local current = self:normalize_selector(selector)

   if current == 'auto' then
      return 'AUTO:' .. string.upper(self:auto_mode())
   end

   return string.upper(current)
end

function M:choices()
   return {
      {
         id = 'auto',
         label = 'Auto: choose from detected hardware capability',
      },
      {
         id = 'high',
         label = 'High: enable refresh-heavy visuals and live indicators',
      },
      {
         id = 'low',
         label = 'Low: prioritize lower CPU/GPU usage',
      },
   }
end

---@param selector? string
---@return 'auto'|'high'|'low'
function M:next_selector(selector)
   local current = self:normalize_selector(selector)

   if current == 'auto' then
      return 'high'
   elseif current == 'high' then
      return 'low'
   end

   return 'auto'
end

---@param selector string
---@return boolean, string?
function M:write_selector(selector)
   local current = self:normalize_selector(selector)

   if not ensure_state_dir() then
      return false, 'failed to create state dir'
   end

   local fd, err = io.open(STATE_FILE, 'w')

   if not fd then
      return false, err
   end

   local ok, write_err = fd:write(
      string.format(
         "return {\n   selector = %q,\n}\n",
         current
      )
   )

   fd:close()

   if not ok then
      return false, write_err
   end

   clear_cached_module('state.performance')
   self._selector_state = { selector = current }
   self._last_selector_reload = os.time()

   return true, nil
end

---@return boolean
function M:start_async_detection()
   if platform.is_win then
      return false
   end

   local argv = {
      '/bin/sh',
      DETECT_CPU_SCRIPT,
      HARDWARE_STATE_FILE,
   }

   local ok = pcall(wezterm.background_child_process, argv)

   if ok then
      return true
   end

   local cmd = table.concat({
      shell_quote(argv[1]),
      shell_quote(argv[2]),
      shell_quote(argv[3]),
      '>/dev/null 2>&1 &',
   }, ' ')

   return os.execute(cmd) == true
end

---@param backdrops BackDrops
---@param selector? string
function M:window_overrides(backdrops, selector)
   local profile = self:profile(selector)

   return {
      max_fps = profile.max_fps,
      animation_fps = profile.animation_fps,
      default_cursor_style = profile.default_cursor_style,
      status_update_interval = profile.status_update_interval,
      webgpu_power_preference = profile.webgpu_power_preference,
      background = backdrops:initial_options({
         no_img = not profile.background_images,
      }),
   }
end

---@param window Window
---@param backdrops BackDrops
function M:maybe_apply_auto_profile(window, backdrops)
   if self:normalize_selector() ~= 'auto' then
      return
   end

   local profile = self:profile('auto')
   local effective_config = window:effective_config()
   local needs_update = effective_config.max_fps ~= profile.max_fps
      or effective_config.animation_fps ~= profile.animation_fps
      or effective_config.default_cursor_style ~= profile.default_cursor_style
      or effective_config.status_update_interval ~= profile.status_update_interval

   if not needs_update then
      return
   end

   local overrides = self:window_overrides(backdrops, 'auto')
   overrides.enable_tab_bar = effective_config.enable_tab_bar
   window:set_config_overrides(overrides)
end

return M
