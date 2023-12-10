
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

-------- Author Mariano Colmenarejo (Oct 2021)

local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local constants = require "st.zigbee.constants"

local ZIGBEE_DEVELCO_FINGERPRINTS = {
  { mfr = "Develco Products A/S", model = "SPLZB-131" },
  { mfr = "frient A/S", model = "SPLZB-131" },
  { mfr = "Develco Products A/S", model = "SMRZB-332" },
  { mfr = "frient A/S", model = "SMRZB-332" },
  { mfr = "NAMRON AS", model = "4512749-N" }
}

local is_zigbee_develco = function(opts, driver, device)
  for _, fingerprint in ipairs(ZIGBEE_DEVELCO_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          return true
      end
  end
  return false
end

-- device temperature handler
local function device_temperature_handler(driver, device, value, zb_rx)
  if device.preferences.logDebugPrint == true then
    print("<<<< value.value =", value.value)
  end
  if value.value ~= 0xFFFF then
    local raw_temp = value.value
    local temp_scale = "C"
    -- All events from drivers should be in celsius and without offset manipulation
    device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.temperatureMeasurement.temperature({value = raw_temp, unit = temp_scale }))
  end
end

--- voltage_handler
local function voltage_handler(driver, device, value, zb_rx)
  print(">>>> Voltage handler")
  local raw_value = value.value
  if device:get_manufacturer() == "NAMRON AS" and device:get_model() == "4512749-N" then
    device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.voltageMeasurement.voltage(raw_value / 10))
  else
    --save last time and last value tu voltage
    if device:get_field("lastTime_voltage") == nil then device:set_field("lastTime_voltage", os.time() - device.preferences.voltageMaxTime + 1000) end
    if device:get_field("lastVoltage") == nil then device:set_field("lastVoltage", raw_value) end
    if (os.time() - device:get_field("lastTime_voltage")) < device.preferences.voltageMaxTime and math.abs(raw_value - device:get_field("lastVoltage")) < device.preferences.voltageChangeRep * 100 then return end
    raw_value = raw_value / 100

    device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.voltageMeasurement.voltage(raw_value))

    device:set_field("lastTime_voltage",os.time())
    device:set_field("lastVoltage", raw_value * 100)
  end
end

--- active_power_meter_handler
local function active_power_meter_handler(driver, device, value, zb_rx)
  print(">>>> Active Power handler")
  local raw_value = value.value
  -- By default emit raw value
  local multiplier = device:get_field(constants.ELECTRICAL_MEASUREMENT_MULTIPLIER_KEY) or 1
  local divisor = device:get_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY) or 1

  if divisor == 0 then 
    --log.warn("Temperature scale divisor is 0; using 1 to avoid division by zero")
    divisor = 1
  end
  
  if device.preferences.logDebugPrint == true then
    print("multiplier >>>>",multiplier)
    print("divisor >>>>>",divisor)
  end
  raw_value = raw_value * multiplier/divisor

  local raw_value_watts = raw_value
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.powerMeter.power({value = raw_value_watts, unit = "W" }))
end

---- SubDriver template config
local device_temperature = {
  NAME = "Device Temperature",

  zigbee_handlers = {
    attr = {
      [0x0002] = {
        [0x0000] = device_temperature_handler
      },
      [zcl_clusters.ElectricalMeasurement.ID] = {
        [zcl_clusters.ElectricalMeasurement.attributes.RMSVoltage.ID] = voltage_handler,
        [zcl_clusters.ElectricalMeasurement.attributes.ActivePower.ID] = active_power_meter_handler,
      },
    },
  },
  can_handle = is_zigbee_develco
}

return device_temperature