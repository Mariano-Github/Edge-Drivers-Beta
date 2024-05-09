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

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local utils = require "st.utils"
-- required module
local signal = require "signal-metrics"
local child_devices = require "child-devices"


-- preferences update
local function do_preferences(self, device)
  print("***** infoChanged *********")
  
   for id, value in pairs(device.preferences) do
    --print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed Name:", id, "old Value", oldPreferenceValue, "new Value>>", newParameterValue)
      if id == "childBatteries" then
        if newParameterValue == true then
          child_devices.create_new(self, device, "main", "child-batteries-status")
        end
      end
    end
  end
  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len) 
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")

  local firmware_full_version = device.data.firmwareFullVersion
  if firmware_full_version == nil then firmware_full_version = "Unknown" end
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
end


-- battery_percentage_handler
local function battery_percentage_handler(driver, device, raw_value, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)

  local percentage = utils.clamp_value(utils.round(raw_value.value / 2), 0, 100)
  device:emit_event(capabilities.battery.battery(percentage))
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
  local function lazy_load_if_possible(sub_driver_name)
    -- gets the current lua libs api version
    local version = require "version"
  
    --print("<<<<< Library Version:", version.api)
    -- version 9 will include the lazy loading functions
    if version.api >= 9 then
      return ZigbeeDriver.lazy_load_sub_driver(require(sub_driver_name))
    else
      return require(sub_driver_name)
    end
  end

local zigbee_smoke_driver_template = {
  lifecycle_handlers = {
    infoChanged = do_preferences
  },
  supported_capabilities = {
    capabilities.smokeDetector,
    capabilities.carbonMonoxideDetector,
    capabilities.battery,
    capabilities.temperatureMeasurement

  },
  zigbee_handlers = {
    attr = {
      [clusters.PowerConfiguration.ID] = {
        [clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_percentage_handler
      }
   }
  },
  sub_drivers = { lazy_load_if_possible("frient"),
    lazy_load_if_possible("co-handler"),
    lazy_load_if_possible("heiman-SMOK_V16"),
    lazy_load_if_possible("gas-handler"),
    lazy_load_if_possible("battery-virtual-status")
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
}

defaults.register_for_default_handlers(zigbee_smoke_driver_template, zigbee_smoke_driver_template.supported_capabilities)
local zigbee_smoke_driver = ZigbeeDriver("zigbee-smoke-detector", zigbee_smoke_driver_template)
zigbee_smoke_driver:run()
