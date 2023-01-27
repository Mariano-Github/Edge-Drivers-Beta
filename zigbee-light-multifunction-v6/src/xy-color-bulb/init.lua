-- Copyright 2022 SmartThings
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

local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
--local switch_defaults = require "st.zigbee.defaults.switch_defaults"
local configurationMap = require "configurations"
local utils = require "st.utils"
local utils_xy = require "utils-xy-lidl"

local zcl_clusters = require "st.zigbee.zcl.clusters"
--local LevelControlCluster = zcl_clusters.Level

--local LAST_KELVIN_SET = "last_kelvin_set"
--local CONVERSION_CONSTANT = 1000000

local ColorControl = clusters.ColorControl

local CURRENT_X = "current_x_value" -- y value from xyY color space
local CURRENT_Y = "current_y_value" -- x value from xyY color space
local Y_TRISTIMULUS_VALUE = "y_tristimulus_value" -- Y tristimulus value which is used to convert color xyY -> RGB -> HSV

local XY_COLOR_BULB_FINGERPRINTS = {
  ["IKEA of Sweden"] = {
    ["TRADFRI bulb E27 CWS opal 600lm"] = true,
    ["TRADFRI bulb E26 CWS opal 600lm"] = true,
    ["TRADFRI bulb GU10 CWS 380lm"] = true,
    ["TRADFRI bulb E27 CWS 806lm"] = true,
  },
  ["_TZ3000_riwp3k79"] = {
    ["TS0505A"] = true
  },
  ["_TZ3000_dbou1ap4"] = {
    ["TS0505A"] = true
  },
  ["_TZ3000_kdpxju99"] = {
    ["TS0505A"] = true
  },
  ["_TZ3000_v7fkcekx"] = {
    ["TS0505A"] = true
  },
  ["_TZ3210_iystcadi"] = {
    ["TS0505B"] = true
  },
  ["_TZ3210_sroezl0s"] = {
    ["TS0504B"] = true
  },
  ["_TZ3000_odygigth"] = {
    ["TS0505A"] = true
  },
  ["_TZ3000_gek6snaj"] = {
    ["TS0505A"] = true
  },
  ["_TZ3000_9cpuaca6"] = {
    ["TS0505A"] = true
  },
  ["_TZ3000_keabpigv"] = {
    ["TS0505A"] = true
  },
  ["_TZ3000_obacbukl"] = {
    ["TS0503A"] = true
  },
  ----- WARNNING: ADD FINGERPRINTS TO configurations.lua file ------
  --["_TZ3000_49qchf10"] = { -- LIDL mia solo ColorTemp
    --["TS0502A"] = true
  --}
}

local function can_handle_xy_color_bulb(opts, driver, device)
  local zll_xy = (XY_COLOR_BULB_FINGERPRINTS[device:get_manufacturer()] or {})[device:get_model()] or false
  if zll_xy == true then
    device:set_field("zll_xy", "yes")
  else
    device:set_field("zll_xy", "no")
  end
  if device.preferences.logDebugPrint == true then
    print("zll_xy >>>>>>", device:get_field("zll_xy"))
  end
  return (XY_COLOR_BULB_FINGERPRINTS[device:get_manufacturer()] or {})[device:get_model()] or false
end

local device_init = function(self, device)
  device:configure()
  device:remove_configured_attribute(ColorControl.ID, ColorControl.attributes.CurrentHue.ID)
  device:remove_configured_attribute(ColorControl.ID, ColorControl.attributes.CurrentSaturation.ID)
  device:remove_monitored_attribute(ColorControl.ID, ColorControl.attributes.CurrentHue.ID)
  device:remove_monitored_attribute(ColorControl.ID, ColorControl.attributes.CurrentSaturation.ID)

  print("<<<< XY Configuration >>>>")
  local configuration = configurationMap.get_device_configuration(device)
  if configuration ~= nil then
    for _, attribute in ipairs(configuration) do
      device:add_configured_attribute(attribute)
      device:add_monitored_attribute(attribute)
    end
  end
end

local function store_xyY_values(device, x, y, Y)
  device:set_field(Y_TRISTIMULUS_VALUE, Y)
  device:set_field(CURRENT_X, x)
  device:set_field(CURRENT_Y, y)
end

local query_device = function(device)
  return function()
    device:send(ColorControl.attributes.CurrentX:read(device))
    device:send(ColorControl.attributes.CurrentY:read(device))
  end
end

-- move to last level stored
local function move_to_last_level(device)
  local last_Level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
  if last_Level == nil then 
    last_Level = 100
    device:set_field("last_Level", 100, {persist = true})
  end
  if last_Level < 1 then last_Level = device:get_field("last_Level") end
  if device.preferences.levelTransTime == 0 then
    device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), 0xFFFF))
  else
    device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), (device.preferences.levelTransTime * 4)))
  end
end
local function set_color_handler(driver, device, cmd)
  print("<<<< set_color_handler XY >>>>")
  local hue = cmd.args.color.hue > 99 and 99 or cmd.args.color.hue
  local sat = cmd.args.color.saturation
  local x, y, Y = 0,0,0
  if device:get_manufacturer()=="IKEA of Sweden" then
   x, y, Y = utils.safe_hsv_to_xy(hue, sat)
  else
    x, y, Y = utils_xy.safe_hsv_to_xy(hue, sat)
  end
  store_xyY_values(device, x, y, Y)

  if device.preferences.logDebugPrint == true then
    print(">>>>> CURRENT_X=",x)
    print(">>>>> CURRENT_Y=",y)
    print(">>>>> Y_TRISTIMULUS_VALUE=",Y)
  end

  --switch_defaults.on(driver,device,cmd)
  move_to_last_level(device)

  --device:send(ColorControl.commands.MoveToColor(device, x, y, 0x0000))
  device:send(ColorControl.commands.MoveToColor(device, x, y, device.preferences.colorTransTime *4))

  device.thread:call_with_delay(2, query_device(device))
end

local function set_hue_handler(driver, device, cmd)
  print("<<<< set_hue_handler XY >>>>")
  local sat = device:get_latest_state("main", capabilities.colorControl.ID, capabilities.colorControl.saturation.NAME)
  local hue = cmd.args.hue > 99 and 99 or cmd.args.hue
  local x, y, Y = 0,0,0
  if device:get_manufacturer()=="IKEA of Sweden" then
   x, y, Y = utils.safe_hsv_to_xy(hue, sat)
  else
    x, y, Y = utils_xy.safe_hsv_to_xy(hue, sat)
  end
  --local x, y, Y = utils.safe_hsv_to_xy(hue, sat)
  store_xyY_values(device, x, y, Y)
  
  --switch_defaults.on(driver,device,cmd)
  move_to_last_level(device)

  --device:send(ColorControl.commands.MoveToColor(device, x, y, 0x0000))
  device:send(ColorControl.commands.MoveToColor(device, x, y, device.preferences.colorTransTime *4))

  device.thread:call_with_delay(2, query_device(device))
end

local function set_saturation_handler(driver, device, cmd)
  print("<<<< set_saturation_handler XY >>>>")
  local hue = device:get_latest_state("main", capabilities.colorControl.ID, capabilities.colorControl.hue.NAME)
  --local x, y, Y = utils.safe_hsv_to_xy(hue, cmd.args.saturation)
  local x, y, Y = 0,0,0
  if device:get_manufacturer()=="IKEA of Sweden" then
   x, y, Y = utils.safe_hsv_to_xy(hue, cmd.args.saturationt)
  else
    x, y, Y = utils_xy.safe_hsv_to_xy(hue, cmd.args.saturation)
  end
  store_xyY_values(device, x, y, Y)
  
  --switch_defaults.on(driver,device,cmd)
  move_to_last_level(device)

  --device:send(ColorControl.commands.MoveToColor(device, x, y, 0x0000))
  device:send(ColorControl.commands.MoveToColor(device, x, y, device.preferences.colorTransTime *4))

  device.thread:call_with_delay(2, query_device(device))
end

local function current_x_attr_handler(driver, device, value, zb_rx)

  if device:get_field("colorChanging") =="Active" then return end

  print("<<<< current_x_attr_handler XY >>>>")
  local Y_tristimulus = device:get_field(Y_TRISTIMULUS_VALUE)
  local y = device:get_field(CURRENT_Y)
  local x = value.value

  if y then
    local hue,saturation = 0,0
    if device:get_manufacturer()=="IKEA of Sweden" then
      hue, saturation = utils.safe_xy_to_hsv(x, y, Y_tristimulus)
    else
      hue, saturation = utils_xy.safe_xy_to_hsv(x, y, Y_tristimulus)
    end
    device:emit_event(capabilities.colorControl.hue(hue))
    device:emit_event(capabilities.colorControl.saturation(saturation))
  end

  device:set_field(CURRENT_X, x)
end

local function current_y_attr_handler(driver, device, value, zb_rx)

  if device:get_field("colorChanging") =="Active" then return end
  
  print("<<<< current_y_attr_handler XY >>>>")
  local Y_tristimulus = device:get_field(Y_TRISTIMULUS_VALUE)
  local x = device:get_field(CURRENT_X)
  local y = value.value

  if x then
    local hue,saturation = 0,0
    if device:get_manufacturer()=="IKEA of Sweden" then
      hue, saturation = utils.safe_xy_to_hsv(x, y, Y_tristimulus)
    else
      hue, saturation = utils_xy.safe_xy_to_hsv(x, y, Y_tristimulus)
    end
    --local hue, saturation = utils.safe_xy_to_hsv(x, y, Y_tristimulus)

    device:emit_event(capabilities.colorControl.hue(hue))
    device:emit_event(capabilities.colorControl.saturation(saturation))
  end

  device:set_field(CURRENT_Y, y)
end


local xy_color_bulb = {
  NAME = "XY Color Bulb",
  lifecycle_handlers = {
    added = device_init
  },
  capability_handlers = {
    [capabilities.colorControl.ID] = {
      [capabilities.colorControl.commands.setColor.NAME] = set_color_handler,
      [capabilities.colorControl.commands.setHue.NAME] = set_hue_handler,
      [capabilities.colorControl.commands.setSaturation.NAME] = set_saturation_handler
    }
  },
  zigbee_handlers = {
    attr = {
      [ColorControl.ID] = {
        [ColorControl.attributes.CurrentX.ID] = current_x_attr_handler,
        [ColorControl.attributes.CurrentY.ID] = current_y_attr_handler,
      }
    }
  },
  can_handle = can_handle_xy_color_bulb
}

return xy_color_bulb
