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
--local data_types = require "st.zigbee.data_types"

--module emit signal metrics
local signal = require "signal-metrics"

local function do_configure(self,device)

--illuminance configuration
  device:send(device_management.build_bind_request(device, zcl_clusters.IlluminanceMeasurement.ID, self.environment_info.hub_zigbee_eui, 3):to_endpoint (3))
  device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, 3600, 1):to_endpoint (3))
  
  -- occupancy configuration
  device:send(device_management.build_bind_request(device, zcl_clusters.OccupancySensing.ID, self.environment_info.hub_zigbee_eui, 2):to_endpoint (2))
  device:send(zcl_clusters.OccupancySensing.attributes.Occupancy:configure_reporting(device, 0, 3600):to_endpoint (2))

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

  -- Modified to multiply by 10
  local lux_value = math.floor((10 ^ ((value.value - 1) / 10000)) * 10)
  if lux_value < 0 then lux_value = 0 end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(lux_value))
end

--- Default handler for occupancy attribute on the occupancy sensing cluster
---
--- This converts the Bitmap8 value of the occupancy attribute to OccupancySensor.occupancy occupied if bit 1 is set
--- unoccupied otherwise
---
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param value st.zigbee.data_types.Bitmap8 the value of the occupancy attribute on the OccupancySensing cluster
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function occupancy_attr_handler(driver, device, value, zb_rx)

  -- emit signal metrics
  signal.metrics(device, zb_rx)

  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, ((value.value & 0x01) ~= 0) and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())
end

--- do_driverSwitched
local function do_driverSwitched(self, device)
  print("<<<< DriverSwitched >>>>")
   device.thread:call_with_delay(2, function(d)
     do_configure(self, device)
   end, "configure") 
 end

local ikea_vallhorn_motion = {
  NAME = "IKEA VALLHORN Motion",
  lifecycle_handlers = {
    doConfigure = do_configure,
    driverSwitched =  do_driverSwitched,
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.OccupancySensing.ID] = {
        [zcl_clusters.OccupancySensing.attributes.Occupancy.ID] = occupancy_attr_handler
      },
      [zcl_clusters.IlluminanceMeasurement.ID] = {
        [zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_measurement_defaults
    }
    }
  },
  can_handle = require("ikea-vallhorn.can_handle")
}

return ikea_vallhorn_motion
