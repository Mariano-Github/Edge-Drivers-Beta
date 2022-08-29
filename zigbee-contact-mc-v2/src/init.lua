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
local tempMeasurement = clusters.TemperatureMeasurement

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
 local have_temperature = "no"
 if device:get_manufacturer() == "ORVIBO" then
   have_temperature = "yes"
 elseif device:get_manufacturer() == "Aurora" then
   have_temperature = "yes"
 elseif device:get_manufacturer() == "HEIMAN" then
   have_temperature = "yes"
 elseif device:get_manufacturer() == "Visonic" then
   have_temperature = "yes"  
 elseif device:get_manufacturer() == "TUYATEC-xnoof3ts" then
   have_temperature = "yes"
  elseif device:get_manufacturer() == "Universal Electronics Inc" then
    have_temperature = "yes"
  elseif device:get_manufacturer() == "Sercomm Corp." then
    have_temperature = "yes"
 end
 
 if have_temperature == "yes" then
  local manufacturer = device:get_manufacturer()
  local model =device:get_model()
  print("Manufacturer, Model",manufacturer, model)
  for id, value in pairs(device.preferences) do
   print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
   local oldPreferenceValue = device:get_field(id)
   local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
     device:set_field(id, newParameterValue, {persist = true})
     print("<< Preference changed name:", id, "old value:", oldPreferenceValue, "new value:", newParameterValue)
     if  id == "maxTime" or id == "changeRep" then
       local maxTime = device.preferences.maxTime * 60
       local changeRep = device.preferences.changeRep
        print ("maxTime:", maxTime,"changeRep:", changeRep)
         device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
         device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
      --change profile tile
     elseif id == "changeTempProfile" then
        if device.preferences.changeTempProfile == "Contact" then
          device:try_update_metadata({profile = "contact-profile"})
        elseif device.preferences.changeTempProfile == "Temp" then
          device:try_update_metadata({profile = "temp-contact-profile"})
        end
     end
    end
 end
end
 --print manufacturer, model and leng of the strings
   local manufacturer = device:get_manufacturer()
   local model = device:get_model()
   local manufacturer_len = string.len(manufacturer)
   local model_len = string.len(model)
 
   print("Device ID", device)
   print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
   print("Model >>>", model,"Model_len >>>",model_len) 
   -- This will print in the log the total memory in use by Lua in Kbytes
   print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")

   local firmware_full_version = device.data.firmwareFullVersion
   if firmware_full_version == nil then firmware_full_version = "Unknown" end
   print("<<<<< Firmware Version >>>>>",firmware_full_version)
end

---- driverSwitched
local function do_configure(self,device)

   device:configure()
  
end

-- i it 
local function do_init(self, device)
    --change profile tile
    if device.preferences.changeTempProfile == nil then return end
    if device.preferences.changeTempProfile == "Contact" then
      device:try_update_metadata({profile = "contact-profile"})
    elseif device.preferences.changeTempProfile == "Temp" then
      device:try_update_metadata({profile = "temp-contact-profile"})
    end
end

---Driver template
local zigbee_contact_driver_template = {
  supported_capabilities = {
    capabilities.contactSensor,
    --capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.refresh
  },
  lifecycle_handlers = {
    infoChanged = info_Changed,
    driverSwitched = do_configure,
    init = do_init

    },
  sub_drivers = {require("battery-overrides"),require("battery-voltage"),require("temperature")},
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

defaults.register_for_default_handlers(zigbee_contact_driver_template, zigbee_contact_driver_template.supported_capabilities)
local zigbee_contact = ZigbeeDriver("zigbee_contact", zigbee_contact_driver_template)
zigbee_contact:run()
