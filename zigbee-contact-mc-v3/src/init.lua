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
local utils = require "st.utils"
local configurationMap = require "configurations"

local clusters = require "st.zigbee.zcl.clusters"
--local PowerConfiguration = clusters.PowerConfiguration
local device_management = require "st.zigbee.device_management"
local tempMeasurement = clusters.TemperatureMeasurement
local battery_defaults = require "st.zigbee.defaults.battery_defaults"

local multi_utils = require "multi_utils"
local data_types = require "st.zigbee.data_types"
local SAMJIN_MFG = 0x1241
local SMARTTHINGS_MFG = 0x110A
local CENTRALITE_MFG = 0x104E
--module emit signal metrics
local signal = require "signal-metrics"

local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

-- configure accel threshold
local function configure_accel_threshold (self,device)
  print("<<<<< configure_accel_threshold >>>>>")
  if device:get_manufacturer() == "Samjin" then
      local accelThreshold = device.preferences.accelThreshold
      device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, accelThreshold, SAMJIN_MFG))
  elseif device:get_manufacturer() == "Centralite" then
      local accelThreshold = device.preferences.accelThresholdCentralite
      device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, accelThreshold, CENTRALITE_MFG))  
  elseif device:get_manufacturer() == "SmartThings" then
      local accelThreshold = device.preferences.accelThresholdST
      device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, 0x01, SMARTTHINGS_MFG))
      device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_ATTR, data_types.Uint16, accelThreshold, SMARTTHINGS_MFG))
  end
end

----- Update prefeence changes
local function info_Changed(self,device)

 print("***** infoChanged *********")
  ----- Execute emit state event for sonoff ewelink with infoChanged lifecycle or timer
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

 -- update preferences
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
            --device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
            device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))

          --change profile tile
        elseif id == "changeTempProfile" then
            if device.preferences.changeTempProfile == "Contact" then
              device:try_update_metadata({profile = "contact-profile"})
            elseif device.preferences.changeTempProfile == "Temp" then
              device:try_update_metadata({profile = "temp-contact-profile"})
            end
        elseif id == "changeProfile" then
          ------ Set profile to aceleration or multiporpuse device
          print("<<< changeProfile >>>")
          if device.preferences.changeProfile == "Yes" or device.preferences.changeProfile == "Accel" then
            print("<<< Accel >>>")
            device:try_update_metadata({profile = "st-acceleration"})
          elseif device.preferences.changeProfile == "No" or device.preferences.changeProfile == "Multi" then
            print("<<< Multi >>>")
            device:try_update_metadata({profile = "st-multipurpose"})
          elseif device.preferences.changeProfile == "Temp" then
            print("<<< Temp >>>")
            device:try_update_metadata({profile = "st-temp-multipurpose"})
          end
        elseif id == "accelThreshold" or id == "accelThresholdCentralite" or id == "accelThresholdST" then
          configure_accel_threshold (self, device)
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
  if device:get_manufacturer() == "eWeLink" or device:get_manufacturer() == "_TZ3000_f1hmoyj4" then -- configuration of battery 600 sec for no offline
    print("<<< special configure battery 600 sec >>>")
    local configuration = configurationMap.get_device_configuration(device)
    if configuration ~= nil then
      for _, attribute in ipairs(configuration) do
        device:add_configured_attribute(attribute)
        device:add_monitored_attribute(attribute)
      end
    end
  else
    device:configure()
  end
  --device:configure()
  if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
    local maxTime = device.preferences.maxTime * 60
    local changeRep = device.preferences.changeRep
    print ("maxTime:", maxTime, "changeRep:", changeRep)
    device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
  end
  if device:get_manufacturer() == "Ecolink" or 
    device:get_manufacturer() == "frient A/S" or
    device:get_manufacturer() == "Sercomm Corp." or
    device:get_manufacturer() == "Universal Electronics Inc" or
    device:get_manufacturer() == "SmartThings" or
    device:get_manufacturer() == "Leedarson" or
    device:get_manufacturer() == "CentraLite" then
      
    -- init battery voltage
    battery_defaults.build_linear_voltage_init(2.3, 3.0)
    
    --- Read Battery voltage
    device:send(clusters.PowerConfiguration.attributes.BatteryVoltage:read(device))
  end
end

-- init 
local function do_init(self, device)
    --change profile tile
    if device.preferences.changeTempProfile == "Contact" then
      device:try_update_metadata({profile = "contact-profile"})
    elseif device.preferences.changeTempProfile == "Temp" then
      device:try_update_metadata({profile = "temp-contact-profile"})

    ------ Set profile to aceleration or multiporpuse device
    elseif device.preferences.changeProfile == "Yes" or device.preferences.changeProfile == "Accel" then
      device:try_update_metadata({profile = "st-acceleration"})
    elseif device.preferences.changeProfile == "No" or device.preferences.changeProfile == "Multi" then
      device:try_update_metadata({profile = "st-multipurpose"})
    elseif device.preferences.changeProfile == "Temp" then
      device:try_update_metadata({profile = "st-temp-multipurpose"})
    end

    if device:get_manufacturer() == "Ecolink" or 
      device:get_manufacturer() == "frient A/S" or
      device:get_manufacturer() == "Sercomm Corp." or
      device:get_manufacturer() == "Universal Electronics Inc" or
      device:get_manufacturer() == "SmartThings" or
      device:get_manufacturer() == "Leedarson" or
      device:get_manufacturer() == "CentraLite" then
        
      -- init battery voltage
      battery_defaults.build_linear_voltage_init(2.3, 3.0)

      --- Read Battery voltage
      device:send(clusters.PowerConfiguration.attributes.BatteryVoltage:read(device))

    elseif device:get_manufacturer() == "eWeLink" or device:get_manufacturer() == "_TZ3000_f1hmoyj4" then -- configuration of battery 600 sec for no offline
      print("<<< special configure battery 600 sec >>>")
      local configuration = configurationMap.get_device_configuration(device)
      if configuration ~= nil then
        for _, attribute in ipairs(configuration) do
          device:add_configured_attribute(attribute)
          device:add_monitored_attribute(attribute)
        end
      end
    end
    if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
      device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
    end
end

-- battery_percentage_handler
local function battery_percentage_handler(driver, device, raw_value, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)

  print("raw_value >>>>",raw_value.value)
  local percentage = utils.clamp_value(utils.round(raw_value.value / 2), 0, 100)
  device:emit_event(capabilities.battery.battery(percentage))
end

---Driver template
local zigbee_contact_driver_template = {
  supported_capabilities = {
    capabilities.contactSensor,
    --capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.threeAxis,
    capabilities.accelerationSensor,
    capabilities.refresh
  },
  lifecycle_handlers = {
    infoChanged = info_Changed,
    driverSwitched = do_configure,
    init = do_init,
    doConfigure = do_configure

    },
    zigbee_handlers = {
      attr = {
        [clusters.PowerConfiguration.ID] = {
          [clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_percentage_handler
        }
     }
    },
  sub_drivers = {require("battery-overrides"),require("battery-voltage"),require("temperature"),require("multi-contact")},
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

defaults.register_for_default_handlers(zigbee_contact_driver_template, zigbee_contact_driver_template.supported_capabilities)
local zigbee_contact = ZigbeeDriver("zigbee_contact", zigbee_contact_driver_template)
zigbee_contact:run()
