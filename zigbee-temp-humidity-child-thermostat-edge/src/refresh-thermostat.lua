local capabilities = require "st.capabilities"


--- Custom Capabilities
local fan_Cyclic_Mode = capabilities["legendabsolute60149.fanCyclicMode"]
--local fan_Next_Change = capabilities["legendabsolute60149.fanNextChange"]
local info_Panel = capabilities ["legendabsolute60149.infoPanel"]

--- variables initialization
local thermostat_Run = "stopped"
local thermostat_Mode = "off"
local thermostatFan_Mode = "auto"
local thermostatOperatingState = "idle"


local refresh_thermostat = {}


-- thermostat calculation functions
function refresh_thermostat.thermostat_data_check(driver, device)
    print("<<< Cheking Temp >>>")
    --print("device:", device)
    thermostat_Mode = device:get_field("thermostat_Mode")
  
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
      -- if thermostat = off and fan in programming mode
      if thermostat_Mode == "off" then
        local text = "No Expected Change in Thermostat State"
        device:emit_event(info_Panel.infoPanel(text))
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
        if thermostatOperatingState ~= device:get_latest_state("main", capabilities.thermostatOperatingState.ID, capabilities.thermostatOperatingState.thermostatOperatingState.NAME) then
          device:emit_event(capabilities.thermostatOperatingState.thermostatOperatingState(thermostatOperatingState))
          device:set_field("thermostatOperatingState", thermostatOperatingState, {persist = false})
        end
        
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

  return refresh_thermostat