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
local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local ElectricalMeasurement = clusters.ElectricalMeasurement
local SimpleMetering = clusters.SimpleMetering

local ZIGBEE_POWER_METER_FINGERPRINTS = {
  { model = "ZHEMI101" },
  { model = "EMIZB-132" },
}

local is_frient_power_meter = function(opts, driver, device)
  for _, fingerprint in ipairs(ZIGBEE_POWER_METER_FINGERPRINTS) do
      if device:get_model() == fingerprint.model then
          return true
      end
  end

  return false
end

-- preferences update
local function do_preferences(self, device)
  for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id])
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
     if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed:", id, "old=",oldPreferenceValue, "new =", newParameterValue)
      if  id == "simpleMeteringDivisor"  then
        device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, newParameterValue, {persist = true})
      elseif id == "electricalMeasureDiviso" then
        device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, newParameterValue, {persist = true})
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
end


local do_configure = function(self, device)
  device:refresh()
  device:configure()
end

local device_init = function(self, device)
  --device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, 1000, {persist = true})
  --device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, 10000, {persist = true})
  device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, device.preferences.simpleMeteringDivisor, {persist = true})
  device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, device.preferences.electricalMeasureDivisor, {persist = true})
end

local frient_power_meter_handler = {
  NAME = "frient power meter handler",
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
    infoChanged = do_preferences
  },
  can_handle = is_frient_power_meter
}

return frient_power_meter_handler