-- Copyright 2022 SmartThings
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
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.CommandClass.Configuration
--local Configuration = (require "st.zwave.CommandClass.Configuration")({ version= 1 })
--- @type st.zwave.CommandClass.Association
-- local Association = (require "st.zwave.CommandClass.Association")({ version= 2 })
--- @type st.zwave.CommandClass.Notification
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3}) --- v8 in documentation v3 in lua defaults
local log = require "log"
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass.SwitchMultilevel
--local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({version=4,strict=true})
--local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({ version= 1 })
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=2,strict=true})
local Basic = (require "st.zwave.CommandClass.Basic")({version=1, strict=true})
local SensorMultilevel = (require "st.zwave.CommandClass.SensorMultilevel")({ version = 11 })


local preferences = require "preferences"
--local configurations = require "configurations"
local refresh_thermostat = require "refresh-thermostat"
--local child_devices = require "child-devices"

------ Endpoints list
-- 1: Input 1 – Notification
-- 2: Input 2 – Notification
-- 3: Analog Input 1 – Voltage Level
-- 4: Analog Input 2 – Voltage Level
-- 5: Output 1
-- 6: Output 2
-- 7: Temperature – internal sensor
-- 8 to 13: Temperature – external sensor DS18B20 No 1-6 (when DS18S20 sensors connected)
-- 8: Temperature – external sensor DHT22  (when DHT22 sensor connected)
-- 9: Humidity – external sensor DHT22  (when DHT22 sensor connected)

------ Notification Command Class: 
-- EndPoint 1,2: Notification Type: Home Security [0x07]  Event: Intrusion Unknown Location [0x02]
-- EndPoint 7: Notification Type: System [0x09]  Event: System hardware failure with manufacturer proprietary failure code [0x03]
-- EndPoint 9: Notification Type: System [0x09]  Event: System hardware failure [0x01]

------- Association Groups:
-- Association Group 1: Hub

------- C.C. Mapping:
-- EndPoint 1: Basic Set, Basic Get, Basic Report
-- EnpPoints 3-4 and 7-13: Sensor Multilevel Get, Sensor Multilevel Report
-- EnpPoints 5-6: Switch BInary Get, Switch BInary Report


-- assign component_to_endpoint
local function component_to_endpoint(device, component_id)
  if component_id == "main" then
    if device.preferences.changeProfileExtTemp == "10" then
      return {8}
    else
      return {7}
    end
  elseif component_id == "externalTemp1" then
    return {8}
  elseif component_id == "externalTemp2" then
    return {9}
  elseif component_id == "externalTemp3" then
    return {10}
  elseif component_id == "externalTemp4" then
    return {11}
  elseif component_id == "externalTemp5" then
    return {12}
  elseif component_id == "externalTemp6" then
    return {13}
  elseif component_id == "out1" then
    return {5}
  elseif component_id == "out2" then
    return {6}
  elseif component_id == "in1" then
    return {1}
  elseif component_id == "in2" then
    return {2}
  elseif component_id == "analog1" then
    return {3}
  elseif component_id == "analog2" then
    return {4}
  end
end

-- assign endpoint_to_component
local function endpoint_to_component(device, ep)
  if ep == 5 then
    return "out1"
  elseif ep == 6 then
    return "out2"
  elseif ep == 1 then
    return "in1"
  elseif ep == 2 then
    return "in2"
  elseif ep == 3 then
    return "analog1"
  elseif ep == 4 then
    return "analog2"
  elseif ep == 8 then
    if device.preferences.changeProfileExtTemp == "10" then
      return "main"
    else
      return "externalTemp1"
    end
  elseif ep == 9 then
    return "externalTemp2"
  elseif ep == 10 then
    return "externalTemp3"
  elseif ep == 11 then
    return "externalTemp4"
  elseif ep == 12 then
    return "externalTemp5"
  elseif ep == 13 then
    return "externalTemp6"
  elseif ep == 7 then
    if device.preferences.changeProfileExtTemp ~= "10" then
      return "main"
    end
  end
end

--- Handle preference changes
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param event table
--- @param args
local function info_changed(self, device, event, args)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    --preferences.update_preferences(self, device, args)
    preferences.do_preferences(self, device, args)
  end
end

-- lifecycle init
local function device_init(self, device)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)

    -- set selected profile
    if device.preferences.changeProfileExtTemp == "1" or device.preferences.changeProfileExtTemp == nil then
      device:try_update_metadata({profile = "fibaro-smart-implant-temp"})
    elseif device.preferences.changeProfileExtTemp == "2" then
      device:try_update_metadata({profile = "fibaro-smart-implant-temp-2"})
    elseif device.preferences.changeProfileExtTemp == "3" then
      device:try_update_metadata({profile = "fibaro-smart-implant-temp-3"})
    elseif device.preferences.changeProfileExtTemp == "4" then
      device:try_update_metadata({profile = "fibaro-smart-implant-temp-4"})
    elseif device.preferences.changeProfileExtTemp == "5" then
      device:try_update_metadata({profile = "fibaro-smart-implant-temp-5"})
    elseif device.preferences.changeProfileExtTemp == "6" then
      device:try_update_metadata({profile = "fibaro-smart-implant-temp-6"})
    elseif device.preferences.changeProfileExtTemp == "0" then
      if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
        device:try_update_metadata({profile = "smart-implant-two-switch"})
      elseif device.preferences.deviceTile == true then
        device:try_update_metadata({profile = "smart-implant-two-switch-multi"})
      end
    elseif device.preferences.changeProfileExtTemp == "7" then
      if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
        device:try_update_metadata({profile = "smart-implant-two-contact-switch"})
      elseif device.preferences.deviceTile == true then
        device:try_update_metadata({profile = "smart-implant-two-contact-switch-multi"})
      end
    elseif device.preferences.changeProfileExtTemp == "8" then
      if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
        device:try_update_metadata({profile = "smart-implant-two-motion-switch"})
      elseif device.preferences.deviceTile == true then
        device:try_update_metadata({profile = "smart-implant-two-motion-switch-multi"})
      end
    elseif device.preferences.changeProfileExtTemp == "9" then
      if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
        device:try_update_metadata({profile = "smart-implant-two-analog"})
      elseif device.preferences.deviceTile == true then
        device:try_update_metadata({profile = "smart-implant-two-analog-multi"})
      end
    elseif device.preferences.changeProfileExtTemp == "10" then
      if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
        device:try_update_metadata({profile = "smart-implant-temp-two-contact-switch"})
      elseif device.preferences.deviceTile == true then
        device:try_update_metadata({profile = "smart-implant-temp-two-contact-switch-multi"})
      end
    elseif device.preferences.changeProfileExtTemp == "11" then
      if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
        device:try_update_metadata({profile = "smart-implant-analog-contact-switch"})
      elseif device.preferences.deviceTile == true then
        device:try_update_metadata({profile = "smart-implant-analog-contact-switch-multi"})
      end
    elseif device.preferences.changeProfileExtTemp == "12" then
      if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
        device:try_update_metadata({profile = "smart-implant-temp-two-motion-switch"})
      elseif device.preferences.deviceTile == true then
        device:try_update_metadata({profile = "smart-implant-temp-two-motion-switch-multi"})
      end
    elseif device.preferences.changeProfileExtTemp == "13" then
      device:try_update_metadata({profile = "smart-implant-temp-3-two-contact-switch"})
    end

    device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)

  end
end

-- Temperature handler
local function sensorMultilevel_report_handler(self, device, cmd)
  print("<< sensorMultilevel_report_handler >>")

     --profiles:
        --"0" : "intTem + Double Switch"
        --"1" : "intTem + 1 External Temp Probe"
        --"2" : "intTem + 2 External Temp Probe"
        --"3" : "intTem + 3 External Temp Probe"
        --"4" : "intTem + 4 External Temp Probe"
        --"5" : "intTem + 5 External Temp Probe"
        --"6" : "intTem + 6 External Temp Probe"
        --"7" : "intTem + 2 Contact Sensors + 2 Switch"
        --"8" : "intTem + 2 Motion Sensors + 2 Switch"
        --"9" : "intTem + 2 Analog Inputs + 2 Switch"
        --"10" : "Ext Temp + 2 Contact + 2 Switch"
        --"11" : "intTem + 1 Analog + 1 Contact + 2 Switch"
        --"12" : "Ext Temp + 2 Motion + 2 Switch"
        --"13" : "intTem + 3 Ext Temp + 2 Contact + 2 Switch"

  if (cmd.args.sensor_type == SensorMultilevel.sensor_type.TEMPERATURE) then
    print("<< Temperature_report_handler >>")
    -- if internal temp and profile = 10 then exit and nor emit temp event
    local profile_number = tonumber(device.preferences.changeProfileExtTemp)
    print("<<<< profile_number:",profile_number)

    local custom_temp = cmd.args.sensor_value
    if cmd.src_channel == 0 then return end
    if cmd.src_channel == 7 then  -- Internal temperature
      if profile_number == 10 or profile_number == 12 then return end
      if device.preferences.internalTempOffset ~= nil then
        custom_temp = custom_temp + device.preferences.internalTempOffset
      end
    elseif cmd.src_channel == 8 then -- Externaltemperature 1
      --if profile_number == 0 or (profile_number > 6 and profile_number ~= 10) then return end
      if profile_number == 0 or profile_number == 11 or (profile_number > 6 and profile_number < 10) then return end
      if device.preferences.externalTempOffset1 ~= nil then -- Externaltemperature 1
        custom_temp = custom_temp + device.preferences.externalTempOffset1
      end
    elseif cmd.src_channel == 9 then -- Externaltemperature 2
      if profile_number == 0 or (profile_number > 6 and profile_number ~= 13) then return end
      if device.preferences.externalTempOffset2 ~= nil then -- Externaltemperature 2
        custom_temp = custom_temp + device.preferences.externalTempOffset2
      end
    elseif cmd.src_channel == 10 then -- Externaltemperature 3
      if profile_number == 0 or (profile_number > 6 and profile_number ~= 13) then return end
      if device.preferences.externalTempOffset3 ~= nil then -- Externaltemperature 3
        custom_temp = custom_temp + device.preferences.externalTempOffset3
      end
    elseif cmd.src_channel == 11 then -- Externaltemperature 4
      if profile_number == 0 or profile_number > 6 then return end
      if device.preferences.externalTempOffset4 ~= nil then -- Externaltemperature 4
        custom_temp = custom_temp + device.preferences.externalTempOffset4
      end
    elseif cmd.src_channel == 12 then -- Externaltemperature 5
      if profile_number == 0 or profile_number > 6 then return end
      if device.preferences.externalTempOffset5 ~= nil then -- Externaltemperature 5
        custom_temp = custom_temp + device.preferences.externalTempOffset5
      end
    elseif cmd.src_channel == 13 then -- Externaltemperature 6
      if profile_number == 0 or profile_number > 6 then return end
      if device.preferences.externalTempOffset6 ~= nil then -- Externaltemperature 6
        custom_temp = custom_temp + device.preferences.externalTempOffset6
      end
    end

    local scale = 'C'
    if (cmd.args.scale == SensorMultilevel.scale.temperature.FAHRENHEIT) then scale = 'F' end
    device:emit_event_for_endpoint(cmd.src_channel, capabilities.temperatureMeasurement.temperature({value = custom_temp, unit = scale}))

    -- save new temperature for Thermostat Child device
    local component= endpoint_to_component(device, cmd.src_channel)

    print("<<<< device.preferences.changeProfileExtTemp:", device.preferences.changeProfileExtTemp)
    print("<<<< component= endpoint_to_component:", component)

    local child_device = device:get_child_by_parent_assigned_key(component)
    if child_device ~= nil and child_device.preferences.changeProfileTherm ~= nil then
      child_device:set_field("last_temp", custom_temp, {persist = false})
      child_device:set_field("stateUnit", scale, {persist = false})
      child_device:emit_event(capabilities.temperatureMeasurement.temperature({value = custom_temp, unit = scale}))

      -- thermostat calculations
      refresh_thermostat.thermostat_data_check (self, child_device)
    end
  elseif cmd.args.sensor_type == SensorMultilevel.sensor_type.VOLTAGE then
    print("<< voltage_report_handler >>")
    local voltageValue = cmd.args.sensor_value
    if cmd.args.scale == SensorMultilevel.scale.voltage.MILLIVOLTS then
      voltageValue = cmd.args.sensor_value * 0.0001
    end
    local scale = 'V'
    device:emit_event_for_endpoint(cmd.src_channel, capabilities.voltageMeasurement.voltage({value = voltageValue, unit = scale}))

    -- emit chil device event
    local component= endpoint_to_component(device, cmd.src_channel)
    local child_device = device:get_child_by_parent_assigned_key(component)
    if child_device ~= nil and child_device.preferences.profileType == "voltage" then
      child_device:emit_event(capabilities.voltageMeasurement.voltage({value = voltageValue, unit = scale}))
    end
  end
end

local initial_events_map = {
  [capabilities.waterSensor.ID] = capabilities.waterSensor.water.dry(),
  [capabilities.contactSensor.ID] = capabilities.contactSensor.contact.closed(),
  [capabilities.smokeDetector.ID] = capabilities.smokeDetector.smoke.clear(),
  [capabilities.motionSensor.ID] = capabilities.motionSensor.motion.inactive(),
}

-- lifecycle Added
local function added_handler(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    for id, event in pairs(initial_events_map) do
      if device:supports_capability_by_id(id) then
        device:emit_event(event)
      end
    end
    device:refresh()
  elseif device.network_type == "DEVICE_EDGE_CHILD" and device.preferences.profileType == "switch" then
    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    if component == "out1" or component == "out2" then
      if parent_device:get_latest_state(component, capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
        device:emit_event(capabilities.switch.switch.on())
      else
        device:emit_event(capabilities.switch.switch.off())
      end
    end

  elseif device.network_type == "DEVICE_EDGE_CHILD" and device.preferences.profileType == "contact" then
    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    if component == "in1" or component == "in2" then
      if parent_device:get_latest_state(component, capabilities.contactSensor.ID, capabilities.contactSensor.contact.NAME) == "closed" then
        device:emit_event(capabilities.contactSensor.contact.closed())
      else
        device:emit_event(capabilities.contactSensor.contact.open())
      end
    end
  elseif device.network_type == "DEVICE_EDGE_CHILD" and device.preferences.profileType == "voltage" then
    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    local scale = 'V'
    local voltageValue = parent_device:get_latest_state(component, capabilities.voltageMeasurement.ID, capabilities.voltageMeasurement.voltage.NAME)
    device:emit_event(capabilities.voltageMeasurement.voltage({value = voltageValue, unit = scale}))

  elseif device.network_type == "DEVICE_EDGE_CHILD" and device.preferences.profileType == "motion" then
    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    if component == "in1" or component == "in2" then
      if parent_device:get_latest_state(component, capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME) == "inactive" then
        device:emit_event(capabilities.motionSensor.motion.inactive())
      else
        device:emit_event(capabilities.motionSensor.motion.active())
      end
    end
  end
end


-- switch_set_command_handler
local function switch_set_helper(driver, device, value, command)
  local set
  local get
  local delay = constants.DEFAULT_GET_STATUS_DELAY
  if device:is_cc_supported(cc.SWITCH_BINARY) then
    log.trace_with({ hub_logs = true }, "SWITCH_BINARY supported.")
    set = SwitchBinary:Set({
      target_value = value,
      duration = 0
    })
    get = SwitchBinary:Get({})
  else
    log.trace_with({ hub_logs = true }, "SWITCH_BINARY and SWITCH_MULTILEVEL NOT supported. Use Basic.Set()")
    set = Basic:Set({
      value = value
    })
    get = Basic:Get({})
  end
  device:send_to_component(set, command.component)
  local query_device = function()
    device:send_to_component(get, command.component)
  end
  device.thread:call_with_delay(delay, query_device)
end

-- switch_on_handler
local function switch_on_handler(driver, device, command)
  print("<<<<<<< switch_on_handler >>>>>>")
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    if command.component == "out1" then
      if device.preferences.out1Logic == "0" then -- out1: Normal open (OFF) and closed if active (ON)
        switch_set_helper(driver, device, SwitchBinary.value.ON_ENABLE, command)
      else
        switch_set_helper(driver, device, SwitchBinary.value.OFF_DISABLE, command)
      end
    elseif command.component == "out2" then
      if device.preferences.out2Logic == "0" then -- out2: Normal open (OFF) and closed if active (ON)
        switch_set_helper(driver, device, SwitchBinary.value.ON_ENABLE, command)
      else
        switch_set_helper(driver, device, SwitchBinary.value.OFF_DISABLE, command)
      end
    end
  else
    device:emit_event(capabilities.switch.switch.on())
    command.component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    if command.component == "out1" then
      if parent_device.preferences.out1Logic == "0" then -- out1: Normal open (OFF) and closed if active (ON)
        switch_set_helper(driver, parent_device, SwitchBinary.value.ON_ENABLE, command)
      else
        switch_set_helper(driver, parent_device, SwitchBinary.value.OFF_DISABLE, command)
      end
    elseif command.component == "out2" then
      if parent_device.preferences.out2Logic == "0" then -- out2: Normal open (OFF) and closed if active (ON)
        switch_set_helper(driver, parent_device, SwitchBinary.value.ON_ENABLE, command)
      else
        switch_set_helper(driver, parent_device, SwitchBinary.value.OFF_DISABLE, command)
      end
    end
  end
end

--- switch_off_handler
local function switch_off_handler(driver, device, command)
  print("<<<<<<< switch_off_handler >>>>>>")
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    if command.component == "out1" then
      if device.preferences.out1Logic == "0" then -- out1: Normal open (OFF) and closed if active (ON)
        switch_set_helper(driver, device, SwitchBinary.value.OFF_DISABLE, command)
      else
        switch_set_helper(driver, device, SwitchBinary.value.ON_ENABLE, command)
      end
    elseif command.component == "out2" then
      if device.preferences.out2Logic == "0" then -- out2: Normal open (OFF) and closed if active (ON)
        switch_set_helper(driver, device, SwitchBinary.value.OFF_DISABLE, command)
      else
        switch_set_helper(driver, device, SwitchBinary.value.ON_ENABLE, command)
      end
    end
  else
    device:emit_event(capabilities.switch.switch.off())
    command.component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    if command.component == "out1" then
      if parent_device.preferences.out1Logic == "0" then -- out1: Normal open (OFF) and closed if active (ON)
        switch_set_helper(driver, parent_device, SwitchBinary.value.OFF_DISABLE, command)
      else
        switch_set_helper(driver, parent_device, SwitchBinary.value.ON_ENABLE, command)
      end
    elseif command.component == "out2" then
      if parent_device.preferences.out2Logic == "0" then -- out2: Normal open (OFF) and closed if active (ON)
        switch_set_helper(driver, parent_device, SwitchBinary.value.OFF_DISABLE, command)
      else
        switch_set_helper(driver, parent_device, SwitchBinary.value.ON_ENABLE, command)
      end
    end
  end
end

--- @param cmd st.zwave.CommandClass.Notification
local function notification_handler(self, device, cmd)
  local contact_notification_events_map = {
    [Notification.event.home_security.INTRUSION_LOCATION_PROVIDED] = capabilities.contactSensor.contact.open(),
    [Notification.event.home_security.INTRUSION] = capabilities.contactSensor.contact.open(),
    [Notification.event.home_security.STATE_IDLE] = capabilities.contactSensor.contact.closed(),
    --[Notification.event.access_control.WINDOW_DOOR_IS_OPEN] = capabilities.contactSensor.contact.open(),
    --[Notification.event.access_control.WINDOW_DOOR_IS_CLOSED] = capabilities.contactSensor.contact.closed()
  }
  local motion_notification_events_map = {
    [Notification.event.home_security.INTRUSION_LOCATION_PROVIDED] = capabilities.motionSensor.motion.active(),
    [Notification.event.home_security.INTRUSION] = capabilities.motionSensor.motion.active(),
    [Notification.event.home_security.STATE_IDLE] = capabilities.motionSensor.motion.inactive(),
    --[Notification.event.access_control.WINDOW_DOOR_IS_OPEN] = capabilities.motionSensor.motion.active(),
    --[Notification.event.access_control.WINDOW_DOOR_IS_CLOSED] = capabilities.motionSensor.motion.inactive()
  }

  if (cmd.args.notification_type == Notification.notification_type.HOME_SECURITY)
      -- or (cmd.args.notification_type == Notification.notification_type.ACCESS_CONTROL)
  then
    local event
    if device.preferences.changeProfileExtTemp == "8" or device.preferences.changeProfileExtTemp == "12" then -- two motion sensors
      event = motion_notification_events_map[cmd.args.event]
    elseif device.preferences.changeProfileExtTemp == "7" or 
      device.preferences.changeProfileExtTemp == "10" or 
      device.preferences.changeProfileExtTemp == "11" or
      device.preferences.changeProfileExtTemp == "13" then -- contact sensors
      event = contact_notification_events_map[cmd.args.event]
    end
    if (event ~= nil) then
      -- emit event parent device
      device:emit_event_for_endpoint(cmd.src_channel, event)

       -- emit event child device
      local component= endpoint_to_component(device, cmd.src_channel)
      local child_device = device:get_child_by_parent_assigned_key(component)
      if child_device ~= nil and (child_device.preferences.profileType == "contact" or child_device.preferences.profileType == "motion") then
        child_device:emit_event(event)
      end
    end
  end
end

local function on_off_handlers_report(driver, device, cmd)
  print("<<<<< on_off_handlers_report in main driver >>>>>>>")
  local event
  if cmd.args.target_value ~= nil then
    -- Target value is our best inidicator of eventual state.
    -- If we see this, it should be considered authoritative.
    if cmd.args.target_value == SwitchBinary.value.OFF_DISABLE then
      event = capabilities.switch.switch.off()
    else
      event = capabilities.switch.switch.on()
    end
  else
    if cmd.args.value == SwitchBinary.value.OFF_DISABLE then
      event = capabilities.switch.switch.off()
    else
      event = capabilities.switch.switch.on()
    end
  end
  device:emit_event_for_endpoint(cmd.src_channel, event)

  -- emit event for childs devices
  --print("cmd.src_channel >>>>>>",cmd.src_channel)
  local component= endpoint_to_component(device, cmd.src_channel)
  local child_device = device:get_child_by_parent_assigned_key(component)
  if child_device ~= nil then
    child_device:emit_event(event)
  end
end

local driver_template = {
  supported_capabilities = {
    capabilities.waterSensor,
    capabilities.contactSensor,
    capabilities.motionSensor,
    capabilities.relativeHumidityMeasurement,
    capabilities.illuminanceMeasurement,
    capabilities.temperatureMeasurement,
    capabilities.switch,
    capabilities.ultravioletIndex,
    capabilities.voltageMeasurement,
    capabilities.smokeDetector,
    capabilities.refresh
  },
  sub_drivers = {
    require("thermostat"),
  },
  lifecycle_handlers = {
    added = added_handler,
    init = device_init,
    infoChanged = info_changed,
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = switch_on_handler,
      [capabilities.switch.commands.off.NAME] = switch_off_handler
    },
  },
  zwave_handlers = {
    [cc.SENSOR_MULTILEVEL] = {
      [SensorMultilevel.REPORT] = sensorMultilevel_report_handler
    },
    [cc.NOTIFICATION] = {
      [Notification.REPORT] = notification_handler
    },
    [cc.BASIC] = {
      [Basic.REPORT] = on_off_handlers_report
    },
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = on_off_handlers_report
    },
  },
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local sensor = ZwaveDriver("zwave_smart_implant", driver_template)
sensor:run()
