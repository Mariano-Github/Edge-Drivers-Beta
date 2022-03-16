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
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"

local clusters = require "st.zigbee.zcl.clusters"
local PowerConfiguration = clusters.PowerConfiguration
local device_management = require "st.zigbee.device_management"

----- Execute emit state event for sonoff ewelink with infoChanged lifecycle or timer
local function info_Changed(self,device)

 print("***** infoChanged *********")

  if device:get_manufacturer() == "eWeLink" then
    ---- Timers Cancel ------
   for timer in pairs(device.thread.timers) do
    print("<<<<< Cancel all timer >>>>>")
    device.thread:cancel_timer(timer)
   end
    ------ Timer activation
    device.thread:call_on_schedule(
    300,
   function ()
    --device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
    --device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 3600, 1))
    local last_state = device:get_latest_state("main", capabilities.contactSensor.ID, capabilities.contactSensor.contact.NAME)
    print("<<<<< Last status >>>>>> ", last_state)
    if last_state == "closed" then
      device:emit_event_for_endpoint("main", capabilities.contactSensor.contact.closed())
    else
      device:emit_event_for_endpoint("main", capabilities.contactSensor.contact.open())
    end
   end
   ,'Refresh state')
 end
end

---- driverSwitched
local function do_configure(self,device)

 device:configure()
  
end

---Driver template
local zigbee_contact_driver_template = {
  supported_capabilities = {
    capabilities.contactSensor,
    capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.refresh
  },
  lifecycle_handlers = {
    infoChanged = info_Changed,
    driverSwitched = do_configure

    },
  sub_drivers = {require("battery-overrides"),require("battery-voltage")},
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

defaults.register_for_default_handlers(zigbee_contact_driver_template, zigbee_contact_driver_template.supported_capabilities)
local zigbee_contact = ZigbeeDriver("zigbee_contact", zigbee_contact_driver_template)
zigbee_contact:run()
