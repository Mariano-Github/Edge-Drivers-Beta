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

local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
--local battery = capabilities.battery
--local utils = require "st.utils"
local constants = require "st.zigbee.constants"
-- required module
local signal = require "signal-metrics"
local configurationMap = require "configurations"


local is_gas_detector = function(opts, driver, device)
  if (device:get_manufacturer() == "LUMI" and device:get_model() == "lumi.sensor_gas.acn02") or
    (device:get_manufacturer() == "_TYZB01_mfccmeio" and device:get_model() == "TS0204") then -- gas detector
    --or (device:get_manufacturer() == "_TYZB01_18pkine6" and device:get_model() == "TS0204")
    return true
  end
  return false
end

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

local function added(driver, device)
  local configuration = configurationMap.get_device_configuration(device)
    if configuration ~= nil then
      for _, attribute in ipairs(configuration) do
        device:add_configured_attribute(attribute)
        device:add_monitored_attribute(attribute)
      end
    end
end

local gas_detector = {
  NAME = "Gas Detector",
  supported_capabilities = {
    capabilities.gasDetector,
    capabilities.battery
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
    added = added
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,

  can_handle = is_gas_detector
}

return gas_detector
