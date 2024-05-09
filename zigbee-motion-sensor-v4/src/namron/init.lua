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
local device_management = require "st.zigbee.device_management"

--module emit signal metrics
local signal = require "signal-metrics"

local ZIGBEE_NAMRON_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "NAMRON AS", model = "4512770" },
  { mfr = "NAMRON AS", model = "4512771" },
  { mfr = "Sunricher", model = "HK-SENSOR-4IN1-A" },
}

local is_zigbee_namron_motion_sensor = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(ZIGBEE_NAMRON_MOTION_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("namron")
          return true, subdriver
        end
    end
  end
  return false
end

local function do_configure(self,device)

--illuminance configuration
  local max = device.preferences.illuMaxTime * 60
  local change = math.floor(10000 * (math.log((device.preferences.illuChangeRep), 10)))
  print ("Illumin maxTime & changeRep: ", max, change)
  device:send(device_management.build_bind_request(device, zcl_clusters.IlluminanceMeasurement.ID, self.environment_info.hub_zigbee_eui, 5):to_endpoint (5))
  device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, max, change):to_endpoint (5))

  -- humidity configuration
  max = device.preferences.humMaxTime * 60
  change = device.preferences.humChangeRep * 100
  print ("Humidity maxTime & changeRep: ", max, change)
  device:send(device_management.build_bind_request(device, zcl_clusters.RelativeHumidity.ID, self.environment_info.hub_zigbee_eui, 4):to_endpoint (4))
  device:send(zcl_clusters.RelativeHumidity.attributes.MeasuredValue:configure_reporting(device, 30, max, change):to_endpoint (4))

  -- temperature configuration
  max = device.preferences.maxTime * 60
  change = device.preferences.changeRep * 100
  print ("Temp maxTime & changeRep: ", max, change)
  device:send(device_management.build_bind_request(device, zcl_clusters.TemperatureMeasurement.ID, self.environment_info.hub_zigbee_eui, 3):to_endpoint (3))
  device:send(zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, max, change):to_endpoint (3))

  -- IAS configuration
  device:send(device_management.build_bind_request(device, zcl_clusters.IASZone.ID, self.environment_info.hub_zigbee_eui, 2):to_endpoint (2))
  device:send(zcl_clusters.IASZone.attributes.ZoneStatus:configure_reporting(device, 30, 300, 1):to_endpoint (2))
  
  -- occupancy configuration
  device:send(device_management.build_bind_request(device, zcl_clusters.OccupancySensing.ID, self.environment_info.hub_zigbee_eui, 1):to_endpoint (1))
  --device:send(zcl_clusters.OccupancySensing.attributes.Occupancy:configure_reporting(device, 0, 3600):to_endpoint (1))

  -- Battery configuration
  device:send(device_management.build_bind_request(device, zcl_clusters.PowerConfiguration.ID, self.environment_info.hub_zigbee_eui, 1):to_endpoint (1))
  device:send(zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1):to_endpoint (1))
  --device:send(zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 1800, 1):to_endpoint (1))

  print("doConfigure performed, transitioning device to PROVISIONED") --23/12/23
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })

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

--- do_driverSwitched
local function do_driverSwitched(self, device)
  print("<<<< DriverSwitched >>>>")
   device.thread:call_with_delay(2, function(d)
     do_configure(self, device)
   end, "configure") 
 end

local namron_motion_handler = {
  NAME = "NAMRON Motion Handler",
  lifecycle_handlers = {
    doConfigure = do_configure,
    driverSwitched = do_driverSwitched,
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.IlluminanceMeasurement.ID] = {
        [zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_measurement_defaults
      }
    }
  },
  can_handle = is_zigbee_namron_motion_sensor
}

return namron_motion_handler
