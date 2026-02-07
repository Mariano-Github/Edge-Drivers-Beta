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
local zcl_clusters = require "st.zigbee.zcl.clusters"
local WindowCovering = zcl_clusters.WindowCovering
local windowShadeDefaults = require "st.zigbee.defaults.windowShade_defaults"
local PowerConfiguration = zcl_clusters.PowerConfiguration

local YOOLAX_WINDOW_SHADE_FINGERPRINTS = {
    { mfr = "Yookee", model = "D10110" },                 -- Yookee Window Treatment
    { mfr = "yooksmart", model = "D10110" },              -- yooksmart Window Treatment
    { mfr = "_TZE200_9caxna4s", model = "TS0301" },        -- Yookee Window Treatment
    { mfr = "_TZE210_z2tpoj46", model = "TS0301" } ,       --  motor Window Treatment
    --{ mfr = "SONOFF", model = "MINI-ZBRBS" }        --  motor Window Treatment
}

local function is_yoolax_window_shade(opts, driver, device)
  for _, fingerprint in ipairs(YOOLAX_WINDOW_SHADE_FINGERPRINTS) do
    if (device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model) or device:get_model() == "TS0301" then
      local subdriver = require("yoolax")
      return true, subdriver
    end
  end
  return false
end

local function set_shade_level(device, value, command)
  local level = 100 - value
  if device.preferences.invert == true then
    level = value
  end
  device:send_to_component(command.component, WindowCovering.server.commands.GoToLiftPercentage(device, level))
end

local function window_shade_level_cmd(driver, device, command)
  set_shade_level(device, command.value, command)
end

local function window_shade_preset_cmd(driver, device, command)
  set_shade_level(device, device.preferences.presetPosition, command)
end

local function set_window_shade_level(level)
  return function(driver, device, cmd)
    set_shade_level(device, level, cmd)
  end
end

local function current_position_attr_handler(driver, device, value, zb_rx)
  local level = 100 - value.value
  --if device.preferences.invertPercentage == true then
  if device.preferences.invert == true then  
    level = value.value
  end
  --windowShadeDefaults.default_current_lift_percentage_handler(driver, device, {value = 100 - value.value}, zb_rx)
  windowShadeDefaults.default_current_lift_percentage_handler(driver, device, {value = level}, zb_rx)
end

-- battery percentage
local function battery_perc_attr_handler(driver, device, value, zb_rx)
  if device:get_manufacturer() == "_TZE200_9caxna4s" then
    value.value  = value.value / 2
  end
  -- this device use battery without / 2
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.battery.battery(value.value))
end

local yoolax_window_shade = {
  NAME = "yoolax window shade",
  capability_handlers = {
    [capabilities.windowShade.ID] = {
      [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = window_shade_level_cmd,
      [capabilities.windowShade.commands.open.NAME] = set_window_shade_level(100),
      [capabilities.windowShade.commands.close.NAME] = set_window_shade_level(0),
    },
    [capabilities.windowShadePreset.ID] = {
      [capabilities.windowShadePreset.commands.presetPosition.NAME] = window_shade_preset_cmd
    }
  },
  zigbee_handlers = {
    attr = {
      [WindowCovering.ID] = {
        [WindowCovering.attributes.CurrentPositionLiftPercentage.ID] = current_position_attr_handler
      },
      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_perc_attr_handler,
      }
    }
  },
  can_handle = is_yoolax_window_shade
}

return yoolax_window_shade
