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

--local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local IASZone = clusters.IASZone
local device_management = require "st.zigbee.device_management"

-- required module
local signal = require "signal-metrics"
--local configurationMap = require "configurations"


-- emit event defaults
local generate_event_from_zone_status = function(driver, device, zone_status, zigbee_message)

    device:emit_event_for_endpoint(
        zigbee_message.address_header.src_endpoint.value,
        (zone_status:is_alarm1_set() or zone_status:is_alarm2_set()) and capabilities.gasDetector.gas.detected() or capabilities.gasDetector.gas.clear())

  -- emit signal metrics
  signal.metrics(device, zigbee_message)

end

-- Default handler for zoneStatus attribute on the IAS Zone cluster
local function ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
  print("<<< ias_zone_status_attr_handler >>>>")

  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--- Default handler for zoneStatus change handler
local function ias_zone_status_change_handler(driver, device, zb_rx)
  print("<<< ias_zone_status_change_handler >>>>")

  local zone_status = zb_rx.body.zcl_body.zone_status
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--do Configure
local function do_configure(self, device)
  print("<< Gas do Configure >>")
  device:send(device_management.build_bind_request(device, IASZone.ID, self.environment_info.hub_zigbee_eui))
  device:send(IASZone.attributes.ZoneStatus:configure_reporting(device, 30, 180, 1))
  device:configure()
end

--- do_driverSwitched
local function do_driverSwitched(self, device) --23/12/23
  print("<<<< Gas DriverSwitched >>>>")
  device.thread:call_with_delay(3, function(d)
    do_configure(self, device)
  end, "configure") 
end

local gas_detector = {
  NAME = "Gas Detector",
  supported_capabilities = {
    --capabilities.gasDetector,
    --capabilities.battery
  },
  zigbee_handlers = {
    cluster = {
      [zcl_clusters.IASZone.ID] = {
        [zcl_clusters.IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    },
    attr = {
      [zcl_clusters.IASZone.ID] = {
        [zcl_clusters.IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    },
  },
  lifecycle_handlers = {
    doConfigure = do_configure,
    driverSwitched = do_driverSwitched
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,

  can_handle = require("gas-handler.can_handle"),
}

return gas_detector
