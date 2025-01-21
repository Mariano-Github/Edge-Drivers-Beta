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

------ Author Mariano Colmenarejo (Jan 2022) --------
------ Version 1 -----------------

-- default libraries
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
--local constants = require "st.zigbee.constants"

local write_attribute = require "st.zigbee.zcl.global_commands.write_attribute"
local zcl_messages = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local zb_const = require "st.zigbee.constants"

--- default Temperature Mesurement config
local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"
local PowerConfiguration = zcl_clusters.PowerConfiguration

-- defualt illuminance
local clusters = require "st.zigbee.zcl.clusters"
--local IlluminanceMeasurement = clusters.IlluminanceMeasurement

----  binaryinput clusters and attributes
local BasicInput = zcl_clusters.BasicInput
local data_types = require "st.zigbee.data_types"
--local cluster_base_index = require "st.zigbee.cluster_base"

local BINARY_INPUT_CLUSTER = 0x000F
local BINARY_INPUT_ATTR_ID = 0x0055
local BINARY_INPUT_ENABLE_ATTR_ID = 0x0051

-- custom capabilities declaration
local motion_Sensor_Enable = capabilities ["legendabsolute60149.motionSensorEnable"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]
--module emit signal metrics
local signal = require "signal-metrics"

-- accel count messages
local accel_count = 0


--- presence Timer handler
local function presence_timer_handler(self, device)

  ---- Timers Cancel ------
  for timer in pairs(device.thread.timers) do
    print("<<<<< Cancel all timer >>>>>")
    device:set_field("presence_timer_status", "OFF", {persist = false})
    device.thread:cancel_timer(timer)
  end

   --print("<<<<< Timer function >>>>>")
    device:set_field("presence_timer_status", "ON", {persist = false})
 
   ------ Timer activation
    device.thread:call_on_schedule(
    30,
    function ()   
    if device.preferences.logDebugPrint == true then
      print("<<<<< Timer >>>>>")
    end
     local current_time = os.time()
     local timeout_Ref = device.preferences.dcPresenceCheck * 60
     if device:get_field("power_source") == "battery" then timeout_Ref = device.preferences.battPresenceCheck * 60 end
     if device.preferences.logDebugPrint == true then
      print("Presence timeout_Ref >>>>>>>>>>>",timeout_Ref, " Sec")
      print("power_source >>>>>", device:get_field("power_source"))
      print("last_battery_value >>>>>",device:get_field("last_battery_value"))
     end
     if current_time - device:get_field("last_presence_check") >= timeout_Ref then
       if device:get_field("last_battery_value") >= device.preferences.battDisableNoPresence or device:get_field("power_source") == "dc" then
        if device:get_latest_state("main", capabilities.presenceSensor.ID, capabilities.presenceSensor.presence.NAME) ~= "not present" then
          device:emit_event(capabilities.presenceSensor.presence("not present"))
        end
        if device:get_field("motion_Sensor_Enable") == "Enabled" then
          if device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) ~= "inactive" then
            device:emit_event(capabilities.motionSensor.motion.inactive())
          end
        end
        if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "inactive" then
          device:emit_event(capabilities.accelerationSensor.acceleration("inactive"))
        end
       end
     else
      --device:emit_event(capabilities.presenceSensor.presence("present"))
     end
    end
    ,'Presence')

 end

------- Write attribute ----
local function write_attribute_function(device, cluster_id, attr_id, data_value)
  local write_body = write_attribute.WriteAttribute({
   write_attribute.WriteAttribute.AttributeRecord(attr_id, data_types.ZigbeeDataType(data_value.ID), data_value.value)})

   local zclh = zcl_messages.ZclHeader({
     cmd = data_types.ZCLCommandId(write_attribute.WriteAttribute.ID)
   })
   local addrh = messages.AddressHeader(
       zb_const.HUB.ADDR,
       zb_const.HUB.ENDPOINT,
       device:get_short_address(),
       device:get_endpoint(cluster_id.value),
       zb_const.HA_PROFILE_ID,
       cluster_id.value
   )
   local message_body = zcl_messages.ZclMessageBody({
     zcl_header = zclh,
     zcl_body = write_body
   })
   device:send(messages.ZigbeeMessageTx({
     address_header = addrh,
     body = message_body
   }))
 end


--- Binary Input Configuration
local function binary_input_configure(self, device)
  print("Enable Binary Input >>>>>>>>>>>>>>>>>>>>>>>> config")

  local data_value = {value = true, ID = 0x10}
  local cluster_id = {value = 0x000F}
  local attr_id = 0x0051
  write_attribute_function(device, cluster_id, attr_id, data_value)

--- Cofigure reports binary inputs
  print("Configure Binary Reports >>>>>>>>>>>>>>>>>>>>>>>> config")

  device:send(device_management.build_bind_request(device, BINARY_INPUT_CLUSTER, self.environment_info.hub_zigbee_eui))
  device:send(BasicInput.attributes.PresentValue:configure_reporting(device, 0, 80))
  device:send(device_management.build_bind_request(device, BINARY_INPUT_CLUSTER, self.environment_info.hub_zigbee_eui))
  device:send(BasicInput.attributes.StatusFlags:configure_reporting(device, 0, 50))

end

--- do configure device
local function do_configure(self,device)

---battery configure
 print("Battery Config >>>>>>>>>")
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  --device:send(PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 0, 10, 1))
  local changeRep = device.preferences.battChangeReported * 10
  if changeRep == nil then changeRep = 3 end
  device:send(PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 0, 1200, changeRep))

-- configure temperature reports
  local maxTime = device.preferences.temMaxTime * 60
  changeRep = device.preferences.temChangeRep * 100
  print ("Temperature maxTime y changeRep: ",maxTime, changeRep )
  device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
  device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))


--- Enable & Configure Reports binary inputs
  binary_input_configure(self, device)

--- Read Battery voltage
  device:send(PowerConfiguration.attributes.BatteryVoltage:read(device))
end

-- preferences update
local function do_preferences(self, device, event, args)
  for id, value in pairs(device.preferences) do
    --print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
     if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      if device.preferences.logDebugPrint == true then
        print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
      end
      if  id == "temMaxTime" or id == "temChangeRep" then
        local maxTime = device.preferences.temMaxTime * 60
        local changeRep = device.preferences.temChangeRep * 100
        if device.preferences.logDebugPrint == true then
          print ("Temp maxTime & changeRep: ", maxTime, changeRep)
        end
        device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
        device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))

      elseif  id == "battChangeReported" then
        local changeRep = device.preferences.battChangeReported * 10
        if changeRep == nil then changeRep = 3 end
        device:send(PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 0, 1200, changeRep))
        
        ------ Change profile multi or single tile
      elseif id == "changeProfile" then
        if device:get_field("motion_Sensor_Enable") == "Enabled" then
          if device.preferences.changeProfile == "Single" then
          device:try_update_metadata({profile = "presence-temp-motion-acc-batt"})
          elseif device.preferences.changeProfile == "Multi" then
          device:try_update_metadata({profile = "presence-temp-motion-acc-batt-multi"})
          end 
        else
          if device.preferences.changeProfile == "Single" then
            device:try_update_metadata({profile = "presence-temp-acc-batt"})
          elseif device.preferences.changeProfile == "Multi" then
            device:try_update_metadata({profile = "presence-temp-acc-batt-multi"})        
          end
        end
      elseif id == "changeProfile" and newParameterValue == true then
        device:emit_event(capabilities.accelerationSensor.acceleration("inactive"))
      end
    end
  end
end

---- init lifecycle
local function do_init(self, device)

  if device:get_field("last_presence_check") == nil then device:set_field("last_presence_check", os.time(), {persist = false}) end
  if device:get_field("presence_timer_status") == nil then device:set_field("presence_timer_status", "OFF", {persist = false}) end
  print("power_source >>>>>",device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME)) 
  if device:get_field("power_source") == nil then
    local power_source = device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME)
    if power_source == nil then power_source = "battery" end
    device:set_field("power_source", power_source, {persist = false}) 
  end
  print("Battery last >>>>",device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.battery.NAME))
  if device:get_field("last_battery_value") == nil then
    local last_battery_value = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.battery.NAME)
    if last_battery_value == nil then last_battery_value = 0 end
    device:set_field("last_battery_value", last_battery_value, {persist = false})
  end
  print("motion_Sensor_Enable >>>>>>", device:get_latest_state("main", motion_Sensor_Enable.ID, motion_Sensor_Enable.motionSensorEnable.NAME))
  if device:get_field("motion_Sensor_Enable") == nil then
    local motion_Sensor_Enabled = device:get_latest_state("main", motion_Sensor_Enable.ID, motion_Sensor_Enable.motionSensorEnable.NAME)
    if motion_Sensor_Enabled == nil then motion_Sensor_Enabled = "Enabled" end
    device:set_field("motion_Sensor_Enable", motion_Sensor_Enabled, {persist = true})
    device:emit_event(motion_Sensor_Enable.motionSensorEnable(device:get_field("motion_Sensor_Enable")))
  end

  --- Initialice Presence Timer
  presence_timer_handler(self, device)

  -- initialize signal metrics
  if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
    device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
  end

end

--- temperature event handler
local function temp_attr_handler(self, device, tempvalue, zb_rx)
  
  ---- emit presence event
  if device:get_latest_state("main", capabilities.presenceSensor.ID, capabilities.presenceSensor.presence.NAME) ~= "present" then
    device:emit_event(capabilities.presenceSensor.presence("present"))
  end
    device:set_field("last_presence_check", os.time(), {persist = false})

  --- Add custom tempOffset
  tempvalue.value = tempvalue.value + (device.preferences.temCustomOffset * 100)

  -- emit temp event by defualt libraries
  tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)
end

--- binary_Input_StatusFlags_Handler
local function binary_Input_StatusFlags_Handler(self, device, value)
  if device.preferences.logDebugPrint == true then
    print("binary_Input_StatusFlags >>>>>", value.value)
  end
  local status_Falgs = value.value

  ---- emit presence event
  if device:get_latest_state("main", capabilities.presenceSensor.ID, capabilities.presenceSensor.presence.NAME) ~= "present" then
    device:emit_event(capabilities.presenceSensor.presence("present"))
  end
    device:set_field("last_presence_check", os.time(), {persist = false})

  --- read StatusFlags value and set capabilities states
  if status_Falgs == 0 or status_Falgs == 8 then
    if device:get_field("motion_Sensor_Enable") == "Enabled" then
      if device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) ~= "inactive" then
        device:emit_event(capabilities.motionSensor.motion.inactive())
      end
    end
    --print("<<<<< Last Acc 0 and 8 =",device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME))
    if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "inactive" then
      device:emit_event(capabilities.accelerationSensor.acceleration("inactive"))
    end
    if device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME) ~= "battery" then
      device:emit_event(capabilities.powerSource.powerSource("battery"))
      device:set_field("power_source", "battery", {persist = false})
    end
  
  elseif status_Falgs == 1 then
    -- Only DC Power source true
    if device:get_field("motion_Sensor_Enable") == "Enabled" then
      if device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) ~= "inactive" then
        device:emit_event(capabilities.motionSensor.motion.inactive())
      end
    end
    if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "inactive" then
      device:emit_event(capabilities.accelerationSensor.acceleration("inactive"))
    end
    if device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME) ~= "dc" then
      device:emit_event(capabilities.powerSource.powerSource("dc"))
      device:set_field("power_source", "dc", {persist = false})
    end
  
  elseif status_Falgs == 2 then
    -- Only vibration true
    if device:get_field("motion_Sensor_Enable") == "Enabled" then
      if device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) ~= "inactive" then
        device:emit_event(capabilities.motionSensor.motion.inactive())
      end
    end
    --print("<<<<< Last Acc 2 =",device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME))
    if device.preferences.pauseAccelEvents == false then
      if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "active" then
        device:emit_event(capabilities.accelerationSensor.acceleration("active"))
      end
    end
    if device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME) ~= "battery" then
      device:emit_event(capabilities.powerSource.powerSource("battery"))
      device:set_field("power_source", "battery", {persist = false})
    end
  
  elseif status_Falgs == 3 then
    -- DC Power source and vibration true
    if device:get_field("motion_Sensor_Enable") == "Enabled" then
      if device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) ~= "inactive" then
        device:emit_event(capabilities.motionSensor.motion.inactive())
      end
    end
    if device.preferences.pauseAccelEvents == false then
      if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "active" then
        device:emit_event(capabilities.accelerationSensor.acceleration("active"))
      end
    end
    if device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME) ~= "dc" then
      device:emit_event(capabilities.powerSource.powerSource("dc"))
      device:set_field("power_source", "dc", {persist = false})
    end
  
  elseif status_Falgs == 4 then
    -- Only motion true
    if device:get_field("motion_Sensor_Enable") == "Enabled" then
      if device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) ~= "active" then
        device:emit_event(capabilities.motionSensor.motion.active())
      end
    end
    if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "inactive" then
      device:emit_event(capabilities.accelerationSensor.acceleration("inactive"))
    end
    if device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME) ~= "battery" then
      device:emit_event(capabilities.powerSource.powerSource("battery"))
      device:set_field("power_source", "battery", {persist = false})
    end
  
  elseif status_Falgs == 5 then
    -- DC Power source and motion true
    if device:get_field("motion_Sensor_Enable") == "Enabled" then
      if device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) ~= "active" then
        device:emit_event(capabilities.motionSensor.motion.active())
      end
    end
    if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "inactive" then
      device:emit_event(capabilities.accelerationSensor.acceleration("inactive"))
    end
    if device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME) ~= "dc" then
      device:emit_event(capabilities.powerSource.powerSource("dc"))
      device:set_field("power_source", "dc", {persist = false})
    end
  
  elseif status_Falgs == 6 then
    -- Motion and vibration true
    if device:get_field("motion_Sensor_Enable") == "Enabled" then device:emit_event(capabilities.motionSensor.motion.active()) end

    if device.preferences.pauseAccelEvents == false then
      if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "active" then
        device:emit_event(capabilities.accelerationSensor.acceleration("active"))
      end
    end
    if device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME) ~= "battery" then
      device:emit_event(capabilities.powerSource.powerSource("battery"))
      device:set_field("power_source", "battery", {persist = false})
    end
  
  elseif status_Falgs == 7 then
    -- DC Power source, Motion and vibration true
    if device:get_field("motion_Sensor_Enable") == "Enabled" then
      if device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) ~= "active" then
        device:emit_event(capabilities.motionSensor.motion.active())
      end
    end
    if device.preferences.pauseAccelEvents == false then
      if device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME) ~= "active" then
        device:emit_event(capabilities.accelerationSensor.acceleration("active"))
      end
    end
    if device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME) ~= "dc" then
      device:emit_event(capabilities.powerSource.powerSource("dc"))
      device:set_field("power_source", "dc", {persist = false})
    end
  end

end

--- battery_voltage_Handler
local function battery_voltage_Handler(self,device,value, zb_rx)

---- emit presence event
if device:get_latest_state("main", capabilities.presenceSensor.ID, capabilities.presenceSensor.presence.NAME) ~= "present" then
  device:emit_event(capabilities.presenceSensor.presence("present"))
end
device:set_field("last_presence_check", os.time(), {persist = false})

-- Emit Battery voltage event
device:emit_event(capabilities.voltageMeasurement.voltage(value.value / 10))

 local minVolts = device.preferences.battMinVolts
 local maxVolts = device.preferences.battMaxVolts

 local battery_pct = math.floor(((((value.value / 10) - minVolts) + 0.05) / (maxVolts - minVolts)) * 100)

 if battery_pct > 100 then 
  battery_pct = 100
 elseif battery_pct < 0 then
  battery_pct = 0
 end

 device:emit_event(capabilities.battery.battery(battery_pct))
 device:set_field("last_battery_value", battery_pct, {persist = false})

-- emit signal metrics
  signal.metrics(device, zb_rx)
end

-----BatteryPercentageRemaining_Handler
local function BatteryPercentageRemaining_Handler(self,device,value, zb_rx)
   print("<<<<<<<< Battery Percentage Remaining Received >>>>>>>>>>")
end


---- motion_Sensor_Enable_handler
local function motion_Sensor_Enable_handler(self, device, command)
  print("motion_Sensor_Enable", command.args.value)
  device:set_field("motion_Sensor_Enable", command.args.value, {persist = true})
  device:emit_event(motion_Sensor_Enable.motionSensorEnable(command.args.value))
  if command.args.value == "Disabled" then
    --device:emit_event_for_endpoint("main", capabilities.motionSensor.motion.inactive())
    if device.preferences.changeProfile == "Single" then
      device:try_update_metadata({profile = "presence-temp-acc-batt"})
    elseif device.preferences.changeProfile == "Multi" then
         device:try_update_metadata({profile = "presence-temp-acc-batt-multi"})
    end 
  else  
    if device.preferences.changeProfile == "Single" then
      device:try_update_metadata({profile = "presence-temp-motion-acc-batt"})
    elseif device.preferences.changeProfile == "Multi" then
      device:try_update_metadata({profile = "presence-temp-motion-acc-batt-multi"})
    end 
  end
end

--- do_driverSwitched
local function do_driverSwitched(self, device)
  print("<<<< DriverSwitched >>>>")
   device.thread:call_with_delay(3, function(d)
     do_configure(self, device)
     print("doConfigure performed, transitioning device to PROVISIONED")
    device:try_update_metadata({ provisioning_state = "PROVISIONED" })
   end, "configure") 
 end

----- driver template ----------
local zigbee_arrival_driver = {
  supported_capabilities = {
    motion_Sensor_Enable,
    capabilities.powerSource,
    --capabilities.battery,
  },
  lifecycle_handlers = {
    init = do_init,
    infoChanged = do_preferences,
    --driverSwitched = do_configure,
    driverSwitched = do_driverSwitched,
    doConfigure = do_configure
  },  
  capability_handlers = {
    [motion_Sensor_Enable.ID] = {
      [motion_Sensor_Enable.commands.setMotionSensorEnable.NAME] = motion_Sensor_Enable_handler,
    },
  },
  zigbee_handlers = {
    attr = {
      --[BasicInput.ID] = {
        --[BasicInput.attributes.PresentValue.ID] = binary_Input_Handler
      --},
      [tempMeasurement.ID] = {
          [tempMeasurement.attributes.MeasuredValue.ID] = temp_attr_handler
      },
      [BasicInput.ID] = {
          [BasicInput.attributes.StatusFlags.ID] = binary_Input_StatusFlags_Handler
        },
      [PowerConfiguration.ID] = {
          [PowerConfiguration.attributes.BatteryVoltage.ID] = battery_voltage_Handler
        },
      },
  },

}

--------- driver run ------
defaults.register_for_default_handlers(zigbee_arrival_driver, zigbee_arrival_driver.supported_capabilities)
local arrival = ZigbeeDriver("st-zigbee-arrival", zigbee_arrival_driver)
arrival:run()
