local wezterm = require('wezterm')
local platform = require('utils.platform')

local font

local font_size = platform.is_mac and 14 or 11.2

if platform.is_linux then
   -- Prefer the installed Nerd Font on Linux to avoid repeated glyph/fallback warnings.
   font = wezterm.font_with_fallback({
      { family = 'JetBrainsMono Nerd Font Mono', weight = 'Medium' },
      { family = 'Noto Sans Mono CJK SC', weight = 'Regular' },
      { family = 'Symbols Nerd Font Mono', weight = 'Regular' },
      { family = 'JetBrains Mono', weight = 'Medium' },
   })
else
   -- local font_family = 'Maple Mono NF'
   -- local font_family = 'CartographCF Nerd Font'
   font = wezterm.font({
      family = 'JetBrains Mono',
      weight = 'Medium',
   })
end

return {
   font = font,
   font_size = font_size,

   --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
   freetype_load_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_render_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
}
