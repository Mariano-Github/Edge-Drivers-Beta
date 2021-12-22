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

------ Author Mariano Colmenarejo (Dec 2021) --------

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"

--- Temperature Mesurement config Samjin
local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"

-- preferences update
local function do_preferences(self, device)
 if device:get_manufacturer() == "Samjin" then 
  local maxTime = device.preferences.maxTime * 60
  local changeRep = device.preferences.changeRep * 100
  print ("maxTime y changeRep: ", maxTime, changeRep)
    device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
    device:configure()
 end
end

----- driver template ----------
local zigbee_moisture_driver = {
  supported_capabilities = {
    capabilities.waterSensor,
    capabilities.battery,
  },
  lifecycle_handlers = {
    infoChanged = do_preferences
},  
  sub_drivers = {require("samjin")},
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

--------- driver run ------
defaults.register_for_default_handlers(zigbee_moisture_driver, zigbee_moisture_driver.supported_capabilities)
local moisture = ZigbeeDriver("st-zigbee-moisture", zigbee_moisture_driver)
moisture:run()
