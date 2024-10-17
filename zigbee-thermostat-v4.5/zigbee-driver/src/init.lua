-- Copyright 2021 SmartThings
-- M. Colmenarejo 2022
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
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local device_management = require "st.zigbee.device_management"
local xiaomi_utils = require "xiaomi_utils"
--module emit signal metrics
local signal = require "signal-metrics"
local thermostat_group = require "thermostat-group-calculation"
local common = require("multi-contact/common")

--- Custom Capabilities
local fan_Cyclic_Mode = capabilities["legendabsolute60149.fanCyclicMode"]
local fan_Next_Change = capabilities["legendabsolute60149.fanNextChange"]
local atmos_Pressure = capabilities ["legendabsolute60149.atmosPressure"]
local thermostat_Locked = capabilities ["legendabsolute60149.thermostatLocked"]
local info_Panel = capabilities ["legendabsolute60149.infoPanel"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]

--- variables initialization
local thermostat_Run = "stopped"
local thermostat_Mode = "off"
local thermostatFan_Mode = "auto"
local thermostatOperatingState = "idle"


-- thermostat calculation functions
local function thermostat_data_check(driver, device)
  print("<<< Cheking Temp >>>")
  print("device:", device)
  thermostat_Mode = device:get_field("thermostat_Mode")
  --print("thermostat_Run =", device:get_field("thermostat_Run"))

  local last_temp = device:get_field("last_temp")
  if last_temp == nil then
    last_temp = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME)
    if last_temp == nil then
      device:send(tempMeasurement.attributes.MeasuredValue:read(device))
      return 
    end
  end
  if device.preferences.thermTempUnits == "Fahrenheit" and device.preferences.useMultipleSensors == false then
   last_temp = (last_temp * 9/5) + 32
  end
  last_temp = last_temp + device.preferences.tempOffset

  --local thermostatOperatingState = device:get_latest_state("main", capabilities.thermostatOperatingState.ID, capabilities.thermostatOperatingState.thermostatOperatingState.NAME)
  thermostatOperatingState = device:get_field("thermostatOperatingState")
  local heating_Setpoint = device:get_field("heating_Setpoint")
  local cooling_Setpoint = device:get_field("cooling_Setpoint")
  local current_temp = tonumber(string.format("%.2f", last_temp)) 
  thermostatFan_Mode = device:get_field("thermostatFan_Mode")  
  local cycleCurrent = device:get_field("cycleCurrent")

  if device.preferences.logDebugPrint == true then
    print("thermostat_Run =", device:get_field("thermostat_Run"))
    print("thermostatOperatingState Before =",thermostatOperatingState)
    print("thermostat_Mode =",thermostat_Mode)
    print("thermostatFan_Mode =", thermostatFan_Mode)
    print("cycleCurrent =", cycleCurrent)
 end
 
  ------------ Fanc Circulate Cycling handler -------------

  -- if thermostat = off and fan in programming mode
  if thermostat_Mode == "off" then
    if device:get_field("thermostatFan_Mode") == "auto" and device:get_latest_state("main", fan_Cyclic_Mode.ID, fan_Cyclic_Mode.fanCyclicMode.NAME) ~= "Off" then
      device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
    end
    return 
  end
   
--------------------------- Thermostat status handler ------------------- 

  --- initial state if idle
 if device:get_field("thermostatOperatingState") == "idle" then 
   if current_temp < (device:get_field("heating_Setpoint")) then 
     thermostatOperatingState = "heating"  
   elseif current_temp >= device:get_field("heating_Setpoint") and current_temp <= (device:get_field("cooling_Setpoint")) then
     thermostatOperatingState = "pending heat"
   else
     thermostatOperatingState = "cooling"
   end
 end

 ---calculate temps for state change for default option "no"---"Radiators to Heat & Cool"
    local tempChangeToPendingHeat = device:get_field("heating_Setpoint") - device.preferences.thermalInertia
    local tempChangeToHeating = device:get_field("heating_Setpoint") - (device.preferences.diffStartStop)

    local tempChangeToPendingCool = device:get_field("cooling_Setpoint") + device.preferences.thermalInertia
    local tempChangeToCooling = device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop)
    
    -- Re-Calculate temp Change To Heating and Cooling for radiant floor and Temp Units
    local unitsCorrection = 1
    if device.preferences.thermTempUnits =="Celsius" then unitsCorrection = 1 else unitsCorrection =2 end
    
    if device.preferences.floorRadaint == "Heat" then --"Floor to Heat & Air to Cool"
      --tempChangeToPendingHeat = (device:get_field("heating_Setpoint") - (device.preferences.diffStartStop / 1.5))
      tempChangeToHeating = tempChangeToPendingHeat - (0.15 * unitsCorrection)
      tempChangeToPendingCool = device:get_field("cooling_Setpoint")
      tempChangeToCooling = device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop)

    elseif device.preferences.floorRadaint == "HeatCool" then --"Floor to Heat & Cool"
      --tempChangeToPendingHeat = (device:get_field("heating_Setpoint") - (device.preferences.diffStartStop / 1.5))
      tempChangeToHeating = tempChangeToPendingHeat - (0.15 * unitsCorrection)
      --tempChangeToPendingCool = (device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop / 1.5))
      tempChangeToCooling = tempChangeToPendingCool + (0.15 * unitsCorrection)

    elseif device.preferences.floorRadaint == "AirCool" then --"Radiators to Heat & Air to Cool"
      tempChangeToPendingCool = device:get_field("cooling_Setpoint")
      tempChangeToCooling = device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop)

    elseif device.preferences.floorRadaint == "AirCoolHeat" then --"Air to Heat & Cool"
      tempChangeToPendingHeat = device:get_field("heating_Setpoint")
      tempChangeToHeating = device:get_field("heating_Setpoint") - device.preferences.diffStartStop
      tempChangeToPendingCool = device:get_field("cooling_Setpoint")
      tempChangeToCooling = device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop)
    end

 ---- Print values for thermostat state Calculate
 if device.preferences.logDebugPrint == true then
   print("device.preferences.floorRadaint =", device.preferences.floorRadaint)
   print("device.preferences.temperature DiffStarStop =", device.preferences.diffStartStop)
   print("*** Current_temp ***", current_temp, device.preferences.thermTempUnits)
   print("## heating_Setpoint ##",device:get_field("heating_Setpoint"))
   print("tempChangeToHeating <=", tempChangeToHeating)
   print("tempChangeToPendingHeat >", tempChangeToPendingHeat)
   print("## cooling_Setpoint ##",device:get_field("cooling_Setpoint"))
   print("tempChangeToCooling >=", tempChangeToCooling)
   print("tempChangeToPendingCool <", tempChangeToPendingCool)
 end

 if thermostat_Mode == "heat" then
 
   if current_temp <= tempChangeToHeating then
     thermostatOperatingState = "heating"

   elseif current_temp > tempChangeToPendingHeat then
     thermostatOperatingState = "pending heat"
   end

 elseif thermostat_Mode == "cool" then

   if current_temp >= tempChangeToCooling then
      thermostatOperatingState = "cooling"

   elseif current_temp < tempChangeToPendingCool then
      thermostatOperatingState = "pending cool"
   end
    
 elseif thermostat_Mode == "auto" or thermostat_Mode == "asleep" or thermostat_Mode == "rush hour" or thermostat_Mode == "away" or thermostat_Mode == "manual" or thermostat_Mode == "eco" then

   if current_temp <= tempChangeToHeating then
      thermostatOperatingState = "heating"

   elseif current_temp > tempChangeToPendingHeat and current_temp < (device:get_field("cooling_Setpoint")) - (device.preferences.diffStartStop) then
      if math.abs(current_temp - device:get_field("heating_Setpoint")) <= math.abs(current_temp - device:get_field("cooling_Setpoint")) then
        thermostatOperatingState = "pending heat"
      else
        thermostatOperatingState = "pending cool"
      end

    elseif current_temp >= tempChangeToCooling then
       thermostatOperatingState = "cooling"

   elseif current_temp < tempChangeToPendingCool and current_temp > (device:get_field("heating_Setpoint")) + (device.preferences.diffStartStop) then
      if math.abs(device:get_field("cooling_Setpoint") - current_temp ) <= math.abs(current_temp - device:get_field("heating_Setpoint")) then
        thermostatOperatingState = "pending cool"
      else
        thermostatOperatingState = "pending heat"
      end
   end
 end

 ----emit event & save thermostatOperatingState
   
   print("thermostatOperatingState ****", thermostatOperatingState,"****")
   if (device:get_field("thermostatOperatingState") ~= "vent economizer" and device:get_field("thermostatOperatingState") ~= "fan only") or thermostat_Mode ~= "off" then 
     if thermostatOperatingState ~= device:get_latest_state("main", capabilities.thermostatOperatingState.ID, capabilities.thermostatOperatingState.thermostatOperatingState.NAME) then
       device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
       device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = false})
     end
   
    -- emit thermostat information for next change state
    local temp_scale = "C"
    if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
    local text = "T= "..current_temp.."º"..temp_scale.."-> No Expected Status Change"
    if thermostatOperatingState == "heating" then
     text = "T= "..current_temp.."º"..temp_scale..", Next State: Pending Heat, T > "..string.format("%.2f",tempChangeToPendingHeat).."º"..temp_scale
    elseif thermostatOperatingState == "cooling"  then
     text = "T= "..current_temp.."º"..temp_scale..", Next State: Pending Cool, T < "..string.format("%.2f",tempChangeToPendingCool).."º"..temp_scale
    elseif thermostatOperatingState == "pending heat" then
     text = "T= "..current_temp.."º"..temp_scale..", Next State: Heating, T <= "..string.format("%.2f",tempChangeToHeating).."º"..temp_scale
    elseif thermostatOperatingState == "pending cool" then
     text = "T= "..current_temp.."º"..temp_scale..", Next State: Cooling, T >= "..string.format("%.2f",tempChangeToCooling).."º"..temp_scale
    end 

    if text ~= device:get_latest_state("main", info_Panel.ID, info_Panel.infoPanel.NAME) then
     device:emit_event(info_Panel.infoPanel(text))
   end

    --Emit event Fan status
    if device:get_field("thermostatFan_Mode") == "auto" then
     if thermostatOperatingState == "heating" or thermostatOperatingState == "cooling" then 
       if device:get_latest_state("main", fan_Cyclic_Mode.ID, fan_Cyclic_Mode.fanCyclicMode.NAME) ~= "On" then
         device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
       end
     else
       if device:get_latest_state("main", fan_Cyclic_Mode.ID, fan_Cyclic_Mode.fanCyclicMode.NAME) ~= "Off" then
         device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
       end
     end
    end
   end
end

----- thermostatMode_handler -------------------

local function thermostatMode_handler(self,device,command)
  --Detect if thermostat initialized by hub reboot
  if command == "init" then
    thermostat_Mode = device:get_field ("thermostat_Mode")
    print("thermostatMode", thermostat_Mode)
    thermostat_Run = "stopped"
    device:set_field("thermostat_Run", thermostat_Run, {persist = false})
  else
    print("thermostatMode", command.args.mode)
    thermostat_Mode = command.args.mode
  end
  --if locked then emit old value
  if device:get_field("thermostat_Lock") == "Locked" then 
    thermostat_Mode = device:get_field("thermostat_Mode")
    device:emit_event(capabilities.thermostatMode.thermostatMode(thermostat_Mode))
    if command ~= "init" then return end
  end

  device:emit_event(capabilities.thermostatMode.thermostatMode(thermostat_Mode))
   --Save thermostatMode
  device:set_field("thermostat_Mode", thermostat_Mode, {persist = false})
   ---- set thermostat state
  if thermostat_Mode == "off" then
    thermostatOperatingState ="idle"
    device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
    device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = false})

    --emit thermostat change state info
    local temp = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME)
      local scale = "C"
      if device.preferences.thermTempUnits == "Fahrenheit" then
        scale = "F"
        temp = (temp * 9/5) + 32
      end
      temp = temp + device.preferences.tempOffset
    local text = "Temp: "..temp.."º"..scale.."-> No Expected Status Change"
    device:emit_event(info_Panel.infoPanel(text))

    ---- Set Thermostat stopped ------
    device:set_field("thermostat_Run", "stopped", {persist = false})
    thermostat_Run = device:get_field("thermostat_Run")
    if device.preferences.logDebugPrint == true then
     print("<<< thermostat_Run >>>", thermostat_Run)
    end

  else
   local heating_Setpoint = device:get_field("heating_Setpoint")
   local cooling_Setpoint = device:get_field("cooling_Setpoint")
   if thermostat_Mode == "auto" then    
    heating_Setpoint = device.preferences.heatTempAuto
    cooling_Setpoint = device.preferences.coolTempAuto  
  
   elseif thermostat_Mode == "asleep" then   
    heating_Setpoint = device.preferences.heatTempSleep
    cooling_Setpoint = device.preferences.coolTempSleep
  
   elseif thermostat_Mode == "rush hour" then
    heating_Setpoint = device.preferences.heatTempRush
    cooling_Setpoint = device.preferences.coolTempRush

   elseif thermostat_Mode == "away" then
    heating_Setpoint = device.preferences.heatTempAway
    cooling_Setpoint = device.preferences.coolTempAway

   elseif thermostat_Mode == "eco" then
    heating_Setpoint = device.preferences.heatTempEco
    cooling_Setpoint = device.preferences.coolTempEco

  end
    local temp_scale = "C"
    if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
    device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))
    device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))
    --Save Setpoints
    device:set_field("heating_Setpoint", heating_Setpoint, {persist = false})
    device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = false}) 
  end

  ---- set thermostat lock status
  if command ~= "init" and (command.args.mode == "away" or command.args.mode == "manual") and device:get_field("thermostat_Lock") == "Unlocked" then
    device:emit_event(thermostat_Locked.thermostatLocked("Locked"))
    --Save thermostat_Locked
    device:set_field("thermostat_Lock", "Locked", {persist = false})
  end

  --- set thermostat or fan cycle run
  thermostat_Mode = device:get_field("thermostat_Mode")
  local cycleCurrent = device:get_field("cycleCurrent") 

  if thermostat_Mode ~= "off" then 
      ------ Timer activation now set thermostat running 
    thermostat_Run = device:get_field("thermostat_Run")
    if device.preferences.logDebugPrint == true then
      print("Pre-timer Activation Thermostat Mode >>>>>>>>",thermostat_Mode)
      print("Pre-timer Activation thermostat_Run >>>>>>",thermostat_Run)
      print("Fan Cycle Timer >>>>>>",cycleCurrent)
    end
    if thermostat_Run == "stopped" or thermostat_Run == nil then
      device:set_field("thermostat_Run", "running", {persist = false})
    end

    -- thermostat calculations
    thermostat_data_check (self, device)
  else
    if device:get_field("thermostatFan_Mode") == "auto" and device:get_latest_state("main", fan_Cyclic_Mode.ID, fan_Cyclic_Mode.fanCyclicMode.NAME) ~= "Off" then
      device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
    end
  end

  -- activate timer for fan_cycle
  if cycleCurrent ~= "stop" and device:get_field ("timer_cycleCurrent")~= "running" then 
    device:set_field ("timer_cycleCurrent", "running", {persist = false})
    ---- Temperature Timer Cancel ------
    for timer in pairs(device.thread.timers) do
      print("<<<<< Cancelando Temp timer >>>>>")
      device.thread:cancel_timer(timer)
    end
    print("<<< Init Fan Cycle Timer >>>")
    device.thread:call_on_schedule(
    60,
    function ()
        ------------ Fanc Circulate Cycling handler -------------
      print("<<< Fan Cycle Timer >>>")
        local onCyclicTotalSteps = device.preferences.onTime
        local offCyclicTotalSteps = device.preferences.offTime

        if device:get_field("cycleCurrent") == "off" then
          local offCyclicStep = device:get_field("offCyclicStep") + 1
          device:set_field("offCyclicStep", offCyclicStep, {persist = false})
          if device.preferences.logDebugPrint == true then
            print("offCyclicStep, offCyclicTotalSteps", device:get_field("offCyclicStep"),offCyclicTotalSteps)
          end
          if offCyclicStep >= offCyclicTotalSteps then 
          offCyclicStep = 0
          device:set_field("offCyclicStep", offCyclicStep, {persist = false})
          local nextChange= os.date("%H:%M:%S",os.time() + (device.preferences.onTime * 60) + (device.preferences.localTimeOffset * 3600))
          --emit fan state  and time for next change
          device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
          device:emit_event(fan_Next_Change.fanNextChange(nextChange))
          device:set_field("cycleCurrent", "on", {persist = false})
          end
        elseif device:get_field("cycleCurrent") == "on" then
          local onCyclicStep = device:get_field("onCyclicStep") + 1
          device:set_field("onCyclicStep", onCyclicStep, {persist = false})
          if device.preferences.logDebugPrint == true then
            print("onCyclicStep, onCyclicTotalSteps", device:get_field("onCyclicStep"),onCyclicTotalSteps)
          end
          if onCyclicStep >= onCyclicTotalSteps then 
            onCyclicStep = 0
            device:set_field("onCyclicStep", onCyclicStep, {persist = false})
            local nextChange= os.date("%H:%M:%S",os.time() + (device.preferences.offTime * 60) + (device.preferences.localTimeOffset * 3600))
            --emit fan state  and time for next change
            device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
            device:emit_event(fan_Next_Change.fanNextChange(nextChange))
            device:set_field("cycleCurrent", "off", {persist = false})
          end   
        end
    end,
    "fan_cycle_timer")
  end

end

---- HeatingSetpoint_handler
local function heatingSetpoint_handler(self,device,command)
  print("HeatingSetpoint", command.args.setpoint)
  local heating_Setpoint = command.args.setpoint

  --if locked then emit old value
  if device:get_field("thermostat_Lock") == "Locked" then heating_Setpoint = device:get_field("heating_Setpoint") end

  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))

  --Save HeatingSetpoint
  device:set_field("heating_Setpoint", heating_Setpoint, {persist = false})

  -- thermostat calculations
  thermostat_data_check (self, device)
end

---- coolingSetpoint_handler
local function coolingSetpoint_handler(self,device,command)

  --print("CoolingSetpoint", command.args.setpoint)
  local cooling_Setpoint = command.args.setpoint

  --if locked then emit old value
  if device:get_field("thermostat_Lock") == "Locked" then cooling_Setpoint = device:get_field("cooling_Setpoint") end

  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))

  --Save CoolSetpoint
  device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = false})

  -- thermostat calculations
  thermostat_data_check (self, device)
end

-------- thermostatFanMode_handler ----------

local function thermostatFanMode_handler(self,device,command)
  print("thermostatFanMode", command.args.mode)
  thermostatFan_Mode = command.args.mode

  --if locked then emit old value
  if device:get_field("thermostat_Lock") == "Locked" then 
    thermostatFan_Mode = device:get_field("thermostatFan_Mode")
    device:emit_event(capabilities.thermostatFanMode.thermostatFanMode(thermostatFan_Mode))
    return
  end
  
  device:emit_event(capabilities.thermostatFanMode.thermostatFanMode(thermostatFan_Mode))
  --Save thermostatFanMode
  device:set_field("thermostatFan_Mode", thermostatFan_Mode, {persist = false})

  --------- Cancel Timers --------------
  thermostat_Run = device:get_field("thermostat_Run")
  if thermostat_Run == "running" then
   for timer in pairs(device.thread.timers) do
    print("<<<<< Cancelando timer >>>>>")
    device.thread:cancel_timer(timer)
    device:set_field("thermostat_Run", "stopped", {persist = false})
    thermostat_Run = device:get_field("thermostat_Run")
    print("thermostat_Run", thermostat_Run)
   end   
  end
 
  --- emit thermostate state and save preset values for fan cyclinc
    thermostat_Mode = device:get_field("thermostat_Mode")
    thermostatOperatingState = device:get_field("thermostatOperatingState")
    if thermostatFan_Mode == "on" then
      device:set_field ("cycleCurrent", "stop", {persist = false})
      device:set_field ("timer_cycleCurrent", "stopped", {persist = false})
      device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))

      if thermostat_Mode == "off" then
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState("fan only"))
      device:set_field ("thermostatOperatingState", "fan only", {persist = false})
      end 
    
    elseif thermostatFan_Mode == "circulate" then
      device:set_field ("cycleCurrent", "stop", {persist = false})
      device:set_field ("timer_cycleCurrent", "stopped", {persist = false})
      device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))

      if thermostat_Mode == "off" then
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState("vent economizer"))
      device:set_field ("thermostatOperatingState", "vent economizer", {persist = false})
      end
    
    elseif thermostatFan_Mode == "auto" then
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
      if thermostat_Mode == "off" then
        device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
        device:set_field ("thermostatOperatingState", "idle", {persist = false})
      end
      thermostatOperatingState = device:get_field("thermostatOperatingState")
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
      device:set_field ("thermostatOperatingState",thermostatOperatingState, {persist = false})
      device:set_field ("cycleCurrent", "stop", {persist = false})
      device:set_field ("timer_cycleCurrent", "stopped", {persist = false})
    
    elseif thermostatFan_Mode == "followschedule" then 
     ---- Set steps for cyclic fan operation
      --emit fan state  and time for next change
      local nextChange= os.date("%H:%M:%S",os.time() + (device.preferences.onTime * 60) + (device.preferences.localTimeOffset * 3600))
      device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
      device:emit_event(fan_Next_Change.fanNextChange(nextChange))
      local onCyclicStep = 0
      local offCyclicStep = 0
      local cycleCurrent = "on"
      device:set_field ("offCyclicStep", offCyclicStep, {persist = false})
      device:set_field ("onCyclicStep", onCyclicStep, {persist = false})
      device:set_field ("cycleCurrent", cycleCurrent, {persist = false})
      device:set_field ("timer_cycleCurrent", "stopped", {persist = false})
      if device.preferences.logDebugPrint == true then
        print("onCyclicStep, offCyclicStep, cycleCurrent", device:get_field ("onCyclicStep"),device:get_field ("offCyclicStep"),device:get_field ("cycleCurrent"))
      end   
    end

   if thermostatFan_Mode == "followschedule" or thermostat_Mode ~= "off" then
    command = "init"
    thermostatMode_handler(self,device,command)
   end
end


--- do Configure
local function do_Configure(self,device)

  if (device:get_manufacturer() == "SmartThings" and device:get_model()== "multiv4") or
  (device:get_manufacturer() == "Samjin" and device:get_model()== "multi") or
  (device:get_manufacturer() == "CentraLite" and device:get_model() == "3321-S") then
      ---Add the manufacturer-specific attributes to generate their configure reporting and bind requests
      for capability_id, configs in pairs(common.get_cluster_configurations(device:get_manufacturer())) do
        if device:supports_capability_by_id(capability_id) then
            device:send(device_management.build_bind_request(device, 0xFC02, self.environment_info.hub_zigbee_eui))
            for _, config in pairs(configs) do
                device:add_configured_attribute(config)
                device:add_monitored_attribute(config)
            end
        end
      end
      -- init battery voltage
      if device:get_manufacturer() ~= "Samjin" then
          battery_defaults.build_linear_voltage_init(2.3, 3.0)
      end
  end

  device:configure()

  if device:get_manufacturer() == "KMPCIL" then
    local maxTime = 900
    local changeRep = math.floor(10000 * (math.log((2), 10)))
    print ("Illumin maxTime & changeRep: ", maxTime, changeRep)
    device:send(device_management.build_bind_request(device, zcl_clusters.IlluminanceMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
  end
  device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
  device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, 600, 10))

  --device:send(tempMeasurement.attributes.MaxMeasuredValue:read(device))
  --device:send(tempMeasurement.attributes.MinMeasuredValue:read(device))

  print("doConfigure performed, transitioning device to PROVISIONED") --23/12/23
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
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

-- initial profile
local function initial_profile(self, device)

  print("<< Set Initial profile >>")
  ------ set initial profile
  if device.preferences.changeProfileTH == "1" then
     device:try_update_metadata({profile = "temp-humid-therm-battery"})
  elseif device.preferences.changeProfileTH == "5" then
     device:try_update_metadata({profile = "temp-humid-therm-battery-05"})
  elseif device.preferences.changeProfileTHP == "1" then

      device:try_update_metadata({profile = "temp-humid-press-therm-battery"})
  elseif device.preferences.changeProfileTHP == "5" then
      device:try_update_metadata({profile = "temp-humid-press-therm-battery-05"})  

  elseif device.preferences.changeProfileTHPI == "1" then
      device:try_update_metadata({profile = "temp-humidity-press-illum-therm"})
  elseif device.preferences.changeProfileTHPI == "5" then
      device:try_update_metadata({profile = "temp-humidity-press-illum-therm-05"})  

  elseif device.preferences.changeProfileMT =="1" then
      device:try_update_metadata({profile = "motion-temp-therm-battery"})
  elseif device.preferences.changeProfileMT =="5" then
      device:try_update_metadata({profile = "motion-temp-therm-battery-05"})  

  elseif device.preferences.changeProfileMTH == "1" then
      device:try_update_metadata({profile = "motion-temp-humid-therm-battery"})
  elseif device.preferences.changeProfileMTH == "5" then
      device:try_update_metadata({profile = "motion-temp-humid-therm-battery-05"})

  elseif device.preferences.changeProfileCT == "1" then
      device:try_update_metadata({profile = "contact-acc-temp-therm-battery"})
  elseif device.preferences.changeProfileCT == "5" then
      device:try_update_metadata({profile = "contact-acc-temp-therm-battery-05"})  

  elseif device.preferences.changeProfileCTB == "1" then
      device:try_update_metadata({profile = "contact-temp-therm-battery"})
  elseif device.preferences.changeProfileCTB == "5" then
      device:try_update_metadata({profile = "contact-temp-therm-battery-05"})
  elseif device.preferences.changeProfileBTB == "1" then
      device:try_update_metadata({profile = "button-temp-therm-battery"})
  elseif device.preferences.changeProfileBTB == "5" then
      device:try_update_metadata({profile = "button-temp-therm-battery-05"}) 
  end
end

--- do_init
local function do_init (self, device)

  -- set intial profile
  initial_profile(self, device)

  --set supported modes
  thermostat_Modes_Supported(self, device)

  if device:get_manufacturer() == "_TZ2000_a476raq2"
    or device:get_manufacturer() == "CentraLite"
    or device:get_manufacturer() == "iMagic by GreatStar"
    or device:get_manufacturer() == "Bosch"
    or (device:get_manufacturer() == "Samjin" and device:get_model() == "button")
    --or device:get_manufacturer() == "SONOFF" and device:get_model() == "SNZB-02D"
    or device:get_manufacturer() == "SmartThings" then

      battery_defaults.build_linear_voltage_init(2.3, 3.0)
  end

  if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
    device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
  end

  thermostat_Run = "stopped"
  device:set_field("thermostat_Run", thermostat_Run, {persist = false})
 
  --thermostat_Mode = device:get_field("thermostat_Mode")
  thermostat_Mode = device:get_latest_state("main", capabilities.thermostatMode.ID, capabilities.thermostatMode.thermostatMode.NAME)
  if thermostat_Mode == nil then 
    thermostat_Mode = "off"
    device:emit_event(capabilities.thermostatMode.thermostatMode(thermostat_Mode))
    --Save thermostatMode
    --device:set_field("thermostat_Mode", thermostat_Mode, {persist = false})
  end
  --Save thermostatMode
  device:set_field("thermostat_Mode", thermostat_Mode, {persist = false})

  -- Save thermostatOperatingState
  thermostatOperatingState = device:get_latest_state("main", capabilities.thermostatOperatingState.ID, capabilities.thermostatOperatingState.thermostatOperatingState.NAME)
  --print("<<< thermostatOperatingState >>>",thermostatOperatingState)
  if thermostatOperatingState == nil then
    thermostatOperatingState ="idle"
    device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
  end
  device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = false})

 -- Save thermostatFan_Mode
  device:set_field("onCyclicStep", 0, {persist = false})
  device:set_field("offCyclicStep", 0, {persist = false})
  device:set_field ("timer_cycleCurrent", "stopped", {persist = false})
  --thermostatFan_Mode = device:get_field("thermostatFan_Mode")
  thermostatFan_Mode = device:get_latest_state("main", capabilities.thermostatFanMode.ID, capabilities.thermostatFanMode.thermostatFanMode.NAME)
  if thermostatFan_Mode == nil then 
    thermostatFan_Mode = "auto"
    device:set_field ("cycleCurrent", "stop", {persist = false})
    device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
    device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
    device:emit_event(capabilities.thermostatFanMode.thermostatFanMode(thermostatFan_Mode))
  elseif thermostatFan_Mode == "followschedule" then
    if device:get_latest_state("main", fan_Cyclic_Mode.ID, fan_Cyclic_Mode.fanCyclicMode.NAME) == "On" then
      device:set_field ("cycleCurrent", "on", {persist = false})
    else
      device:set_field ("cycleCurrent", "off", {persist = false})
    end
  else
    device:set_field ("cycleCurrent", "stop", {persist = false})
  end

  --Save thermostatFanMode
  device:set_field("thermostatFan_Mode", thermostatFan_Mode, {persist = false})
  
  -- initialize Temp set points
  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  local cap_state = device:get_latest_state("main", capabilities.thermostatHeatingSetpoint.ID, capabilities.thermostatHeatingSetpoint.heatingSetpoint.NAME)
  if cap_state == nil then cap_state = device.preferences.heatTempAuto end
  --if device:get_field("heating_Setpoint") == nil then 
  device:set_field("heating_Setpoint", cap_state, {persist = false})
  device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = device:get_field("heating_Setpoint"), unit = temp_scale }))
  --end

  cap_state = device:get_latest_state("main", capabilities.thermostatCoolingSetpoint.ID, capabilities.thermostatCoolingSetpoint.coolingSetpoint.NAME)
  if cap_state == nil then cap_state = device.preferences.coolTempAuto end
  --if device:get_field("cooling_Setpoint") == nil then 
  device:set_field("cooling_Setpoint", cap_state, {persist = false})
  device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = device:get_field("cooling_Setpoint"), unit = temp_scale }))
  --end

  --- thermostat lock state initialize
  cap_state = device:get_latest_state("main", thermostat_Locked.ID, thermostat_Locked.thermostatLocked.NAME)
  if cap_state == nil then cap_state =  "Unlocked" end
  --if device:get_field("thermostat_Lock") == nil then 
  device:set_field("thermostat_Lock", cap_state, {persist = false}) --end
  device:emit_event(thermostat_Locked.thermostatLocked(device:get_field("thermostat_Lock")))
  --end

 --- if thermostat initialized by hub reboot
 if thermostat_Mode ~= "off" or thermostatFan_Mode == "followschedule" then
  thermostatMode_handler(self, device, "init")
 end

end

--- Update preferences after infoChanged recived---
local function do_Preferences (self, device)
 for id, value in pairs(device.preferences) do
  if device.preferences.logDebugPrint == true then
    print("device.preferences[infoChanged]=", device.preferences[id])
  end
  local oldPreferenceValue = device:get_field(id)
  local newParameterValue = device.preferences[id]
   if oldPreferenceValue ~= newParameterValue then
    device:set_field(id, newParameterValue, {persist = true})
    print("<< Preference changed:", id, "old value:", oldPreferenceValue, "new value:", newParameterValue)
    if id == "thermTempUnits" then
      --device:get_field("heating_Setpoint")
      local temp_scale =  "C"
      if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
      device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = device:get_field("heating_Setpoint"), unit = temp_scale }))
      device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = device:get_field("cooling_Setpoint"), unit = temp_scale }))
    end
      ------ Change profile Temp Set points steps
    if id == "changeProfileTH" then
        if newParameterValue == "1" then
         device:try_update_metadata({profile = "temp-humid-therm-battery"})
        elseif newParameterValue == "5" then
         device:try_update_metadata({profile = "temp-humid-therm-battery-05"})
        end
    elseif id == "changeProfileTHP" then
        if newParameterValue == "1" then
         device:try_update_metadata({profile = "temp-humid-press-therm-battery"})
        elseif newParameterValue == "5" then
         device:try_update_metadata({profile = "temp-humid-press-therm-battery-05"})  
        end
    elseif id == "changeProfileTHPI" then
        if newParameterValue == "1" then
         device:try_update_metadata({profile = "temp-humidity-press-illum-therm"})
        elseif newParameterValue == "5" then
         device:try_update_metadata({profile = "temp-humidity-press-illum-therm-05"})  
        end
    elseif id == "changeProfileMT" then
        if newParameterValue == "1" then
         device:try_update_metadata({profile = "motion-temp-therm-battery"})
        elseif newParameterValue == "5" then
         device:try_update_metadata({profile = "motion-temp-therm-battery-05"})  
        end
    elseif id == "changeProfileMTH" then
        if newParameterValue == "1" then
         device:try_update_metadata({profile = "motion-temp-humid-therm-battery"})
        elseif newParameterValue == "5" then
         device:try_update_metadata({profile = "motion-temp-humid-therm-battery-05"})
        end 
    elseif id == "changeProfileCTB" then
        if newParameterValue == "1" then
         device:try_update_metadata({profile = "contact-temp-therm-battery"})
        elseif newParameterValue == "5" then
         device:try_update_metadata({profile = "contact-temp-therm-battery-05"})  
        end
    elseif id == "changeProfileCT" then
        if newParameterValue == "1" then
         device:try_update_metadata({profile = "contact-acc-temp-therm-battery"})
        elseif newParameterValue == "5" then
         device:try_update_metadata({profile = "contact-acc-temp-therm-battery-05"})  
        end
    elseif id == "changeProfileBTB" then
        if newParameterValue == "1" then
         device:try_update_metadata({profile = "button-temp-therm-battery"})
        elseif newParameterValue == "5" then
         device:try_update_metadata({profile = "button-temp-therm-battery-05"})  
        end
    elseif id == "useMultipleSensors" or id == "calculationType" or id == "thermostatGroup" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.preferences.thermostatGroup > 0 then
            -- calculate group temperature
            thermostat_group.temperature_calculation(self, dev, dev.preferences.thermostatGroup)
            -- refresh thermostat
            thermostat_data_check (self, dev)
          else
            dev:emit_event(device_Info.deviceInfo({value = "Device not assigned to any Group"}, {visibility = {displayed = false}}))
          end
        end
    end
    -- thermostat calculations
    thermostatMode_handler(self,device,"init")
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
  --- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- attributte handler Atmospheric pressure
local pressure_value_attr_handler = function (driver, device, value, zb_rx)
  local kPa = value.value / 10
  device: emit_event (capabilities.atmosphericPressureMeasurement.atmosphericPressure ({value = kPa, unit = "kPa"}))

  -- emit even for custom capability in mBar
  local mBar = value.value
  device:emit_event(atmos_Pressure.atmosPressure(mBar))
end

--- temperature handler
local function temp_attr_handler(self, device, tempvalue, zb_rx)

  -- emit signal metrics
  signal.metrics(device, zb_rx)

  if device:get_manufacturer() == "LUMI" and device:get_model()== "lumi.weather" then -- ramdomly send value 0º or -100º
    if tempvalue.value <= -9900 then return end
    if tempvalue.value == 0 then
      if device:get_field("last_temp") == nil then
        return
      else
        if (math.abs((tempvalue.value / 100) - device:get_field("last_temp"))) > 3 then
          device:set_field("last_temp", tempvalue.value / 100, {persist = false})
          return
        end
      end
    end
  end

  -- reduce events to temp change > 0.06 and 0.3 if mode = Off
  local ref_event_temp = tempvalue.value
  local temp_filter = 7
  if device:get_field("thermostat_Mode") == "off" and device.preferences.thermostatGroup == 0 then 
    temp_filter = 30
  else
    --if device:get_field("thermostatOperatingState") == "idle" then temp_filter = 0 end
    temp_filter = 0
  end

  if device.preferences.thermostatGroup == 0 then
    device:emit_event(device_Info.deviceInfo({value = "Device not assigned to any Group"}, {visibility = {displayed = false}}))
  else
    --if device.preferences.useMultipleSensors == true then
      --ref_event_temp = ref_event_temp - device.preferences.tempOffset -- temp saved in group temp calculation include offset
    --end
  end

  if device:get_field("ref_event_temp") == nil then device:set_field("ref_event_temp", 0, {persist = false}) end
  if math.abs(ref_event_temp - device:get_field("ref_event_temp")) >= temp_filter then
      -- get current temp for thermostat state control 
      local last_temp = tempvalue.value / 100
      local need_refresh = true
      if device:get_field("last_temp") == last_temp and device:get_manufacturer() ~= "LUMI" and device:get_model() ~= "lumi.weather" then
        need_refresh = false
      end
      device:set_field("last_temp", last_temp, {persist = false})
      device:set_field("ref_event_temp", ref_event_temp, {persist = false})
      --emit event
      tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)

    if device:get_field("thermostat_Mode") == "off" then
      local temp = last_temp -- + device.preferences.tempOffset
      local scale = "C"
      if device.preferences.thermTempUnits == "Fahrenheit" then
        scale = "F"
        temp = (temp * 9/5) + 32
      end
      temp = temp + device.preferences.tempOffset
      local text = "Temp: "..temp.."º"..scale.."-> No Expected Status Change"
      device:emit_event(info_Panel.infoPanel(text))
    else
      if need_refresh == true then
        thermostat_data_check (self, device)
      end
    end

    if device.preferences.thermostatGroup > 0 and need_refresh == true then
      -- calculate group temperature
      thermostat_group.temperature_calculation(self, device, device.preferences.thermostatGroup)
      -- refresh thermostat
      for uuid, dev in pairs(device.driver:get_devices()) do
        if device.preferences.thermostatGroup == dev.preferences.thermostatGroup then
          if dev.preferences.useMultipleSensors == true then
            thermostat_data_check (self, dev)
          end
        end
      end
    end

  end
end

---- thermostat_Lock Handler ---------------------------
local function thermostatLocked_handler(self,device,command)
  print("thermostatLock State=", command.args.value)
  local thermostat_Lock = command.args.value
  device:emit_event(thermostat_Locked.thermostatLocked(thermostat_Lock))
  --Save thermostat_Locked
  device:set_field("thermostat_Lock", thermostat_Lock, {persist = false})
end

---illuminance_measurement_defaults
local function illuminance_measurement_defaults(driver, device, value, zb_rx)
  local lux_value = math.floor(10 ^ ((value.value - 1) / 10000))
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(lux_value))
end

-----driver_switched
local function driver_switched(self,device)
  device.thread:call_with_delay(5, function() 
    do_Configure(self,device)
   end)
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
  local function lazy_load_if_possible(sub_driver_name)
    -- gets the current lua libs api version
    local version = require "version"
  
    --print("<<<<< Library Version:", version.api)
    -- version 9 will include the lazy loading functions
    if version.api >= 9 then
      return ZigbeeDriver.lazy_load_sub_driver(require(sub_driver_name))
    else
      return require(sub_driver_name)
    end
  end

  local function do_refresh(driver, device)
    if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
      device:send(tempMeasurement.attributes.MeasuredValue:read(device))
    end
    device:refresh()
  end

----- driver template ----------
local zigbee_thermostat_driver = {
  supported_capabilities = {
    capabilities.motionSensor,
    capabilities.contactSensor,
    capabilities.threeAxis,
    capabilities.accelerationSensor,
    --capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.atmosphericPressureMeasurement,
    capabilities.illuminanceMeasurement,
    capabilities.button,
    atmos_Pressure,
    thermostat_Locked,
    capabilities.thermostatMode,
    capabilities.thermostatOperatingState,
    capabilities.thermostatFanMode,
    fan_Cyclic_Mode,
    fan_Next_Change,
    capabilities.thermostatHeatingSetpoint,
    capabilities.thermostatCoolingSetpoint,
    info_Panel,
    capabilities.battery,
  },
  lifecycle_handlers = {
    init = do_init,
    infoChanged = do_Preferences,
    driverSwitched = driver_switched,
    doConfigure = do_Configure
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
    [thermostat_Locked.ID] = {
      [thermostat_Locked.commands.setThermostatLocked.NAME] = thermostatLocked_handler,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
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
        },
        [zcl_clusters.IlluminanceMeasurement.ID] = {
          [zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_measurement_defaults
        }
      },  
  },
  sub_drivers = {
    lazy_load_if_possible("battery"), 
    lazy_load_if_possible("multi-contact"), 
    lazy_load_if_possible("button")
  },

  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

--------- driver run ------
defaults.register_for_default_handlers( zigbee_thermostat_driver,  zigbee_thermostat_driver.supported_capabilities)
local thermostat = ZigbeeDriver(" zigbee_thermostat_driver",  zigbee_thermostat_driver)
thermostat:run()
