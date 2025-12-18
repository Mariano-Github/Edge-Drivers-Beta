
--local ZigbeeDriver = require "st.zigbee"
--local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
--local Basic = clusters.Basic

--local powerSource = capabilities.powerSource
local Thermostat = clusters.Thermostat
local ThermostatMode = capabilities.thermostatMode
local TemperatureMeasurement = capabilities.temperatureMeasurement
local ThermostatHeatingSetpoint = capabilities.thermostatHeatingSetpoint
local ThermostatOperatingState  = capabilities.thermostatOperatingState

local backlightLevel = capabilities["fabricbypass11616.backlightLevel"]
local keypadLock = capabilities["fabricbypass11616.keypadChildLock"]
--local keypadBeep = capabilities["fabricbypass11616.keypadBeep"]
local ThermostatWorkingDaySettings = capabilities["fabricbypass11616.thermostatWorkingDaySetting"]
--local statusTable = capabilities["fabricbypass11616.statusTable"]
local schedule = capabilities["fabricbypass11616.thermostatSchedule"]
local commands = require "avatto.commands"
local status = require "avatto.status"

local DEFAULT_SCHEDULE= "06:00 20.0; 08:00 16.0; 11:30 16.0; 12:30 16.0; 17:00 22.0; 22:00 16.0; 08:00 22.0; 23:00 16.0"

local ON = "\x01"
local OFF = "\x00"
local syncTimer = nil


local function do_refresh(self, device)
  print("<<<<<<<<<< do refresh >>>>>>>>>>")
  if device.preferences ~= nil then
    commands.syncDeviceTime(device, device.preferences.localTimeOffset)
  end
end

local function do_init(self, device)
  print("<<<<<<<<<< do init >>>>>>>>>>")
  syncTimer = nil

  if device:get_latest_state("main", backlightLevel.ID, backlightLevel.level.NAME) == nil then
    device:emit_event(backlightLevel.level({value = 2}, {visibility = {displayed = false}}))
    commands.setBackplaneBrightness(device, 2)
  end

  if device:get_latest_state("main", keypadLock.ID, keypadLock.lock.NAME) == nil then
    device:emit_event(keypadLock.lock.unlocked())
    commands.setChildLock(device, false)
  end

  if device:get_latest_state("main",ThermostatMode.ID, ThermostatMode.supportedThermostatModes.NAME) == nil then
    device:emit_event(ThermostatMode.supportedThermostatModes({"autowithreset", "manual", "auto"}, {visibility = {displayed = false}}))
  end

  local cap_status = device:get_latest_state("main",ThermostatOperatingState.ID, ThermostatOperatingState.thermostatOperatingState.NAME)
  if cap_status == nil then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.idle())
  end

  cap_status = device:get_latest_state("main",ThermostatMode.ID, ThermostatMode.thermostatMode.NAME)
  if cap_status == nil then
      device:emit_event(ThermostatMode.thermostatMode({value = "manual"}, {visibility = {displayed = false}}))
      commands.setThermostatMode(device, "manual")
  end

  if device:get_latest_state("main",ThermostatWorkingDaySettings.ID, ThermostatWorkingDaySettings.workingDaySetting.NAME) == nil then
    device:emit_event(ThermostatWorkingDaySettings.availableWorkingDaySetting({value = {"mondayToFriday","mondayToSaturday","mondayToSunday"}}, {visibility = {displayed = false}}))
    device:emit_event(ThermostatWorkingDaySettings.workingDaySetting("mondayToFriday",{ visibility = {displayed = false}}))
  end

  cap_status = device:get_latest_state("main",schedule.ID, schedule.schedule.NAME)
  if cap_status == nil then
    cap_status = DEFAULT_SCHEDULE
    device:emit_event(schedule.schedule({value = DEFAULT_SCHEDULE}, {visibility = {displayed = false}}))
  end
  commands.setPrograms(device, cap_status)  -- last Schedule

  cap_status = device:get_latest_state("main", ThermostatWorkingDaySettings.ID, ThermostatWorkingDaySettings.workingDaySetting.NAME)
  if cap_status == nil then 
    cap_status = "mondayToSunday"
    device:emit_event(ThermostatWorkingDaySettings.workingDaySetting("mondayToSunday", {visibility = {displayed = false}}))
    commands.setSchedule(device, cap_status)
  end

  -- set temperature range to -50ºc to 250ºc
  device:emit_event(capabilities.temperatureMeasurement.temperatureRange({ value = { minimum = -20, maximum = 100 }, unit = "C" }))
end

local function syncTimeTimer(device)
  local delay= function ()
    syncTimer = nil
  end
  if syncTimer == nil then
    commands.syncDeviceTime(device, device.preferences.localTimeOffset)
    syncTimer = device.thread:call_with_delay(3600, delay)
  end
end

local function do_configure(self, device)
  print("<<<<<<<<<< do configure >>>>>>>>>>")

  commands.setTempCorrection(device,  device.preferences.tempCorrection)    -- No correction or preference
  commands.setChildLock(device, false)                                      -- Unlock
  commands.setBackplaneBrightness(device, 2)                                -- Backplane Brightness level medium
  commands.setSensorSelection(device, device.preferences.sensorSelection)   -- Internal sensor or preference
  commands.setMaxTemperature(device, device.preferences.maxTemp)            -- 60ºc or preference
  commands.setFrostProtection(device, device.preferences.frostProtection)   -- Off or preference
  commands.setHysteresis(device, device.preferences.hysteresis)             -- 1º or prefernce
  local offset = device.preferences.localTimeOffset
  if offset == nil then offset = 1 end
  commands.syncDeviceTime(device, offset)                                   -- UTC + 1 or preference
  local cap_status = device:get_latest_state("main",schedule.ID, schedule.schedule.NAME)
  if cap_status == nil then
    cap_status = DEFAULT_SCHEDULE
    device:emit_event(schedule.schedule({value = DEFAULT_SCHEDULE}, {visibility = {displayed = false}}))
  end
  commands.setPrograms(device, cap_status)  -- last Schedule

end

local function device_added(self, device)
  print("<<<<<<<<<< do added >>>>>>>>>>")
  device:emit_event(ThermostatMode.supportedThermostatModes({"autowithreset", "manual", "auto"}, {visibility = {displayed = false}}))
  device:emit_event(capabilities.switch.switch.on())  -- set the switch state to on, because it must be on when you add it
  commands.setHeatingSetpoint(device, 10)   -- To avoid turning on the boiler immediately after adding the device, at least in my country.
  do_refresh(self, device)
end

local function device_info_changed(driver, device, event, args)
  print("<<<<<<<< device_info_changed handler >>>>>>>>")
  if device.preferences ~= nil then
    if device.preferences.tempCorrection ~= args.old_st_store.preferences.tempCorrection then 
      commands.setTempCorrection(device, device.preferences.tempCorrection)
    elseif device.preferences.sensorSelection ~= args.old_st_store.preferences.sensorSelection then
      commands.setSensorSelection(device, device.preferences.sensorSelection)
    elseif device.preferences.localTimeOffset ~= args.old_st_store.preferences.localTimeOffset then
      commands.syncDeviceTime(device, device.preferences.localTimeOffset)
    elseif device.preferences.frostProtection ~= args.old_st_store.preferences.frostProtection then
      commands.setFrostProtection(device, device.preferences.frostProtection)
    elseif device.preferences.hysteresis ~= args.old_st_store.preferences.hysteresis then
      commands.setHysteresis(device, device.preferences.hysteresis)
    elseif device.preferences.maxTemp ~= args.old_st_store.preferences.maxTemp then
      commands.setMaxTemperature(device, device.preferences.maxTemp)
    elseif device.preferences.thermostatReset ~= args.old_st_store.preferences.thermostatReset then
      if device.preferences.thermostatReset == "1" then
        if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
          commands.factoryReset(device)
          -- turn On thermostat
          local follow_up_poll = function()
            commands.switch(device, true)
            device.thread:call_with_delay(2, function()
              commands.setTempCorrection(device,  device.preferences.tempCorrection)    -- No correction or preference
              commands.setSensorSelection(device, device.preferences.sensorSelection)   -- Internal sensor or preference
              commands.setMaxTemperature(device, device.preferences.maxTemp)            -- 60ºc or preference
              commands.setFrostProtection(device, device.preferences.frostProtection)   -- Off or preference
              commands.setHysteresis(device, device.preferences.hysteresis)             -- 1º or prefernce
            end)
          end  
          device.thread:call_with_delay(7, follow_up_poll)
        else
          print("Skipping Reset command. Thermostat must be On")
        end
      end
    end
  end
end


local function switch_on_handler(driver, device, command)
  commands.switch(device, true)
end
local function switch_off_handler(driver, device, command)
  commands.switch(device, false)
end

local function tuya_cluster_sync_time_handler(driver, device, zb_rx)
  print("<<<<<<<< TUYA sync_time handler >>>>>>>>")
  --print(utils.stringify_table(zb_rx, "zb_rx table", true))
  local offset = device.preferences.localTimeOffset
  commands.syncDeviceTime(device, offset)
end

local function tuya_cluster_handler(driver, device, zb_rx)
  --print("<<<<<<<< TUYA command handler >>>>>>>>")
  local value = 0
  local cmd = commands.getCommand(zb_rx.body.zcl_body.body_bytes)
  print(commands.stringify_command(cmd, false))
  if cmd.dpName == "CurrentTemp" then
    local divisor = 10
    value = string.unpack(">i", cmd.data) / divisor
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C" }))
    if syncTimer == nil then syncTimeTimer(device) end    -- start Thermostat Time sync every hour
  elseif cmd.dpName == "switch" then
    if cmd.data == ON then
      device:emit_event(capabilities.switch.switch.on())
      if syncTimer == nil then syncTimeTimer(device) end  -- start Thermostat Time sync every hour
    else
      device:emit_event(capabilities.switch.switch.off())
    end
  elseif cmd.dpName == "thermostatMode" then
    value = string.unpack("b", cmd.data)
    if device:get_manufacturer() == "_TZE200_viy9ihs7" then --invert manual and auto mode
      if value == 0 then
        device:emit_event(ThermostatMode.thermostatMode.manual())
      elseif value == 1 then
        device:emit_event(ThermostatMode.thermostatMode.auto())
      elseif value == 2 then
        device:emit_event(ThermostatMode.thermostatMode.autowithreset())
      end
    else
      if value == 1 then
        device:emit_event(ThermostatMode.thermostatMode.manual())
      elseif value == 0 then
        device:emit_event(ThermostatMode.thermostatMode.auto())
      elseif value == 2 then
        device:emit_event(ThermostatMode.thermostatMode.autowithreset())
      end
    end
  elseif cmd.dpName == "SetTemp" then
    local divisor = 10 
    value = string.unpack(">i", cmd.data) / divisor
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value, unit = 'C' }))
  elseif cmd.dpName == "ChildLock" then
    if cmd.data == OFF then
      device:emit_event(keypadLock.lock.unlocked())
    else
      device:emit_event(keypadLock.lock.locked())
    end
  elseif cmd.dpName == "FaultAlarm" then
    local err = tostring(string.unpack("B", cmd.data))
    if err == "0" then
      err = "<<<<<<<<<< Fault Alarm, No error >>>>>>>>>>>>"
    else
      err = "<<<<<<<<< Fault Alarm, Error code: " .. err .. " >>>>>>>>"
    end
    print("<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>")
    print(err)
    print("<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>")
  elseif cmd.dpName == "thermostatOperatingState" then
    if cmd.data == ON then
      device:emit_event(ThermostatOperatingState.thermostatOperatingState.heating())
    else
      device:emit_event(ThermostatOperatingState.thermostatOperatingState.idle())
    end
  elseif cmd.dpName == "FactoryReset" then
    if cmd.data == OFF then
      print("<<<<<<<< Factory defaults restored >>>>>>>>")
    else
      print("<<<<<<<< Performing Factory reset >>>>>>>>>")
    end
  elseif cmd.dpName == "BackplaneBrightness" then
    local level = string.unpack("B", cmd.data)
    if level >= 0 and level <= 3 then
      device:emit_event(backlightLevel.level({value = level}, {visibility = {displayed = false}}))
    end
  elseif cmd.dpName == "WeeklyProcedure" then
    local scheduleArray = status:getScheduleArray(cmd.data)
    local newSchedule = ""
    for i = 1, 8 do
      newSchedule = newSchedule .. scheduleArray[i]
      if i < 8 then newSchedule = newSchedule .. ";" end
    end
    if newSchedule ~= "" then
      device:emit_event(schedule.schedule(newSchedule,{ visibility = {displayed = true}}))
    end
  elseif cmd.dpName == "WorkingDaySetting" then
    value = string.unpack("b", cmd.data)
    if device:get_manufacturer() == "_TZE200_viy9ihs7" then --invert mondayToFriday and mondayToSaturday
      if value == commands.thermostatWeekFormat.mondayToFriday then
        device:emit_event(ThermostatWorkingDaySettings.workingDaySetting("mondayToSaturday", {visibility = {displayed = true}}))
      elseif value == commands.thermostatWeekFormat.mondayToSaturday then
        device:emit_event(ThermostatWorkingDaySettings.workingDaySetting("mondayToFriday", {visibility = {displayed = true}}))
      elseif value == commands.thermostatWeekFormat.mondayToSunday then
        device:emit_event(ThermostatWorkingDaySettings.workingDaySetting("mondayToSunday", {visibility = {displayed = true}}))
      end
    else
      if value == commands.thermostatWeekFormat.mondayToFriday then
        device:emit_event(ThermostatWorkingDaySettings.workingDaySetting("mondayToFriday", {visibility = {displayed = true}}))
      elseif value == commands.thermostatWeekFormat.mondayToSaturday then
        device:emit_event(ThermostatWorkingDaySettings.workingDaySetting("mondayToSaturday", {visibility = {displayed = true}}))
      elseif value == commands.thermostatWeekFormat.mondayToSunday then
        device:emit_event(ThermostatWorkingDaySettings.workingDaySetting("mondayToSunday", {visibility = {displayed = true}}))
      end
    end
  --[[elseif cmd.dpName == "TempCorrection" then
    value = string.unpack(">i", cmd.data) / 10

  elseif cmd.dpName == "SensorSelection" then
    value = string.unpack("b", cmd.data)

  elseif cmd.dpName == "Hysteresis" then
    value = string.unpack(">i", cmd.data) / 10

  elseif cmd.dpName == "FrostProtection" then
    value = string.unpack("b", cmd.data)
    local fp = false
    if value == ON then fp = true end

  elseif cmd.dpName == "MaxTemp" then
    value = string.unpack(">i", cmd.data) / 10]]
  end
end

local function setThermostatMode_handler(driver, device, command)
  print("setThermostatMode: " .. tostring(command.args.mode))
  commands.setThermostatMode(device, command.args.mode)
end

local function setHeatingSetpoint_handler(driver, device, command)
  print(utils.stringify_table(command, "setHeatingSetpoint_handler table", false))
  commands.setHeatingSetpoint(device, command.args.setpoint)
end

local function setBacklightLevel_handler(driver, device, command)
  print(utils.stringify_table(command, "setBacklightLevels_handler table", false))
  commands.setBackplaneBrightness(device, command.args.level)
end

local function keypadLock_handler(driver, device, command)
  print(utils.stringify_table(command, "lock_handler table", false))
  commands.setChildLock(device, true)
end

local function keypadUnlock_handler(driver, device, command)
  print(utils.stringify_table(command, "unlock_handler table", false))
  commands.setChildLock(device, false)
end

local function setWorkingDaySetting_handler(driver, device, command)
  print(utils.stringify_table(command, "setWorkingDaySetting_handler table", false))
  local twf
  if device:get_manufacturer() == "_TZE200_viy9ihs7" then --invert mondayToFriday and mondayToSaturday
    if command.args.setting == "mondayToFriday" then
      twf = commands.thermostatWeekFormat.mondayToSaturday 
    elseif command.args.setting == "mondayToSaturday" then
      twf = commands.thermostatWeekFormat.mondayToFriday
    elseif command.args.setting == "mondayToSunday" then
      twf = commands.thermostatWeekFormat.mondayToSunday
    end
  else
    if command.args.setting == "mondayToFriday" then
      twf = commands.thermostatWeekFormat.mondayToFriday
    elseif command.args.setting == "mondayToSaturday" then
      twf = commands.thermostatWeekFormat.mondayToSaturday
    elseif command.args.setting == "mondayToSunday" then
      twf = commands.thermostatWeekFormat.mondayToSunday
    end
  end
  commands.setSchedule(device, twf)
end

local function setScheduleTable_handler(driver, device, command)
  print(utils.stringify_table(command, "setScheduleTable_handler table", false))
  local error = "Not error"
  if status:checkScheduleString(command.args.schedule) then
    if commands.setPrograms(device, command.args.schedule) ~= 0 then
      error = "Format error in schedule string"
    end
  else
    error = "Format error in schedule string"
  end
  print("error:", error)
end

local zigbee_avatto_thermostat = {
  NAME = "AVATTO Thermostat",
  supported_capabilities = {
    capabilities.switch,
    capabilities.thermostatMode,
    backlightLevel,
    keypadLock,
    TemperatureMeasurement,
    ThermostatHeatingSetpoint,
    ThermostatOperatingState,
    ThermostatWorkingDaySettings,
    schedule,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = switch_on_handler,
      [capabilities.switch.commands.off.NAME] = switch_off_handler
    },
    [capabilities.thermostatHeatingSetpoint.ID] = {
      [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = setHeatingSetpoint_handler,
    },
    [backlightLevel.ID] = {
      [backlightLevel.commands.setLevel.NAME] = setBacklightLevel_handler,
    },
    [keypadLock.ID] = {
      [keypadLock.commands.lock.NAME] = keypadLock_handler,
      [keypadLock.commands.unlock.NAME] = keypadUnlock_handler,
    },
    [ThermostatMode.ID] = {
      [ThermostatMode.commands.setThermostatMode.NAME] = setThermostatMode_handler
    },
    [ThermostatWorkingDaySettings.ID] = {
      [ThermostatWorkingDaySettings.commands.setWorkingDaySetting.NAME] = setWorkingDaySetting_handler
    },
    [schedule.ID] = {
      [schedule.commands.setSchedule.NAME] = setScheduleTable_handler
    }
  },
  lifecycle_handlers = {
    init = do_init,
    doConfigure = do_configure,
    added = device_added,
    infoChanged = device_info_changed,
    driverSwitched = do_configure
  },
  zigbee_handlers = {
    global = {},
    cluster = {
      [0xEF00] = {
        [0x00] = tuya_cluster_handler,  -- TUYA_REQUEST
        [0x01] = tuya_cluster_handler,  -- TUYA_REPORT
        [0x02] = tuya_cluster_handler,  -- TUYA_REPORT
        [0x03] = tuya_cluster_handler,  -- TUYA_QUERY
        [0x06] = tuya_cluster_handler,  -- TUYA proactively reports status to the module
        [0x24] = tuya_cluster_sync_time_handler,  -- requests to sync clock time with the server time
      }
    },
  },
  --health_check = false,
  can_handle = require("avatto.can_handle"),
}
return zigbee_avatto_thermostat