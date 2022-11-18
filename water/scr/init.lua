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

--- Temperature Mesurement config Samjin
local zcl_clusters = require "st.zigbee.zcl.clusters"

local generate_event_from_zone_status = function(driver, device, zone_status, zigbee_message)
  device:emit_event_for_endpoint(
      zigbee_message.address_header.src_endpoint.value,
      -- this is the default event and changed by the inverted dry by wet
      --(zone_status:is_alarm1_set() or zone_status:is_alarm2_set()) and capabilities.waterSensor.water.wet() or capabilities.waterSensor.water.dry())
      (zone_status:is_alarm1_set() or zone_status:is_alarm2_set()) and capabilities.waterSensor.water.dry() or capabilities.waterSensor.water.wet())
end

--- Default handler for zoneStatus attribute on the IAS Zone cluster
---
--- This converts the 2 byte bitmap value to waterSensor.water."dry" or waterSensor.water."wet"
---
--- @param driver Driver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zone_status st.zigbee.zcl.types.IasZoneStatus 2 byte bitmap zoneStatus attribute value of the IAS Zone cluster
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
local function ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--- Default handler for zoneStatus change handler
---
--- This converts the 2 byte bitmap value to waterSensor.water."dry" or waterSensor.water."wet"
---
--- @param driver Driver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param zb_rx st.zigbee.ZigbeeMessageRx containing zoneStatus attribute value of the IAS Zone cluster
local function ias_zone_status_change_handler(driver, device, zb_rx)
  local zone_status = zb_rx.body.zcl_body.zone_status
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

----- driver template ----------
local zigbee_rain_driver = {
  supported_capabilities = {
    capabilities.waterSensor,
    capabilities.battery,
    capabilities.refresh

  },
  lifecycle_handlers = {

  },
  zigbee_handlers = {
    global = {},
    cluster = {
      [zcl_clusters.IASZone.ID] = {
        [zcl_clusters.IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    },
    attr = {
      [zcl_clusters.IASZone.ID] = {
        [zcl_clusters.IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    }
  },

}

--------- driver run ------
defaults.register_for_default_handlers(zigbee_rain_driver, zigbee_rain_driver.supported_capabilities)
local moisture = ZigbeeDriver("zigbee_rain_driver", zigbee_rain_driver)
moisture:run()
