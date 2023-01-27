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
local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local utils = require "st.utils"
local IlluminanceMeasurement = clusters.IlluminanceMeasurement

--- Temperature Mesurement config Samjin
local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"

local signal = require "signal-metrics"
local write = require "writeAttribute"

-- custom capabilities
local sensor_Sensitivity = capabilities["legendabsolute60149.sensorSensitivity"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

-- preferences update
local function do_preferences(self, device)
  print("***** infoChanged *********")

  if device:get_model() == "MS01" or device:get_model() == "ms01" then
    ---- Timers Cancel ------
   for timer in pairs(device.thread.timers) do
    print("<<<<< Cancel all timer >>>>>")
    device.thread:cancel_timer(timer)
   end
    ------ Timer activation
    device.thread:call_on_schedule(
    300,
   function ()
    local last_state = device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME)
    print("<<<<< Last status >>>>>> ", last_state)
    if last_state == "active" then
      device:emit_event_for_endpoint("main", capabilities.motionSensor.motion.active())
    else
      device:emit_event_for_endpoint("main", capabilities.motionSensor.motion.inactive())
    end
   end
   ,'Refresh state')
 end
  
   for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
     if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
      if  id == "maxTime" or id == "changeRep" then
        local maxTime = device.preferences.maxTime * 60
        local changeRep = device.preferences.changeRep
         print ("maxTime y changeRep: ", maxTime, changeRep)
          --device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
          device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))

      --- Configure motionSensitivity IAS cluster 0x0500 and attribute 0013 
      elseif id == "motionSensitivity" then
        print("<<< Write Sensitivity Level >>>")
        local value_send = newParameterValue
        local data_value = {value = value_send, ID = 0x20}
        local cluster_id = {value = 0x0500}
        --write atribute for zigbee standard devices
        local attr_id = 0x0013
        write.write_attribute_function(device, cluster_id, attr_id, data_value)

        device.thread:call_with_delay(3, function(d)
          --device:send_to_component("main", zcl_clusters.Basic.attributes.ApplicationVersion:read(device))
          device:send_to_component("main", zcl_clusters.IASZone.attributes.CurrentZoneSensitivityLevel:read(device))
          device:send_to_component("main", zcl_clusters.IASZone.attributes.NumberOfZoneSensitivityLevelsSupported:read(device))
        end)
      end
     end
  end

   --print manufacturer, model and leng of the strings
   local manufacturer = device:get_manufacturer()
   local model = device:get_model()
   local manufacturer_len = string.len(manufacturer)
   local model_len = string.len(model)
 
   print("Device ID >>>", device)
   print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
   print("Model >>>", model,"Model_len >>>",model_len)
   --print("Firmware >>>",firmware)
   -- This will print in the log the total memory in use by Lua in Kbytes
   print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- do_configure
local function do_configure(self,device)
  device:configure() -- mod (09/01/2023)
  if device:get_manufacturer() == "frient A/S" or 
      device:get_manufacturer() == "IKEA of Sweden" or
      device:get_manufacturer() == "SmartThings" or
      device:get_manufacturer() == "Bosch" or
      device:get_manufacturer() == "Konke" or
      device:get_manufacturer() == "NYCE"  or
      device:get_manufacturer() == "CentraLite" or
      device:get_manufacturer() == "Universal Electronics Inc" or
      device:get_manufacturer() == "Visonic" or
      (device:get_manufacturer() == "iMagic by GreatStar" and device:get_model() == "1117-S") then

        device:send(device_management.build_bind_request(device, zcl_clusters.PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
        device:send(zcl_clusters.PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 30, 21600, 1))
  end

    --- Configure motionSensitivity IAS cluster 0x0500 and attribute 0013
    if device.preferences.motionSensitivity ~= nil then
      print("<<< Write Sensitivity Level >>>")
      local value_send = device.preferences.motionSensitivity
      local data_value = {value = value_send, ID = 0x20}
      local cluster_id = {value = 0x0500}
      local attr_id = 0x0013
      write.write_attribute_function(device, cluster_id, attr_id, data_value)
    end

  device.thread:call_with_delay(4, function(d)
    --device:send_to_component("main", zcl_clusters.Basic.attributes.ApplicationVersion:read(device))
    device:send_to_component("main", zcl_clusters.IASZone.attributes.CurrentZoneSensitivityLevel:read(device))
    device:refresh()
  end)

end

local function applicationVersion_handler(self, device, value, zb_rx)
  print("Firmware >>>>>>>>>",value.value)
  --print("zb_rx >>>>>>",utils.stringify_table(zb_rx))
  local body = zb_rx.body.zcl_body.attr_records
  --print("body >>>>>>",utils.stringify_table(body))
  local status = body[1].status.value
  print("<<<<<< applicationVersion_handler Status >>>>>>>",status)

end

local function currentZoneSensitivityLevel_handler(self, device, value, zb_rx)
  print("currentZoneSensitivityLevel >>>>>>>>>",value.value)
  local sensitivity = tostring(value.value)
  device:emit_event(sensor_Sensitivity.sensorSensitivity(sensitivity))

  local body = zb_rx.body.zcl_body.attr_records
  --print("body >>>>>>",utils.stringify_table(body))
  local status = body[1].status.value
  print("<<<<<< currentZoneSensitivityLevel Status >>>>>>>",status)

    -- emit signal metrics
    signal.metrics(device, zb_rx)
end

--- NumberOfZoneSensitivityLevelsSupported_handler
local function NumberOfZoneSensitivityLevelsSupported_handler(self, device, value, zb_rx)
  print("NumberOfZoneSensitivityLevelsSupported >>>>>>>>>",value.value)
end

local function do_init(self, device)
  --print("<<<<< do_init for Main int.lua >>>>>>")

  if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
    device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
  end

  do_configure(self,device)
end

--- sensor_Sensitivity_handler
local function sensor_Sensitivity_handler(self, device, command)
  print("command.args.value >>>>>", command.args.value)

  if command.args.value == "Read" then
    device:emit_event(sensor_Sensitivity.sensorSensitivity("Read Attribute"))
    --- Read firmware version and sensor_Sensitivity
    --device:send_to_component("main", zcl_clusters.Basic.attributes.ApplicationVersion:read(device))
    device:send_to_component("main", zcl_clusters.IASZone.attributes.CurrentZoneSensitivityLevel:read(device))
    device:send_to_component("main", zcl_clusters.IASZone.attributes.NumberOfZoneSensitivityLevelsSupported:read(device))
  end
end

-- battery_percentage_handler
local function battery_percentage_handler(driver, device, raw_value, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)

  if device:get_manufacturer() == "Samjin" then
    local raw_percentage = raw_value.value - (200 - raw_value.value) / 2
    print("raw_value >>>>",raw_value.value)
    print("raw_percentage >>>>",raw_percentage)
    local percentage = utils.clamp_value(utils.round(raw_percentage / 2), 0, 100)
    device:emit_event(capabilities.battery.battery(percentage))
  else
    local percentage = utils.clamp_value(utils.round(raw_value.value / 2), 0, 100)
    device:emit_event(capabilities.battery.battery(percentage))
  end
end

--- do_driverSwitched
local function do_driverSwitched(self, device)
  --device:configure() -- mod (09/01/2023)
  if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
    local maxTime = device.preferences.maxTime * 60
    local changeRep = device.preferences.changeRep
    print ("maxTime:", maxTime, "changeRep:", changeRep)
    device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
    --device.thread:call_with_delay(2, function() device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep)) end)
    device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
  end
  do_configure(self, device)
end

local zigbee_motion_driver = {
  supported_capabilities = {
    capabilities.motionSensor,
    --capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.battery,
    capabilities.presenceSensor,
    capabilities.contactSensor,
    capabilities.occupancySensor,
    capabilities.illuminanceMeasurement,
    capabilities.powerSource,
    capabilities.refresh
  },
  lifecycle_handlers = {
    init = do_init,
    infoChanged = do_preferences,
    driverSwitched = do_driverSwitched,
    --driverSwitched = do_configure,
    --doConfigure = do_configure
},
capability_handlers = {
  [sensor_Sensitivity.ID] = {
    [sensor_Sensitivity.commands.setSensorSensitivity.NAME] = sensor_Sensitivity_handler,
  }
},
zigbee_handlers = {
  attr = {
    --[zcl_clusters.Basic.ID] = {
       --[zcl_clusters.Basic.attributes.ApplicationVersion.ID] = applicationVersion_handler
    --},
    [zcl_clusters.IASZone.ID] = {
      [zcl_clusters.IASZone.attributes.CurrentZoneSensitivityLevel.ID] = currentZoneSensitivityLevel_handler,
      [zcl_clusters.IASZone.attributes.NumberOfZoneSensitivityLevelsSupported.ID] = NumberOfZoneSensitivityLevelsSupported_handler
    },
    [zcl_clusters.PowerConfiguration.ID] = {
      [zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_percentage_handler
    }
 }
},
  sub_drivers = { require("aurora"),
                  require("ikea"),
                  --require("iris"),
                  require("tuya"),
                  require("gatorsystem"),
                  require("motion_timeout"),
                  require("nyce"),
                  require("zigbee-plugin-motion-sensor"),
                  require("battery"),
                  require("temperature"),
                  require("frient")
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

defaults.register_for_default_handlers(zigbee_motion_driver, zigbee_motion_driver.supported_capabilities)
local motion = ZigbeeDriver("zigbee-motion", zigbee_motion_driver)
motion:run()
