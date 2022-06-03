-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- utilities for conversion xy color for Lidl and sengled
local utils = require "st.utils"


---@module st.utils_xy
local utils_xy = {}


local function color_gamma_adjust(value)
  return value > 0.04045 and ((value + 0.055) / (1.0 + 0.055)) ^ 2.4 or value / 12.92
end

local function color_gamma_revert(value)
  return value <= 0.0031308 and 12.92 * value or (1.0 + 0.055) * (value ^ (1.0 / 2.4)) - 0.055
end

--- Converts Hue/Saturation to Red/Green/Blue
---
--- @param hue number hue in range [0,1]
--- @param saturation number saturation in range[0,1]
--- @return number, number, number equivalent red, green, blue with each color in range [0,1]
function utils_xy.hsv_to_rgb(hue, saturation)
  local r, g, b

  if (saturation <= 0) then
    r, g, b = 1, 1, 1
  else
    local region = math.floor(6 * hue)
    local remainder = 6 * hue - region

    local p = 1 - saturation
    local q = 1 - saturation * remainder
    local t = 1 - saturation * (1 - remainder)

    if region == 0 then
      r, g, b = 1, t, p
    elseif region == 1 then
      r, g, b = q, 1, p
    elseif region == 2 then
      r, g, b = p, 1, t
    elseif region == 3 then
      r, g, b = p, q, 1
    elseif region == 4 then
      r, g, b = t, p, 1
    else
      r, g, b = 1, p, q
    end
  end

  return r, g, b
end

--- Converts Red/Green/Blue to Hue/Saturation
---
--- @param red number red in range [0,1]
--- @param green number green in range [0,1]
--- @param blue number blue in range [0,1]
--- @return number, number, number equivalent hue, saturation, level with each value in range [0,1]
function utils_xy.rgb_to_hsv(red, green, blue)
  local min_rgb = math.min(red, green, blue)
  local max_rgb = math.max(red, green, blue)
  local delta = max_rgb - min_rgb

  local h, s
  local v = max_rgb

  if delta <= 0 then
    h, s = 0, 0
  else
    s = delta / max_rgb

    if red >= max_rgb then
      h = (green - blue) / delta
    elseif green >= max_rgb then
      h = 2 + (blue - red) / delta
    else
      h = 4 + (red - green) / delta
    end

    h = h / 6

    if h < 0 then
      h = h + 1
    end
  end

  return h, s, v
end

--- Convert from x/y/Y to Red/Green/Blue
---
--- @param x number x axis non-negative value
--- @param y number y axis non-negative value
--- @param Y number Y tristimulus value
--- @returns number, number, number equivalent red, green, blue vector with each color in the range [0,1]
function utils_xy.xy_to_rgb(x, y, Y)
  local X = (Y / y) * x
  local Z = (Y / y) * (1.0 - x - y)

  local M = {
    { 1.6117568, -0.2028048, -0.3022977 },
    {-0.5090571, 1.4119135, 0.0660704 },
    { 0.0260863, -0.0723525, 0.9620860 }
  }

  local r = X * M[1][1] + Y * M[1][2] + Z * M[1][3]
  local g = X * M[2][1] + Y * M[2][2] + Z * M[2][3]
  local b = X * M[3][1] + Y * M[3][2] + Z * M[3][3]

  r = r < 0 and 0 or r
  r = r > 1 and 1 or r
  g = g < 0 and 0 or g
  g = g > 1 and 1 or g
  b = b < 0 and 0 or b
  b = b > 1 and 1 or b

  local max_rgb = math.max(r, g, b)
  r = color_gamma_revert(r / max_rgb)
  g = color_gamma_revert(g / max_rgb)
  b = color_gamma_revert(b / max_rgb)

  return r, g, b
end

--- Convert from Red/Green/Blue to x/y/Y
---
--- @param red number red in range [0,1]
--- @param green number green in range [0,1]
--- @param blue number blue in range [0,1]
--- @returns number, number, number equivalent x, y, Y
function utils_xy.rgb_to_xy(red, green, blue)
  local r = color_gamma_adjust(red)
  local g = color_gamma_adjust(green)
  local b = color_gamma_adjust(blue)

  local M = {
    { 0.649926,  0.103455, 0.197109 },
    { 0.234327,  0.743075,  0.022598 },
    { 0.0000000,  0.053077,  1.03576 }
  }

  local X = r * M[1][1] + g * M[1][2] + b * M[1][3]
  local Y = r * M[2][1] + g * M[2][2] + b * M[2][3]
  local Z = r * M[3][1] + g * M[3][2] + b * M[3][3]

  local x = X / ( X + Y + Z )
  local y = Y / ( X + Y + Z )

  return x, y, Y
end

--- Safe convert from Hue/Saturation to x/y/Y
--- If hue or saturation is missing 0 is applied
---
--- @param hue number red in range [0,100]%
--- @param saturation number green in range [0,100]%
--- @returns number, number, number equivalent x, y, Y with x, y in range 0x0000 to 0xFFFF
function utils_xy.safe_hsv_to_xy(hue, saturation)
  local safe_h = hue ~= nil and hue / 100 or 0
  local safe_s = saturation ~= nil and saturation / 100 or 0

  local r, g, b = utils_xy.hsv_to_rgb(safe_h, safe_s)

  local x, y, Y = utils_xy.rgb_to_xy(r, g, b)

  return utils.round(x * 65536), utils.round(y * 65536), Y
end

--- Convert from x/y/Y to Hue/Saturation
--- If every value is missing then [x, y, Y] = [0, 0, 1]
---
--- @param x number red in range [0x0000, 0xFFFF]
--- @param y number green in range [0x0000, 0xFFFF]
--- @param Y number blue in range [0x0000, 0xFFFF]
--- @returns number, number equivalent hue, saturation, level each in range [0,100]%
function utils_xy.safe_xy_to_hsv(x, y, Y)
  local safe_x = x ~= nil and x / 65536 or 0
  local safe_y = y ~= nil and y / 65536 or 0
  local safe_Y = Y ~= nil and Y or 1

  local r, g, b = utils_xy.xy_to_rgb(safe_x, safe_y, safe_Y)

  local h, s, v = utils_xy.rgb_to_hsv(r, g, b)

  return utils.round(h * 100), utils.round(s * 100), utils.round(v * 100)
end

--- Convert from Hue/Saturation/Lightness to Red/Green/Blue
--- If lightness is missing, default to 50%.
---
--- @param hue number hue in the range [0,100]%
--- @param saturation number saturation in the range [0,100]%
--- @param lightness number lightness in the range [0,100]%, or nil
--- @returns number, number, number equivalent red, green, blue vector with each color in the range [0,255]
function utils_xy.hsl_to_rgb(hue, saturation, lightness)
  lightness = lightness or 50 -- In most ST contexts, lightness is implicitly 50%.
  hue = hue * (1 / 100) -- ST hue is 0 to 100
  saturation = saturation * (1 / 100) -- ST sat is 0 to 100
  lightness = lightness * (1 / 100) -- Match ST hue/sat units
  if saturation <= 0 then
    return 255, 255, 255 -- achromatic
  end
  local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
    return p
  end
  local red, green, blue
  local q = lightness + saturation - lightness * saturation
  local p = 2 * lightness - q
  red = hue2rgb(p, q, hue + 1/3);
  green = hue2rgb(p, q, hue);
  blue = hue2rgb(p, q, hue - 1/3);
  return utils.round(red * 255), utils.round(green * 255), utils.round(blue * 255)
end

--- Convert from red, green, blue to hue, saturation, lightness.
---
--- @param red number red component in the range [0,255]
--- @param green number green component in the range [0,255]
--- @param blue number blue component in the range [0,255]
--- @return number, number, number equivalent hue, saturation, lightness vector with each component in the range [0,100]
function utils_xy.rgb_to_hsl(red, green, blue)
  red = red * (1 / 255)
  green = green * (1 / 255)
  blue = blue * (1 / 255)
  local min = math.min(math.min(red, green), blue)
  local max = math.max(math.max(red, green), blue)
  local lightness = (min + max) * (1 / 2)
  local saturation
  local hue
  if max == min then
    saturation = 0.0
    hue = 0.0
  else
    if lightness < 0.5 then
      saturation = (max - min) / (max + min)
    else
      saturation = (max - min) / (2.0 - max - min)
    end

    if max == red then
      hue = (green - blue) / (max - min)
    elseif max == green then
      hue = 2 + (blue - red) / (max - min)
    else
      hue = 4 + (red - green) / (max - min)
    end
    hue = hue * (1 / 6)
    if hue < 0 then hue = hue + 1 end -- normalize to [0,1]
  end
  return utils.round(hue * 100), utils.round(saturation * 100), utils.round(lightness * 100)
end

return utils_xy
