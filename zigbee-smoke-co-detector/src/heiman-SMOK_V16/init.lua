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

local constants = require "st.zigbee.constants"
-- required module
local configurationMap = require "configurations"
local clusters = require "st.zigbee.zcl.clusters"
local IASZone = clusters.IASZone
local IASWD = clusters.IASWD
local PowerConfiguration = clusters.PowerConfiguration
local device_management = require "st.zigbee.device_management"


local is_heiman_SMOK_V16 = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    if device:get_model() == "SMOK_V16" or 
      device:get_model() == "SmokeSensor-N" or
      device:get_model() == "SmokeSensor-N-3.0" or
      device:get_model() == "SMOK_YDLV10" or
      device:get_model() == "COSensor-EM" or
      (device:get_model() == "TS0205" and device:get_manufacturer() == "_TYZB01_wqcac7lo") or
      (device:get_model() == "TS0205" and device:get_manufacturer() == "_TZ3210_up3pngle") or
      --(device:get_model() == "TS0205" and device:get_manufacturer() == "_TZ3000_hl7yraue") or
      (device:get_model() == "TS0205" and device:get_manufacturer() == "_TYZB01_dsjszp0x") then
        local subdriver = require("heiman-SMOK_V16")
        return true, subdriver
    end
  end
  return false
end

--do Configure
  local function do_configure(self, device)
    print("<<< special configure battery 300 sec>>>")

    device:remove_configured_attribute(IASZone.ID, IASZone.attributes.ZoneStatus.ID)
    device:send(device_management.build_bind_request(device, IASWD.ID, self.environment_info.hub_zigbee_eui))
    device:send(device_management.build_bind_request(device, IASZone.ID, self.environment_info.hub_zigbee_eui))
    if (device:get_manufacturer() == "Trust" and device:get_model() == "COSensor-EM") then
      print("<<< Trust, COSensor-EM Configure>>> ")
      device:send(IASZone.attributes.ZoneStatus:configure_reporting(device, 30, 180, 1))
    end
    device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
    device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 300, 1))
    if (device:get_model() == "TS0205" and device:get_manufacturer() == "_TYZB01_wqcac7lo") then -- nedis device tht not respond to any command
      device:send(PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 30, 300, 1))
    end
    local configuration = configurationMap.get_device_configuration(device)
    if configuration ~= nil then
      for _, attribute in ipairs(configuration) do
        --device:add_configured_attribute(attribute)
        device:add_monitored_attribute(attribute)
      end
    end
    print("doConfigure performed, transitioning device to PROVISIONED") --23/12/23
    device:try_update_metadata({ provisioning_state = "PROVISIONED" })
  end

  --- do_driverSwitched
  local function do_driverSwitched(self, device) --23/12/23
    print("<<<< DriverSwitched >>>>")
    device.thread:call_with_delay(3, function(d)
      do_configure(self, device)
    end, "configure") 
 end

 
local heiman_SMOK_V16 = {
  NAME = "heiman_SMOK_V16",
  lifecycle_handlers = {
    doConfigure = do_configure,
    --driverSwitched = do_configure,
    driverSwitched = do_driverSwitched --23/12/23
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,

  can_handle = is_heiman_SMOK_V16
}

return heiman_SMOK_V16
