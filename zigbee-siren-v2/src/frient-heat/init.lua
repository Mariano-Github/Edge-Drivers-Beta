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
local battery = capabilities.battery
--local utils = require "st.utils"
local constants = require "st.zigbee.constants"

-- required module
local signal = require "signal-metrics"


local is_heat_detector = function(opts, driver, device)
  if device:get_manufacturer() == "frient A/S" and device:get_model() == "HESZB-120" then
    return true
  end
  return false
end

-- emit event defaults
local generate_event_from_zone_status = function(driver, device, zone_status, zigbee_message)
  print("<<<<< ZoneStaus >>>>>",zone_status)

  -- zone_status for Test = 0x0130
  --print("<<< zone_status:is_test_set() >>>>>", zone_status:is_test_set())
  --print("<<< zone_status:is_alarm1_set() >>>>>", zone_status:is_alarm1_set())
  --print("<<< zone_status:is_alarm2_set() >>>>>", zone_status:is_alarm2_set())

  if zone_status:is_test_set() or zone_status:is_alarm1_set() or zone_status:is_alarm2_set() then
    --device:emit_event_for_endpoint(zigbee_message.address_header.src_endpoint.value,(capabilities.smokeDetector.smoke.detected()))
    device:emit_event(capabilities.temperatureAlarm.temperatureAlarm("heat"))

  else
    --device:emit_event_for_endpoint(zigbee_message.address_header.src_endpoint.value,(capabilities.smokeDetector.smoke.clear()))
    device:emit_event(capabilities.temperatureAlarm.temperatureAlarm("cleared"))
  end

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

--- initial status
local function do_added(driver, device)
  --device:emit_event(capabilities.smokeDetector.smoke.clear())
  device:emit_event(capabilities.temperatureAlarm.temperatureAlarm("cleared"))
end

local battery_handler = function(driver, device, value, zb_rx)

  -- Emit Battery voltage event

      local minVolts = 2.3
      local maxVolts = 3.0
      
      local battery_pct = math.floor(((((value.value / 10) - minVolts) + 0.05) / (maxVolts - minVolts)) * 100)
      if battery_pct > 100 then 
        battery_pct = 100
      elseif battery_pct < 0 then
        battery_pct = 0
      end
      device:emit_event(battery.battery(battery_pct))

      -- emit signal metrics
      signal.metrics(device, zb_rx)
  end

local heat_detector = {
  NAME = "Frient Heat Detector",
  supported_capabilities = {
    --capabilities.smokeDetector,
  },
  zigbee_handlers = {
    cluster = {
      [zcl_clusters.IASZone.ID] = {
        [zcl_clusters.IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      },
      [zcl_clusters.IASZone.ID] = {
        [zcl_clusters.IASZone.server.commands.ZoneEnrollResponse.ID] = ias_zone_status_change_handler
      }
    },
    attr = {
      [zcl_clusters.IASZone.ID] = {
        [zcl_clusters.IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      },
      [zcl_clusters.PowerConfiguration.ID] = {
        [zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.ID] = battery_handler
      }
    },
  },
  lifecycle_handlers = {
    --added = do_added
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,

  can_handle = is_heat_detector
}

return heat_detector
