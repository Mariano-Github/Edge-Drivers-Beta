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
local zcl_clusters = require "st.zigbee.zcl.clusters"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local device_management = require "st.zigbee.device_management"
local data_types = require "st.zigbee.data_types"
local OccupancySensing = zcl_clusters.OccupancySensing

--module emit signal metrics
local signal = require "signal-metrics"

local ZIGBEE_FRIENT_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "frient A/S", model = "MOSZB-140" },
}

local is_zigbee_frient_motion_sensor = function(opts, driver, device)
  for _, fingerprint in ipairs(ZIGBEE_FRIENT_MOTION_SENSOR_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          return true
      end
  end
  return false
end

local function occupancy_attr_handler(driver, device, occupancy, zb_rx)
  device:emit_event(
      occupancy.value == 1 and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())
end

local function add_illuminance(self,device)
  local maxTime = 1800
  --local changeRep = math.floor(10000 * (math.log((1), 10)))
  local changeRep = 1
  print ("Illuminance maxTime y changeRep: ",maxTime, changeRep )

  device:send(device_management.build_bind_request(device, zcl_clusters.IlluminanceMeasurement.ID, self.environment_info.hub_zigbee_eui))--:to_endpoint (0x27))
  device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep):to_endpoint (0x27))
  --device:send(device_management.build_bind_request(device, zcl_clusters.OccupancySensing.ID, self.environment_info.hub_zigbee_eui))--:to_endpoint (0x28))
  --device:send(zcl_clusters.OccupancySensing.attributes.Occupancy:configure_reporting(device, 0, 3600):to_endpoint (0x22))

  device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:read(device):to_endpoint (0x27))
  --device:send(zcl_clusters.OccupancySensing.attributes.Occupancy:read(device):to_endpoint (0x22))
  device.thread:call_with_delay(2, function(d)
    device:refresh()
  end)

end

--illuminance_measurement_defaults
local function illuminance_measurement_defaults(driver, device, value, zb_rx)

  -- emit signal metrics
  signal.metrics(device, zb_rx)
  
  local lux_value = math.floor(10 ^ ((value.value - 1) / 10000))
  if lux_value < 0 then lux_value = 0 end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(lux_value))
end

local frient_motion_handler = {
  NAME = "FRIENT Motion Handler",
  lifecycle_handlers = {
    --init = battery_defaults.build_linear_voltage_init(2.1, 3.0)
    added = add_illuminance
  },
  zigbee_handlers = {
    attr = {
      --[OccupancySensing.ID] = {
        --[OccupancySensing.attributes.Occupancy.ID] = occupancy_attr_handler
      --},
      [zcl_clusters.IlluminanceMeasurement.ID] = {
        [zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_measurement_defaults
    }
    }
  },
  can_handle = is_zigbee_frient_motion_sensor
}

return frient_motion_handler
