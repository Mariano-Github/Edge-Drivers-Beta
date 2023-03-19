-- Thermostat subdriver Zwave
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

------ Author Mariano Colmenarejo (Oct 2022) --------

--- @type st.zwave.CommandClass.SensorMultilevel
local SensorMultilevel = (require "st.zwave.CommandClass.SensorMultilevel")({version=5})
local capabilities = require "st.capabilities"
local refresh_thermostat = require "refresh-thermostat"
--local utils = require "st.utils"

--- Custom Capabilities
local fan_Cyclic_Mode = capabilities["legendabsolute60149.fanCyclicMode"]
local fan_Next_Change = capabilities["legendabsolute60149.fanNextChange"]
local thermostat_Locked = capabilities ["legendabsolute60149.thermostatLocked"]
local info_Panel = capabilities ["legendabsolute60149.infoPanel"]

--- variables initialization
local thermostat_Run = "stopped"
local thermostat_Mode = "off"
local thermostatFan_Mode = "auto"
local thermostatOperatingState = "idle"
--local temp_refresh = os.time()
local last_temp = 0
local stateUnit ={}
stateUnit.unit = "C"

local can_handle = function(opts, driver, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then
    return true
  else
    return false
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
  device:set_field("thermostat_Mode", thermostat_Mode, {persist = true})
   ---- set thermostat state
  if thermostat_Mode == "off" then
    thermostatOperatingState ="idle"
    device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
    device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = false})
    --emit thermostat change state info
    local text = "No Expected Change in Thermostat State"
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
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))
    device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))
    --Save Setpoints
    device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})
    device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true}) 
  end

  ---- set thermostat lock status
  if (thermostat_Mode == "away" or thermostat_Mode == "manual") and device:get_field("thermostat_Lock") == "Unlocked" then
    device:emit_event(thermostat_Locked.thermostatLocked("Locked"))
    --Save thermostat_Locked
    device:set_field("thermostat_Lock", "Locked", {persist = true})
  --else
    --device:emit_event(thermostat_Locked.thermostatLocked("Unlocked"))
    --Save thermostat_Locked
    --device:set_field("thermostat_Lock", "Unlocked", {persist = true})
  end

  --- thermostat run timer 
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
  refresh_thermostat.thermostat_data_check (self, device)
end

----- activate timer for fan_cycle
if cycleCurrent ~= "stop" and device:get_field ("timer_cycleCurrent")~= "running" then
  device:set_field ("timer_cycleCurrent", "running", {persist = false})

  ---- Temperature Timer Cancel ------
  for timer in pairs(device.thread.timers) do
    print("<<<<< Cancelando Temp timer >>>>>")
    device.thread:cancel_timer(timer)
  end

  print("<<< Init Fan Cycle Timer >>>")
  local thermostat_timer = 60
  device.thread:call_on_schedule(
    thermostat_timer,
  function ()
    print("<<< Cheking Temp >>>")
    --print("device:", device)
  
    ------------ Fanc Circulate Cycling handler -------------
      thermostatFan_Mode = device:get_field ("thermostatFan_Mode")
      if device.preferences.fanCyclic == "Yes" then
        local onCyclicTotalSteps = device.preferences.onTime * 60  / thermostat_timer
        local offCyclicTotalSteps = device.preferences.offTime * 60  / thermostat_timer

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
  device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = heating_Setpoint, unit = temp_scale }))

  --Save HeatingSetpoint
  device:set_field("heating_Setpoint", heating_Setpoint, {persist = true})

  -- thermostat calculations
  refresh_thermostat.thermostat_data_check (self, device)
end

---- coolingSetpoint_handler
local function coolingSetpoint_handler(self,device,command)

  --print("CoolingSetpoint", command.args.setpoint)
  local cooling_Setpoint = command.args.setpoint

  --if locked then emit old value
  if device:get_field("thermostat_Lock") == "Locked" then cooling_Setpoint = device:get_field("cooling_Setpoint") end

  local temp_scale = "C"
  if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
  device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = cooling_Setpoint, unit = temp_scale }))

  --Save CoolSetpoint
  device:set_field("cooling_Setpoint", cooling_Setpoint, {persist = true})

  -- thermostat calculations
  refresh_thermostat.thermostat_data_check (self, device)
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
      print("<<<<< Cancelando timers >>>>>")
      device.thread:cancel_timer(timer)
      device:set_field("thermostat_Run", "stopped", {persist = false})
      thermostat_Run = device:get_field("thermostat_Run")
      print("thermostat_Run", thermostat_Run)
    end
    -- initialize temperature timer
    --temperature_timer(self, device)
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
      if thermostat_Mode == "off" then
        device:emit_event(fan_Cyclic_Mode.fanCyclicMode("Off"))
        device:set_field("cycleCurrent", "off", {persist = false})
        device:set_field ("thermostatOperatingState", "idle", {persist = false})
      end 
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
      if device.preferences.logDebugPrint == true then
        print("onCyclicStep, offCyclicStep, cycleCurrent", device:get_field ("onCyclicStep"),device:get_field ("offCyclicStep"),device:get_field ("cycleCurrent"))
      end
     end     
    end

   if thermostatFan_Mode == "followschedule" or thermostat_Mode ~= "off" then
    command.args.mode = thermostat_Mode
    thermostatMode_handler(self,device,command)
   end
end

--- added thermostat_Modes_Supported
local function thermostat_Modes_Supported(self,device)
  print("<< thermostat_Modes_Supported >>")
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

--- do_init
local function do_init (self, device)

  --- added thermostat_Modes_Supported
  thermostat_Modes_Supported(self,device)

  --Initialize selected profile
  print("<<< Set Selected profile >>>")
  print("<<< device.preferences.changeProfileTherm >>>",device.preferences.changeProfileTherm)
  print("<<< device.preferences.multiTile >>>",device.preferences.multiTile)

  if device.preferences.changeProfileTherm == "1" and device.preferences.multiTile == false then
    print("<<< child-thermostat >>>")
    device:try_update_metadata({profile = "child-thermostat"})
  elseif device.preferences.changeProfileTherm == "1" and device.preferences.multiTile == true then
    print("<<< child-thermostat-multi >>>")
    device:try_update_metadata({profile = "child-thermostat-multi"})
  elseif device.preferences.changeProfileTherm == "5" and device.preferences.multiTile == false then
    print("<<< child-thermostat-05 >>>")
    device:try_update_metadata({profile = "child-thermostat-05"})
  elseif device.preferences.changeProfileTherm == "5" and device.preferences.multiTile == true then
    print("<<< child-thermostat-multi-05 >>>")
    device:try_update_metadata({profile = "child-thermostat-multi-05"})
  end


  --temp_refresh = os.time()
  device:set_field("temp_refresh", os.time(), {persist = false})


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
  device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = device:get_field("heating_Setpoint"), unit = temp_scale }))
  device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = device:get_field("cooling_Setpoint"), unit = temp_scale }))

  --- thermostat lock state initialize
  if device:get_field("thermostat_Lock") == nil then device:set_field("thermostat_Lock", "Unlocked", {persist = true}) end
  device:emit_event(thermostat_Locked.thermostatLocked(device:get_field("thermostat_Lock")))

 --- if thermostat initialized or hub reboot
 if thermostat_Mode ~= "off" or thermostatFan_Mode == "followschedule" then
  thermostatMode_handler(self,device,"init")
 else

 end

end

--- added thermostat_Modes_Supported
local function added_device(self,device)
    print("Adding EDGE_CHILD device...")
      local parent_device = device:get_parent_device()
      print("<<<< parent_device", parent_device)

      -- emit and save last parent device temperature
    if parent_device ~= nil then
      print("<<<< device.parent.ID >>>>>",device.parent_device_id)
      print("<<<< child_device.ID >>>>>",device.id)
      if device:get_field("last_temp") == nil or device:get_field("last_temp") == 0 then
        stateUnit.unit = "C"
        last_temp, stateUnit = parent_device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME)
        if last_temp == nil then 
          if device:get_field("last_temp") == nil then
            print("<<< Waiting Temperature event >>>")
            parent_device:send(SensorMultilevel:Get({sensor_type = SensorMultilevel.sensor_type.TEMPERATURE},{dst_channels = {0x08}}))
            return
          else
            last_temp = device:get_field("last_temp")
            stateUnit.unit = device:get_field("stateUnit")
          end
        end
        if device.preferences.logDebugPrint == true then
         print("<<<<< last_temp >>>>>", last_temp)
         print("<<<<< stateUnit >>>>>", stateUnit.unit)
        end
        device:set_field("last_temp", last_temp, {persist = false})
        device:set_field("stateUnit", stateUnit.unit, {persist = false})

        device:emit_event(capabilities.temperatureMeasurement.temperature({value = last_temp, unit = stateUnit.unit }))
        --emit thermostat change state info
        local text = "No Expected Change in Thermostat State"
        device:emit_event(info_Panel.infoPanel(text))
      end

      do_init(self, device)

      -- thermostat calculations
      refresh_thermostat.thermostat_data_check (self, device)
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
      print("<< Preference changed name:", id, "old value:", oldPreferenceValue, "new value:",  newParameterValue)
      if id == "thermTempUnits" then
        local temp_scale =  "C"
        if device.preferences.thermTempUnits == "Fahrenheit" then temp_scale = "F" end
        device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = device:get_field("heating_Setpoint"), unit = temp_scale }))
        device:emit_event(capabilities.thermostatCoolingSetpoint.coolingSetpoint({value = device:get_field("cooling_Setpoint"), unit = temp_scale }))

        -- thermostat calculations
        --refresh_thermostat.thermostat_data_check (self, device)
      end
      ------ Change profile Temp Set points steps
      if id == "changeProfileTherm" or id == "multiTile" then
        if device.preferences.logDebugPrint == true then
          print("<<< device.preferences.changeProfileTherm >>>",device.preferences.changeProfileTherm)
          print("<<< device.preferences.multiTile >>>",device.preferences.multiTile)
        end
        if device.preferences.changeProfileTherm == "1" and device.preferences.multiTile == false then
          print("<<< child-thermostat >>>")
          device:try_update_metadata({profile = "child-thermostat"})
        elseif device.preferences.changeProfileTherm == "1" and device.preferences.multiTile == true then
          print("<<< child-thermostat-multi >>>")
          device:try_update_metadata({profile = "child-thermostat-multi"})
        elseif device.preferences.changeProfileTherm == "5" and device.preferences.multiTile == false then
          print("<<< child-thermostat-05 >>>")
          device:try_update_metadata({profile = "child-thermostat-05"})
        elseif device.preferences.changeProfileTherm == "5" and device.preferences.multiTile == true then
          print("<<< child-thermostat-multi-05 >>>")
          device:try_update_metadata({profile = "child-thermostat-multi-05"})
        end
      end

      -- thermostat calculations
      thermostatMode_handler(self,device,"init")
      --refresh_thermostat.thermostat_data_check (self, device)

    end
  end
  
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

---- thermostat_Lock Handler ---------------------------
local function thermostatLocked_handler(self,device,command)
  print("thermostatLock State=", command.args.value)
  local thermostat_Lock = command.args.value
  device:emit_event(thermostat_Locked.thermostatLocked(thermostat_Lock))
  --Save thermostat_Locked
  device:set_field("thermostat_Lock", thermostat_Lock, {persist = true})
end

-- refresh_handler
local function refresh_handler(driver, device)
  -- refresh temperature for Thermostat Child device
  print("<<< Refresh Child device >>>")
  local parent_device = device:get_parent_device()

  parent_device:send(SensorMultilevel:Get({sensor_type = SensorMultilevel.sensor_type.TEMPERATURE}))
  if parent_device:get_field("app_version") == 25 then
    parent_device:send(SensorMultilevel:Get({sensor_type = SensorMultilevel.sensor_type.TEMPERATURE}, {dst_channels = {0x02}}))
  end

  -- thermostat calculations
  refresh_thermostat.thermostat_data_check (driver, device)
end


----- driver template ----------
local thermostat_sub_driver = {
  NAME = "Thermostat subdriver",
  supported_capabilities = {
    thermostat_Locked,
    capabilities.thermostatMode,
    capabilities.thermostatOperatingState,
    capabilities.thermostatFanMode,
    fan_Cyclic_Mode,
    fan_Next_Change,
    capabilities.thermostatHeatingSetpoint,
    capabilities.thermostatCoolingSetpoint,
    info_Panel,
  },
  lifecycle_handlers = {
    init = do_init,
    infoChanged = do_Preferences,
    added = added_device,
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
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler,
    }
  },
  zigbee_handlers = {
    attr = {
    }
  },
  can_handle = can_handle
}

return thermostat_sub_driver
