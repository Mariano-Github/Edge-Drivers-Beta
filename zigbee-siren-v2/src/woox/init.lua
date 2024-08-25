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
--local battery = capabilities.battery
local constants = require "st.zigbee.constants"

-- required module
local signal = require "signal-metrics"


local is_wooxt_siren = function(opts, driver, device)
  if device:get_manufacturer() == "_TYZB01_ynsiasng" and device:get_model() == "TS0219" then
    local subdriver = require("woox")
    return true, subdriver
  end
  return false
end


local generate_event_from_zone_status = function(driver, device, zone_status, zb_rx)
  print("<< Generate event handler >>")
  --print ("<< zone_status:",zone_status)

  if zone_status:is_alarm1_set() then
    --device:emit_event(capabilities.alarm.alarm.siren())
    --device:emit_event(capabilities.alarm.alarm.strobe())
    device:emit_event(capabilities.alarm.alarm.both())
    device:emit_event(capabilities.switch.switch.on())
  else
    device:emit_event(capabilities.alarm.alarm.off())
    device:emit_event(capabilities.switch.switch.off())
  end
  -- emit signal metrics
  signal.metrics(device, zb_rx)
end

-- Default handler for zoneStatus attribute on the IAS Zone cluster
local function ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
  --print("<<< ias_zone_status_attr_handler >>>>")

  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--- Default handler for zoneStatus change handler
local function ias_zone_status_change_handler(driver, device, zb_rx)
 -- print("<<< ias_zone_status_change_handler >>>>")

  local zone_status = zb_rx.body.zcl_body.zone_status
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

local function power_source_attr_handler(driver, device, value, zb_rx)
  local PowerSource = require "st.zigbee.generated.zcl_clusters.Basic.server.attributes.PowerSource"
  local POWER_SOURCE_MAP = {
    [PowerSource.UNKNOWN]                                                 = capabilities.powerSource.powerSource.unknown,
    [PowerSource.UNKNOWN_WITH_BATTERY_BACKUP]                             = capabilities.powerSource.powerSource.unknown,
    [PowerSource.SINGLE_PHASE_MAINS]                                      = capabilities.powerSource.powerSource.mains,
    [PowerSource.THREE_PHASE_MAINS]                                       = capabilities.powerSource.powerSource.mains,
    [PowerSource.SINGLE_PHASE_MAINS_WITH_BATTERY_BACKUP]                  = capabilities.powerSource.powerSource.mains,
    [PowerSource.THREE_PHASE_MAINS_WITH_BATTERY_BACKUP]                   = capabilities.powerSource.powerSource.mains,
    [PowerSource.EMERGENCY_MAINS_CONSTANTLY_POWERED]                      = capabilities.powerSource.powerSource.mains,
    [PowerSource.EMERGENCY_MAINS_AND_TRANSFER_SWITCH]                     = capabilities.powerSource.powerSource.battery, -- modified from mains
    [PowerSource.EMERGENCY_MAINS_CONSTANTLY_POWERED_WITH_BATTERY_BACKUP]  = capabilities.powerSource.powerSource.mains,
    [PowerSource.EMERGENCY_MAINS_AND_TRANSFER_SWITCH_WITH_BATTERY_BACKUP] = capabilities.powerSource.powerSource.mains,
    [PowerSource.BATTERY]                                                 = capabilities.powerSource.powerSource.battery,
    [PowerSource.BATTERY_WITH_BATTERY_BACKUP]                             = capabilities.powerSource.powerSource.battery,
    [PowerSource.DC_SOURCE]                                               = capabilities.powerSource.powerSource.dc,
    [PowerSource.DC_SOURCE_WITH_BATTERY_BACKUP]                           = capabilities.powerSource.powerSource.dc
  }

  if POWER_SOURCE_MAP[value.value] then
    device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, POWER_SOURCE_MAP[value.value]())
  end
end

local woox_siren = {
  NAME = "Woox Siren",
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
      [zcl_clusters.Basic.ID] = {
        [zcl_clusters.Basic.attributes.PowerSource.ID] = power_source_attr_handler
      }
    },
  },
  lifecycle_handlers = {
    --added = do_added
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,

  can_handle = is_wooxt_siren
}

return woox_siren
