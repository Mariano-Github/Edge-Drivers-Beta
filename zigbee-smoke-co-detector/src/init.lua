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
--local child_devices = require "child-devices"


-- preferences update
local function do_preferences(self, device, event, args)
  print("***** infoChanged *********")
  
   for id, value in pairs(device.preferences) do
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    -- temporal solution to delete old preferences variables
    if device:get_field(id) ~= nil then
      device:set_field(id, nil, {persist = false})
    end
    if oldPreferenceValue ~= newParameterValue then
      print("<< Preference changed Name:", id, "old Value", oldPreferenceValue, "new Value>>", newParameterValue)
      if id == "changeProfile" then
        if newParameterValue == "Smoke" then
          device:try_update_metadata({profile = "smoke-detector"})
        else --if newParameterValue == "Gas"
          device:try_update_metadata({profile = "gas-detector"})
        end
      end
    elseif id == "batteryType" and newParameterValue ~= nil then
      device:emit_event(capabilities.battery.type(newParameterValue))
    elseif id == "batteryQuantity" and newParameterValue ~= nil then
      device:emit_event(capabilities.battery.quantity(newParameterValue))
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
    capabilities.temperatureMeasurement,
    capabilities.gasDetector,

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
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  health_check = false
}

defaults.register_for_default_handlers(zigbee_smoke_driver_template, zigbee_smoke_driver_template.supported_capabilities, {native_capability_attrs_enabled = true})
local zigbee_smoke_driver = ZigbeeDriver("zigbee-smoke-detector", zigbee_smoke_driver_template)
zigbee_smoke_driver:run()
