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

------ Author Mariano Colmenarejo (Nov 2021) --------

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local xiaomi_utils = require "xiaomi_utils"

--- Custom Capabilities
local fan_Cyclic_Mode = capabilities["legendabsolute60149.fanCyclicMode"]
local fan_Next_Change = capabilities["legendabsolute60149.fanNextChange"]
local atmos_Pressure = capabilities ["legendabsolute60149.atmosPressure"]

--- variables initialization
local thermostat_Run = "stopped"
local thermostat_Mode = "off"
local thermostatFan_Mode = "auto"
local thermostatOperatingState = "idle"


----- thermostatMode_handler -------------------

local function thermostatMode_handler(self,device,command)
  --Detect if thermostat initialized by hub reboot
  if command == "init" then
    thermostat_Mode = device:get_field ("thermostat_Mode")
    print("thermostatMode", thermostat_Mode)
    thermostat_Run = "stopped"
    device:set_field("thermostat_Run", thermostat_Run, {persist = true})
  else
    print("thermostatMode", command.args.mode)
    thermostat_Mode = command.args.mode
  end
  device:emit_event(capabilities.thermostatMode.thermostatMode(thermostat_Mode))
   --Save thermostatMode
  device:set_field("thermostat_Mode", thermostat_Mode, {persist = true})
   ---- set thermostat state
  if thermostat_Mode == "off" then
    thermostatOperatingState ="idle"
    device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
    device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = true})  

   ---- Timers Cancel ------
    for timer in pairs(device.thread.timers) do
     print("<<<<< Cancelando timer >>>>>")
     device.thread:cancel_timer(timer)
     device:set_field("thermostat_Run", "stopped", {persist = true})
     thermostat_Run = device:get_field("thermostat_Run")
     print("thermostat_Run", thermostat_Run)
    end
  
  elseif thermostat_Mode == "auto" then    
    local heating_Setpoint = device.preferences.heatTempAuto
    local cooling_Setpoint = device.preferences.coolTempAuto
    local temp_scale = "C"
    if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
    device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))
    device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))
    --Save Setpoints
    device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})
    device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true})    
  
  elseif thermostat_Mode == "asleep" then   
    local heating_Setpoint = device.preferences.heatTempSleep
    local cooling_Setpoint = device.preferences.coolTempSleep
    local temp_scale = "C"
    if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
    device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))
    device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))
    --Save Setpoints
    device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})
    device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true})
  
  elseif thermostat_Mode == "rush hour" then
    local heating_Setpoint = device.preferences.heatTempRush
    local cooling_Setpoint = device.preferences.coolTempRush
    local temp_scale = "C"
    if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
    device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))
    device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))
    --Save Setpoints
    device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})
    device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true})

  elseif thermostat_Mode == "away" then
    local heating_Setpoint = device.preferences.heatTempAway
    local cooling_Setpoint = device.preferences.coolTempAway
    local temp_scale = "C"
    if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
    device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))
    device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))
    --Save Setpoints
    device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})
    device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true})
  end
  
  --- thermostat run timer 
thermostat_Mode = device:get_field("thermostat_Mode")
local cycleCurrent = device:get_field("cycleCurrent")
if thermostat_Mode ~= "off" or cycleCurrent ~= "stop" then 

   ------ Timer activation
 thermostat_Run = device:get_field("thermostat_Run")
 if thermostat_Run == "stopped" then
  device:set_field("thermostat_Run", "running", {persist = true})
  device.thread:call_on_schedule(
   15,
   function ()
   print("<<< Cheking Temp >>>")
   print("device:", device)
   thermostat_Mode = device:get_field("thermostat_Mode")
   print("thermostat_Run =", device:get_field("thermostat_Run"))
   
   --local last_temp = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME) + device.preferences.tempOffset
   --last_temp = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME) + device.preferences.tempOffset
   local last_temp = device:get_field("last_temp") + device.preferences.tempOffset
   if device.preferences.thermTempUnits == "Fahrenheit" then
    last_temp = (last_temp * 9/5) + 32
   end

   --local thermostatOperatingState = device:get_latest_state("main", capabilities.thermostatOperatingState.ID, capabilities.thermostatOperatingState.thermostatOperatingState.NAME)
   thermostatOperatingState = device:get_field("thermostatOperatingState")
   local heating_Setpoint = device:get_field("heating_Setpoint")
   local cooling_Setpoint = device:get_field("cooling_Setpoint")
   print("thermostatOperatingState Before =",thermostatOperatingState)
   print("thermostat_Mode =",thermostat_Mode)
   local current_temp = tonumber(string.format("%.1f ", last_temp)) 
   local thermostatFan_Mode = device:get_field("thermostatFan_Mode")
   print("thermostatFan_Mode =", thermostatFan_Mode)   
   local cycleCurrent = device:get_field("cycleCurrent")
   print("cycleCurrent =", cycleCurrent)
  
   ------------ Fanc Circulate Cycling handler -------------
    thermostatFan_Mode = device:get_field ("thermostatFan_Mode")
    if device.preferences.fanCyclic == "Yes" then
      local onCyclicTotalSteps = device.preferences.onTime * 60  / 15
      local offCyclicTotalSteps = device.preferences.offTime * 60  / 15

      if device:get_field("cycleCurrent") == "off" then
       local offCyclicStep = device:get_field("offCyclicStep") + 1
       device:set_field("offCyclicStep", offCyclicStep, {persist = true})
       print("offCyclicStep, offCyclicTotalSteps", device:get_field("offCyclicStep"),offCyclicTotalSteps)
       if offCyclicStep >= offCyclicTotalSteps then 
        offCyclicStep = 0
        device:set_field("offCyclicStep", offCyclicStep, {persist = true})
        local nextChange= os.date("%H:%M:%S",os.time() + (device.preferences.onTime * 60) + (device.preferences.localTimeOffset * 3600))
        --emit fan state  and time for next change
        device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
        device:emit_event(fan_Next_Change.fanNextChange(nextChange))
        device:set_field("cycleCurrent", "on", {persist = true})
       end
      elseif device:get_field("cycleCurrent") == "on" then
        local onCyclicStep = device:get_field("onCyclicStep") + 1
        device:set_field("onCyclicStep", onCyclicStep, {persist = true})
        print("onCyclicStep, onCyclicTotalSteps", device:get_field("onCyclicStep"),onCyclicTotalSteps)
        if onCyclicStep >= onCyclicTotalSteps then 
         onCyclicStep = 0
         device:set_field("onCyclicStep", onCyclicStep, {persist = true})
         local nextChange= os.date("%H:%M:%S",os.time() + (device.preferences.offTime * 60) + (device.preferences.localTimeOffset * 3600))
         --emit fan state  and time for next change
         device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
         device:emit_event(fan_Next_Change.fanNextChange(nextChange))
         device:set_field("cycleCurrent", "off", {persist = true})
        end   
      end
    end
    
--------------------------- Thermostat status handler ------------------- 

   --- initial state if idle
   if device:get_field("thermostatOperatingState") == "idle" then 
    if current_temp <= (device:get_field("heating_Setpoint")) then 
      thermostatOperatingState = "pending heat"
    elseif current_temp >= (device:get_field("cooling_Setpoint")) then
      thermostatOperatingState = "pending cool"
    end
  end

  ---calculate temps for state change
  local tempChangeToPendingHeat = (device:get_field("heating_Setpoint") - (device.preferences.diffStartStop / 2))
  local tempChangeToHeating = device:get_field("heating_Setpoint") - (device.preferences.diffStartStop)
  local tempChangeToPendingCool = (device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop / 2))  
  local tempChangeToCooling = device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop)
  
  -- Re-Calculate temp Change To Heating and Cooling for radiant floor and Temp Units
  local unitsCorrection = 1
  if device.preferences.thermTempUnits =="Celsius" then unitsCorrection = 1 else unitsCorrection =2 end
  if device.preferences.floorRadaint == "Heat" then
   tempChangeToHeating = tempChangeToPendingHeat - (0.1 * unitsCorrection)
  elseif device.preferences.floorRadaint == "HeatCool" then
   tempChangeToHeating = tempChangeToPendingHeat - (0.1 * unitsCorrection)
   tempChangeToCooling = tempChangeToPendingCool + (0.1 * unitsCorrection)
  end

  ---- Print values for thermostat state Calculate
  print("device.preferences.floorRadaint =", device.preferences.floorRadaint)
  print("device.preferences.temperature DiffStarStop =", device.preferences.diffStartStop)
  print("*** Current_temp ***",string.format("%.1f ", last_temp), device.preferences.thermTempUnits)
  print("## heating_Setpoint ##",heating_Setpoint)
  print("tempChangeToHeating <=", tempChangeToHeating)
  print("tempChangeToPendingHeat >", tempChangeToPendingHeat)
  print("## cooling_Setpoint ##",cooling_Setpoint)
  print("tempChangeToCooling >=", tempChangeToCooling)
  print("tempChangeToPendingCool <", tempChangeToPendingCool)

  if thermostat_Mode == "heat" then

    --if current_temp <= device:get_field("heating_Setpoint") - (device.preferences.diffStartStop / floorRadaintHeat)  
    if current_temp <= tempChangeToHeating then
      thermostatOperatingState = "heating"
 
    --elseif current_temp > (device:get_field("heating_Setpoint") - (device.preferences.diffStartStop / 2))
    elseif current_temp > tempChangeToPendingHeat then
      thermostatOperatingState = "pending heat"

    end

  elseif thermostat_Mode == "cool" then
    --if current_temp >= device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop / floorRadaintcool)
    if current_temp >= tempChangeToCooling then
       thermostatOperatingState = "cooling"

    --elseif current_temp < (device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop / 2))
    elseif current_temp < tempChangeToPendingCool then
       thermostatOperatingState = "pending cool"
    end
     
  elseif thermostat_Mode == "auto" or thermostat_Mode == "asleep" or thermostat_Mode == "rush hour" or thermostat_Mode == "away" or thermostat_Mode == "manual" or thermostat_Mode == "eco" then

    if current_temp <= tempChangeToHeating then
        thermostatOperatingState = "heating"

    elseif current_temp > tempChangeToPendingHeat and current_temp < (device:get_field("cooling_Setpoint")) - (device.preferences.diffStartStop) then
        thermostatOperatingState = "pending heat"

      elseif current_temp >= tempChangeToCooling then
        thermostatOperatingState = "cooling"

    elseif current_temp < tempChangeToPendingCool and current_temp > (device:get_field("heating_Setpoint")) + (device.preferences.diffStartStop) then
        thermostatOperatingState = "pending cool"

    end
  end

  ----emit event & save thermostatOperatingState
    
    print("thermostatOperatingState ****", thermostatOperatingState,"****")
    if (device:get_field("thermostatOperatingState") ~= "vent economizer" and device:get_field("thermostatOperatingState") ~= "fan only") or thermostat_Mode ~= "off" then 
     device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
     device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = true})
     if device:get_field("thermostatFan_Mode") == "auto" then
      if thermostatOperatingState == "heating" or thermostatOperatingState == "cooling" then 
       device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
      else
       device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
      end
     end
    end
   end,
  "thermostat_timer")
  end
 end
end

---- HeatingSetpoint_handler
local function heatingSetpoint_handler(self,device,command)
  print("HeatingSetpoint", command.args.setpoint)
  local heating_Setpoint = command.args.setpoint
  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))

  --Save HeatingSetpoint
  device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})

end

---- coolingSetpoint_handler
local function coolingSetpoint_handler(self,device,command)
  print("CoolingSetpoint", command.args.setpoint)
  local cooling_Setpoint = command.args.setpoint
  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))

  --Save CoolSetpoint
  device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true})

end

-------- thermostatFanMode_handler ----------

local function thermostatFanMode_handler(self,device,command)
  print("thermostatFanMode", command.args.mode)
  local thermostatFan_Mode = command.args.mode
  device:emit_event(capabilities.thermostatFanMode.thermostatFanMode(thermostatFan_Mode))
  --Save thermostatFanMode
  device:set_field("thermostatFan_Mode", thermostatFan_Mode, {persist = true})

  --------- Cancel Timers --------------
  thermostat_Run = device:get_field("thermostat_Run")
  if thermostat_Run == "running" then
   for timer in pairs(device.thread.timers) do
    print("<<<<< Cancelando timer >>>>>")
    device.thread:cancel_timer(timer)
    device:set_field("thermostat_Run", "stopped", {persist = true})
    thermostat_Run = device:get_field("thermostat_Run")
    print("thermostat_Run", thermostat_Run)
   end   
  end
 
  --- emit thermostate state and save preset values for fan cyclinc
    thermostat_Mode = device:get_field("thermostat_Mode")
    thermostatOperatingState = device:get_field("thermostatOperatingState")
    if thermostatFan_Mode == "on" then
     device:set_field ("cycleCurrent", "stop", {persist = true})
     device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))       
     if thermostat_Mode == "off" then
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState("fan only"))
      device:set_field ("thermostatOperatingState", "fan only", {persist = true})
     end     
    
    elseif thermostatFan_Mode == "circulate" then
     device:set_field ("cycleCurrent", "stop", {persist = true})
     device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
     if thermostat_Mode == "off" then
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState("vent economizer"))
      device:set_field ("thermostatOperatingState", "vent economizer", {persist = true})
     end 
    
    elseif thermostatFan_Mode == "auto" then
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
      thermostatOperatingState = device:get_field("thermostatOperatingState")
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
      device:set_field ("thermostatOperatingState",thermostatOperatingState, {persist = true})
      device:set_field ("cycleCurrent", "stop", {persist = true})
    
    elseif thermostatFan_Mode == "followschedule" then 
     ---- Set steps for cyclic fan operation
     if device.preferences.fanCyclic == "Yes" then
      --emit fan state  and time for next change
      local nextChange= os.date("%H:%M:%S",os.time() + (device.preferences.onTime * 60) + (device.preferences.localTimeOffset * 3600))
      device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
      device:emit_event(fan_Next_Change.fanNextChange(nextChange))
      local onCyclicStep = 0
      local offCyclicStep = 0
      local cycleCurrent = "on"
      device:set_field ("offCyclicStep", offCyclicStep, {persist = true})
      device:set_field ("onCyclicStep", onCyclicStep, {persist = true})
      device:set_field ("cycleCurrent", cycleCurrent, {persist = true})
      print("onCyclicStep, offCyclicStep, cycleCurrent", device:get_field ("onCyclicStep"),device:get_field ("offCyclicStep"),device:get_field ("cycleCurrent"))
     end     
    end

   if thermostatFan_Mode == "followschedule" or thermostat_Mode ~= "off" then
    command.args.mode = thermostat_Mode
    thermostatMode_handler(self,device,command)
   end
end


--- do Configure
local function do_Configure(self,device)
  device:configure()
end

--- do_init
local function do_init (self, device)

  --thermostat_Run = device:get_field("thermostat_Run")
  thermostat_Run = "stopped"
  device:set_field("thermostat_Run", thermostat_Run, {persist = true})

  device:set_field("onCyclicStep", 0, {persist = true})
  device:set_field("offCyclicStep", 0, {persist = true})
  device:set_field ("cycleCurrent", "stop", {persist = true})
 
  --thermostat_Mode = "off"
  thermostat_Mode = device:get_field("thermostat_Mode")
  if thermostat_Mode == nil then thermostat_Mode = "off" end
  device:emit_event(capabilities.thermostatMode.thermostatMode(thermostat_Mode))
  --Save thermostatMode
  device:set_field("thermostat_Mode", thermostat_Mode, {persist = true}) 

  --thermostatOperatingState = "idle"
  thermostatOperatingState = device:get_field("thermostatOperatingState")
  if thermostatOperatingState == nil then thermostatOperatingState ="idle" end  
  device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
  device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = true})  
 
  thermostatFan_Mode = device:get_field("thermostatFan_Mode")
  --thermostatFan_Mode = "auto"
  if thermostatFan_Mode == nil then thermostatFan_Mode = "auto" end
  device:emit_event(capabilities.thermostatFanMode.thermostatFanMode(thermostatFan_Mode))

  --fan_Cyclic_Mode = device:get_field("fan_Cyclic_Mode")
  --if fan_Cyclic_Mode == nil then fan_Cyclic_Mode = "Off" end
  device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
  device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
  --Save thermostatFanMode
  device:set_field("thermostatFan_Mode", thermostatFan_Mode, {persist = true})
  
  -- initialize set points
  if device:get_field("heating_Setpoint") == nil then device:set_field("heating_Setpoint", device.preferences.heatTempAuto, {persist = true}) end
  if device:get_field("cooling_Setpoint") == nil then device:set_field("cooling_Setpoint", device.preferences.heatTempAuto, {persist = true}) end
  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = device:get_field("heating_Setpoint"), unit = temp_scale }))
  device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = device:get_field("cooling_Setpoint"), unit = temp_scale }))

 --- if thermostat initialized by hub reboot
 if thermostat_Mode ~= "off" then
  thermostatMode_handler(self,device,"init")
 end

end

--- added thermostat_Modes_Supported
local function thermostat_Modes_Supported(self,device)
  local supported_modes = {
    capabilities.thermostatMode.thermostatMode.off.NAME,
    capabilities.thermostatMode.thermostatMode.auto.NAME,
    capabilities.thermostatMode.thermostatMode.eco.NAME,
    capabilities.thermostatMode.thermostatMode.asleep.NAME,    
    capabilities.thermostatMode.thermostatMode.heat.NAME,
    capabilities.thermostatMode.thermostatMode.cool.NAME,
    capabilities.thermostatMode.thermostatMode.rush_hour.NAME,
    capabilities.thermostatMode.thermostatMode.away.NAME,
    capabilities.thermostatMode.thermostatMode.manual.NAME
  }
  local supported_fanmodes =  {
    capabilities.thermostatFanMode.thermostatFanMode.auto.NAME,
    capabilities.thermostatFanMode.thermostatFanMode.circulate.NAME,
    capabilities.thermostatFanMode.thermostatFanMode.on.NAME,
    capabilities.thermostatFanMode.thermostatFanMode.followschedule.NAME,
  }                         
  device:emit_event(capabilities.thermostatMode.supportedThermostatModes(supported_modes))
  device:emit_event(capabilities.thermostatFanMode.supportedThermostatFanModes(supported_fanmodes))
end

--- Update preferences after infoChanged recived---
local function do_Preferences (self, device)
 for id, value in pairs(device.preferences) do
  print("device.preferences[infoChanged]=", device.preferences[id])
  local oldPreferenceValue = device:get_field(id)
  local newParameterValue = device.preferences[id]
   if oldPreferenceValue ~= newParameterValue then
    device:set_field(id, newParameterValue, {persist = true})
    print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
    if id == "thermTempUnits" then
      --device:get_field("heating_Setpoint")
      local temp_scale =  "C"
      if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
      device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = device:get_field("heating_Setpoint"), unit = temp_scale }))
      device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = device:get_field("cooling_Setpoint"), unit = temp_scale }))
    end
   end
  end
end

-- attributte handler Atmospheric pressure
local pressure_value_attr_handler = function (driver, device, value, zb_rx)
  local kPa = math.floor (value.value / 10)
  device: emit_event (capabilities.atmosphericPressureMeasurement.atmosphericPressure ({value = kPa, unit = "kPa"}))

  -- emit even for custom capability in mBar
  local mBar = value.value
  device:emit_event(atmos_Pressure.atmosPressure(mBar))
end

--- temperature handler
local function temp_attr_handler(self, device, tempvalue, zb_rx)

  -- set temp ref to thermostat state to temp change > 0.1
  local ref_event_temp = tempvalue.value
  if device:get_field("ref_event_temp") == nil then device:set_field("ref_event_temp", ref_event_temp, {persist = true}) end
  if math.abs(ref_event_temp - device:get_field("ref_event_temp")) > 10 then
    -- get current temp for thermostat state control 
    local last_temp = tempvalue.value / 100
    device:set_field("last_temp", last_temp, {persist = true})
    device:set_field("ref_event_temp", ref_event_temp, {persist = true})
  end
  --emit event
  tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)

end

----- driver template ----------
local zigbee_motion_driver = {
  supported_capabilities = {
    capabilities.motionSensor,
    capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.atmosphericPressureMeasurement,
    atmos_Pressure,
    capabilities.thermostatMode,
    capabilities.thermostatOperatingState,
    capabilities.thermostatFanMode,
    fan_Cyclic_Mode,
    fan_Next_Change,
    capabilities.thermostatHeatingSetpoint,
    capabilities.thermostatCoolingSetpoint,    
    capabilities.battery,
  },
  lifecycle_handlers = {
    init = do_init,
    infoChanged = do_Preferences,
    added = thermostat_Modes_Supported,
    driverSwitched = do_Configure
  },
  capability_handlers = {
    [capabilities.thermostatMode.ID] = {
      [capabilities.thermostatMode.commands.setThermostatMode.NAME] = thermostatMode_handler,       
    },
    [capabilities.thermostatHeatingSetpoint.ID] = {
      [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = heatingSetpoint_handler,
    },
    [capabilities.thermostatCoolingSetpoint.ID] = {
      [capabilities.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME] = coolingSetpoint_handler,
    },
    [capabilities.thermostatFanMode.ID] = {
      [capabilities.thermostatFanMode.commands.setThermostatFanMode.NAME] = thermostatFanMode_handler,
    },  
  },   
  zigbee_handlers = {
    attr = {
      [zcl_clusters.basic_id] = {
        [0xFF02] = xiaomi_utils.battery_handler,
        [0xFF01] = xiaomi_utils.battery_handler
      },
      [zcl_clusters.PressureMeasurement.ID] = {
          [zcl_clusters.PressureMeasurement.attributes.MeasuredValue.ID] = pressure_value_attr_handler
      },
      [tempMeasurement.ID] = {
            [tempMeasurement.attributes.MeasuredValue.ID] = temp_attr_handler
        }
    },  
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

--------- driver run ------
defaults.register_for_default_handlers(zigbee_motion_driver, zigbee_motion_driver.supported_capabilities)
local motion = ZigbeeDriver("st-zigbee-motion", zigbee_motion_driver)
motion:run()
