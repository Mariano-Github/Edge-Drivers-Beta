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
local thermostat_Locked = capabilities ["legendabsolute60149.thermostatLocked"]
local info_Panel = capabilities ["legendabsolute60149.infoPanel"]

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
  device:set_field("thermostat_Mode", thermostat_Mode, {persist = true})
   ---- set thermostat state
  if thermostat_Mode == "off" then
    thermostatOperatingState ="idle"
    device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
    device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = false})
    --emit thermostat change state info
    local text = "No Expected Change in Thermostat State"
    device:emit_event(info_Panel.infoPanel(text))

   ---- Timers Cancel ------
    for timer in pairs(device.thread.timers) do
     print("<<<<< Cancelando timer >>>>>")
     device.thread:cancel_timer(timer)
     device:set_field("thermostat_Run", "stopped", {persist = false})
     thermostat_Run = device:get_field("thermostat_Run")
     print("thermostat_Run", thermostat_Run)
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
    device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})
    device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true}) 
  end

  ---- set thermostat lock status
  if thermostat_Mode == "away" or thermostat_Mode == "manual" then
    device:emit_event(thermostat_Locked.thermostatLocked("Locked"))
    --Save thermostat_Locked
    device:set_field("thermostat_Lock", "Locked", {persist = true})
  else
    device:emit_event(thermostat_Locked.thermostatLocked("Unlocked"))
    --Save thermostat_Locked
    device:set_field("thermostat_Lock", "Unlocked", {persist = true})
  end

  --- thermostat run timer 
thermostat_Mode = device:get_field("thermostat_Mode")
print("Pre-timer Activation Thermostat Mode >>>>>>>>",thermostat_Mode)
local cycleCurrent = device:get_field("cycleCurrent")
if thermostat_Mode ~= "off" or cycleCurrent ~= "stop" then 

   ------ Timer activation
 thermostat_Run = device:get_field("thermostat_Run")
 print("Pre-timer Activation thermostat_Run >>>>>>",thermostat_Run)
 if thermostat_Run == "stopped" or thermostat_Run == nil then
  device:set_field("thermostat_Run", "running", {persist = false})
  device.thread:call_on_schedule(
   15,
   function ()
   print("<<< Cheking Temp >>>")
   print("device:", device)
   thermostat_Mode = device:get_field("thermostat_Mode")
   print("thermostat_Run =", device:get_field("thermostat_Run"))
   
   --local last_temp = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME) + device.preferences.tempOffset
   --last_temp = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME) + device.preferences.tempOffset

   local last_temp = device:get_field("last_temp")
   if last_temp == nil then 
     last_temp = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME) + device.preferences.tempOffset
   else
    last_temp = last_temp + device.preferences.tempOffset
   end
   if device.preferences.thermTempUnits == "Fahrenheit" then
    last_temp = (last_temp * 9/5) + 32
   end

   --local thermostatOperatingState = device:get_latest_state("main", capabilities.thermostatOperatingState.ID, capabilities.thermostatOperatingState.thermostatOperatingState.NAME)
   thermostatOperatingState = device:get_field("thermostatOperatingState")
   local heating_Setpoint = device:get_field("heating_Setpoint")
   local cooling_Setpoint = device:get_field("cooling_Setpoint")
   print("thermostatOperatingState Before =",thermostatOperatingState)
   print("thermostat_Mode =",thermostat_Mode)
   local current_temp = tonumber(string.format("%.2f", last_temp)) 
   thermostatFan_Mode = device:get_field("thermostatFan_Mode")
   print("thermostatFan_Mode =", thermostatFan_Mode)   
   cycleCurrent = device:get_field("cycleCurrent")
   print("cycleCurrent =", cycleCurrent)
  
   ------------ Fanc Circulate Cycling handler -------------
    thermostatFan_Mode = device:get_field ("thermostatFan_Mode")
    if device.preferences.fanCyclic == "Yes" then
      local onCyclicTotalSteps = device.preferences.onTime * 60  / 15
      local offCyclicTotalSteps = device.preferences.offTime * 60  / 15

      if device:get_field("cycleCurrent") == "off" then
       local offCyclicStep = device:get_field("offCyclicStep") + 1
       device:set_field("offCyclicStep", offCyclicStep, {persist = false})
       print("offCyclicStep, offCyclicTotalSteps", device:get_field("offCyclicStep"),offCyclicTotalSteps)
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
        print("onCyclicStep, onCyclicTotalSteps", device:get_field("onCyclicStep"),onCyclicTotalSteps)
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

  ---calculate temps for state change
  local tempChangeToPendingHeat = (device:get_field("heating_Setpoint") - (device.preferences.diffStartStop / 2))
  local tempChangeToHeating = device:get_field("heating_Setpoint") - (device.preferences.diffStartStop)
  local tempChangeToPendingCool = (device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop / 2))  
  local tempChangeToCooling = device:get_field("cooling_Setpoint") + (device.preferences.diffStartStop)
  
  -- Re-Calculate temp Change To Heating and Cooling for radiant floor and Temp Units
  local unitsCorrection = 1
  if device.preferences.thermTempUnits =="Celsius" then unitsCorrection = 1 else unitsCorrection =2 end
  if device.preferences.floorRadaint == "Heat" then
   tempChangeToHeating = tempChangeToPendingHeat - (0.15 * unitsCorrection)
  elseif device.preferences.floorRadaint == "HeatCool" then
   tempChangeToHeating = tempChangeToPendingHeat - (0.15 * unitsCorrection)
   tempChangeToCooling = tempChangeToPendingCool + (0.15 * unitsCorrection)
  end

  ---- Print values for thermostat state Calculate
  print("device.preferences.floorRadaint =", device.preferences.floorRadaint)
  print("device.preferences.temperature DiffStarStop =", device.preferences.diffStartStop)
  print("*** Current_temp ***", current_temp, device.preferences.thermTempUnits)
  print("## heating_Setpoint ##",device:get_field("heating_Setpoint"))
  print("tempChangeToHeating <=", tempChangeToHeating)
  print("tempChangeToPendingHeat >", tempChangeToPendingHeat)
  print("## cooling_Setpoint ##",device:get_field("cooling_Setpoint"))
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
     device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = false})
    
     -- emit thermostat information for next change state
     local temp_scale = "C"
     if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
     local text = "No Expected Change in Thermostat State"
     if thermostatOperatingState == "heating" then
      text = "T= "..current_temp.."º"..temp_scale..", Next State: Pending Heat, T > "..string.format("%.2f",tempChangeToPendingHeat).."º"..temp_scale
     elseif thermostatOperatingState == "cooling"  then
      text = "T= "..current_temp.."º"..temp_scale..", Next State: Pending Cool, T < "..string.format("%.2f",tempChangeToPendingCool).."º"..temp_scale
     elseif thermostatOperatingState == "pending heat" then
      text = "T= "..current_temp.."º"..temp_scale..", Next State: Heating, T <= "..string.format("%.2f",tempChangeToHeating).."º"..temp_scale
     elseif thermostatOperatingState == "pending cool" then
      text = "T= "..current_temp.."º"..temp_scale..", Next State: Cooling, T >= "..string.format("%.2f",tempChangeToCooling).."º"..temp_scale
     end 
     device:emit_event(info_Panel.infoPanel(text))

     --Emit event Fan status
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

  --if locked then emit old value
  if device:get_field("thermostat_Lock") == "Locked" then heating_Setpoint = device:get_field("heating_Setpoint") end

  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))

  --Save HeatingSetpoint
  device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})

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
  device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true})

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
  device:set_field("thermostatFan_Mode", thermostatFan_Mode, {persist = true})

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
     device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))       
     if thermostat_Mode == "off" then
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState("fan only"))
      device:set_field ("thermostatOperatingState", "fan only", {persist = false})
     end     
    
    elseif thermostatFan_Mode == "circulate" then
     device:set_field ("cycleCurrent", "stop", {persist = false})
     device:emit_event(fan_Cyclic_Mode.fanCyclicMode("On"))
     if thermostat_Mode == "off" then
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState("vent economizer"))
      device:set_field ("thermostatOperatingState", "vent economizer", {persist = false})
     end 
    
    elseif thermostatFan_Mode == "auto" then
      device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
      thermostatOperatingState = device:get_field("thermostatOperatingState")
      device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
      device:set_field ("thermostatOperatingState",thermostatOperatingState, {persist = false})
      device:set_field ("cycleCurrent", "stop", {persist = false})
    
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
      device:set_field ("offCyclicStep", offCyclicStep, {persist = false})
      device:set_field ("onCyclicStep", onCyclicStep, {persist = false})
      device:set_field ("cycleCurrent", cycleCurrent, {persist = false})
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

 if device:get_manufacturer() == "KMPCIL" then
  local maxTime = 900
  local changeRep = math.floor(10000 * (math.log((2), 10)))
  print ("Illumin maxTime & changeRep: ", maxTime, changeRep)
  device:send(device_management.build_bind_request(device, zcl_clusters.IlluminanceMeasurement.ID, self.environment_info.hub_zigbee_eui))
  device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
 end
  device:configure()

end

--- do_init
local function do_init (self, device)

  --device:configure()

  thermostat_Run = "stopped"
  device:set_field("thermostat_Run", thermostat_Run, {persist = false})

  device:set_field("onCyclicStep", 0, {persist = false})
  device:set_field("offCyclicStep", 0, {persist = false})
  device:set_field ("cycleCurrent", "stop", {persist = false})
 
  thermostat_Mode = device:get_field("thermostat_Mode")
  if thermostat_Mode == nil then thermostat_Mode = "off" end
  device:emit_event(capabilities.thermostatMode.thermostatMode(thermostat_Mode))
  --Save thermostatMode
  device:set_field("thermostat_Mode", thermostat_Mode, {persist = true}) 

  thermostatOperatingState = device:get_field("thermostatOperatingState")
  if thermostatOperatingState == nil then thermostatOperatingState ="idle" end  
  device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
  device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = false})  
 
  thermostatFan_Mode = device:get_field("thermostatFan_Mode")
  if thermostatFan_Mode == nil then thermostatFan_Mode = "auto" end
  device:emit_event(capabilities.thermostatFanMode.thermostatFanMode(thermostatFan_Mode))

  device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
  device:emit_event(fan_Next_Change.fanNextChange("Inactive"))
  --Save thermostatFanMode
  device:set_field("thermostatFan_Mode", thermostatFan_Mode, {persist = true})
  
  -- initialize Temp set points
  if device:get_field("heating_Setpoint") == nil then device:set_field("heating_Setpoint", device.preferences.heatTempAuto, {persist = true}) end
  if device:get_field("cooling_Setpoint") == nil then device:set_field("cooling_Setpoint", device.preferences.heatTempAuto, {persist = true}) end

  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  device:emit_event_for_endpoint("main", capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = device:get_field("heating_Setpoint"), unit = temp_scale }))
  device:emit_event_for_endpoint("main", capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = device:get_field("cooling_Setpoint"), unit = temp_scale }))

  --- thermostat lock state initialize
  if device:get_field("thermostat_Lock") == nil then device:set_field("thermostat_Lock", "Unlocked", {persist = true}) end
  device:emit_event(thermostat_Locked.thermostatLocked(device:get_field("thermostat_Lock")))

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

  -- reduce events to temp change > 0.06
  local ref_event_temp = tempvalue.value
  if device:get_field("ref_event_temp") == nil then device:set_field("ref_event_temp", 0, {persist = false}) end
  if math.abs(ref_event_temp - device:get_field("ref_event_temp")) > 6 or device:get_field("thermostatOperatingState") == "idle" then
    -- get current temp for thermostat state control 
    local last_temp = tempvalue.value / 100
    device:set_field("last_temp", last_temp, {persist = false})
    device:set_field("ref_event_temp", ref_event_temp, {persist = false})
    --emit event
    tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)
   if device:get_field("thermostat_Mode") == "off" then
     local temp = last_temp + device.preferences.tempOffset
     local scale = "C"
    if device.preferences.thermTempUnits == "Fahrenheit" then
      scale = "C"
      temp = (temp * 9/5) + 32
    end
    local text = "Temperature: "..temp.."º"..scale..", Thermostat Mode: "..device:get_field("thermostat_Mode")
    device:emit_event(info_Panel.infoPanel(text))
  end
  end
end

---- thermostat_Lock Handler ---------------------------
local function thermostatLocked_handler(self,device,command)
  print("thermostatLock State=", command.args.value)
  local thermostat_Lock = command.args.value
  device:emit_event(thermostat_Locked.thermostatLocked(thermostat_Lock))
  --Save thermostat_Locked
  device:set_field("thermostat_Lock", thermostat_Lock, {persist = true})
end

---illuminance_measurement_defaults
local function illuminance_measurement_defaults(driver, device, value, zb_rx)
  local lux_value = math.floor(10 ^ ((value.value - 1) / 10000))
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(lux_value))
end

-----driver_switched
local function driver_switched(self,device)
  device.thread:call_with_delay(5, function() do_Configure(self,device) end)
end


----- driver template ----------
local zigbee_motion_driver = {
  supported_capabilities = {
    capabilities.motionSensor,
    capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.atmosphericPressureMeasurement,
    capabilities.illuminanceMeasurement,
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
    added = thermostat_Modes_Supported,
    driverSwitched = driver_switched
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
  sub_drivers = {require("battery")},
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

--------- driver run ------
defaults.register_for_default_handlers(zigbee_motion_driver, zigbee_motion_driver.supported_capabilities)
local motion = ZigbeeDriver("st-zigbee-motion", zigbee_motion_driver)
motion:run()
