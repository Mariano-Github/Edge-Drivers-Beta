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
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"

local write = require "writeAttribute"


--- Update preferences after infoChanged recived---
local function do_Preferences (self, device, event, args)
  for id, value in pairs(device.preferences) do
    --print("device.preferences[infoChanged]=", id, device.preferences[id])
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if device:get_field(id) ~= nil then
      --print("set_field ~= nil")
      device:set_field(id, nil, {persist = false})
    end
    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:",id, "old value:",oldPreferenceValue, "new value:", newParameterValue)

      --- Configure calibration cluster 0x0102, attributte 0xF001 data type "Enum8"
      if id == "performCalibration" then
        print("<<< Write perform Calibration >>>")
        local value_send = tonumber(newParameterValue)
        local data_value = {value = value_send, ID = 0x30}
        local cluster_id = {value = 0x0102}
        local attr_id = 0xF001
        write.write_attribute_function(device, cluster_id, attr_id, data_value)

       --- Configure motorReversal cluster 0x0102, attributte 0xF002 data type "Enum8"
      elseif id == "motorReversal" then
        print("<<< Write motor Reversal >>>")
        local value_send = tonumber(newParameterValue)
        local data_value = {value = value_send, ID = 0x30}
        local cluster_id = {value = 0x0102}
        local attr_id = 0xF002
        write.write_attribute_function(device, cluster_id, attr_id, data_value)
      elseif id == "quickCalibration" then
        print("<<< Write quick Calibration >>>")
        local value_send = newParameterValue * 10
        local data_value = {value = value_send, ID = 0x21}
        local cluster_id = {value = 0x0102}
        local attr_id = 0xF003
        write.write_attribute_function(device, cluster_id, attr_id, data_value)
      elseif id == "batteryType" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.type(newParameterValue))
      elseif id == "batteryQuantity" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.quantity(newParameterValue))
      end
    end
  end

  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device)
  print("Manufacturer >>>", manufacturer)
  print("Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model)
  print("Model_len >>>",model_len)
  local firmware_full_version = device.data.firmwareFullVersion
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end


local function added_handler(self, device)
  device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({"open", "close", "pause"}, { visibility = { displayed = false }}))
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
  local version = require "version"

local lazy_handler
if version.api >= 15 then
  lazy_handler = require "st.utils.lazy_handler"
else
  lazy_handler = require
end
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

local zigbee_window_treatment_driver_template = {
  supported_capabilities = {
    capabilities.windowShade,
    capabilities.windowShadePreset,
    capabilities.windowShadeLevel,
    capabilities.battery
  },
  sub_drivers = {
    lazy_load_if_possible("vimar"),
    lazy_load_if_possible("aqara"),
    lazy_load_if_possible("feibit"),
    lazy_load_if_possible("somfy"),
    lazy_load_if_possible("IKEA"),
    lazy_load_if_possible("rooms-beautiful"),
    lazy_load_if_possible("axis"), 
    lazy_load_if_possible("yoolax"),
    lazy_load_if_possible("tuya-calib"),
    lazy_load_if_possible("smartwings"),
    lazy_load_if_possible("current-position"),
    lazy_load_if_possible("hanssem"),
    lazy_load_if_possible("ts0302")
 },
  lifecycle_handlers = {
    added = added_handler,
    infoChanged = do_Preferences
  },
  health_check = false,
}

defaults.register_for_default_handlers(zigbee_window_treatment_driver_template, zigbee_window_treatment_driver_template.supported_capabilities)
local zigbee_window_treatment = ZigbeeDriver("zigbee_window_treatment", zigbee_window_treatment_driver_template)
zigbee_window_treatment:run()
