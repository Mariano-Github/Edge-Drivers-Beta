
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

local ZIGBEE_DEVELCO_FINGERPRINTS = {
  { mfr = "Develco Products A/S", model = "SPLZB-131" },
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

---- SubDriver template config
local device_temperature = {
  NAME = "Device Temperature",

  zigbee_handlers = {
    attr = {
      [0x0002] = {
        [0x0000] = device_temperature_handler
      },
    },
  },
  can_handle = is_zigbee_develco
}

return device_temperature