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

local cc = require "st.zwave.CommandClass"
local capabilities = require "st.capabilities"
--local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })
--local Battery = (require "st.zwave.CommandClass.Battery")({ version = 1 })
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })
--local SensorBinary = (require "st.zwave.CommandClass.SensorBinary")({ version = 2 })
local SensorMultilevel = (require "st.zwave.CommandClass.SensorMultilevel")({ version = 5 })
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 2 })
local Version = (require "st.zwave.CommandClass.Version")({ version = 2 })
--local utils = require "st.utils"

local preferencesMap = require "preferences"
local configurations = require "configurations"
local child_devices = require "child-devices"

local FIBARO_DOOR_WINDOW_SENSOR_WAKEUP_INTERVAL = 21600 --seconds

local FIBARO_DOOR_WINDOW_SENSOR_FINGERPRINTS = {
  { manufacturerId = 0x010F, prod = 0x0700, productId = 0x1000 }, -- Fibaro Open/Closed Sensor (FGK-10x) / Europe
  { manufacturerId = 0x010F, prod = 0x0700, productId = 0x2000 }, -- Fibaro Open/Closed Sensor (FGK-10x) / NA
  { manufacturerId = 0x010F, prod = 0x0702, productId = 0x1000 }, -- Fibaro Open/Closed Sensor 2 (FGDW-002) / Europe
  { manufacturerId = 0x010F, prod = 0x0702, productId = 0x2000 }, -- Fibaro Open/Closed Sensor 2 (FGDW-002) / NA
  { manufacturerId = 0x010F, prod = 0x0702, productId = 0x3000 }, -- Fibaro Open/Closed Sensor 2 (FGDW-002) / ANZ
  { manufacturerId = 0x010F, prod = 0x0701, productId = 0x2001 }, -- Fibaro Open/Closed Sensor with temperature (FGK-10X) / NA
  { manufacturerId = 0x010F, prod = 0x0701, productId = 0x1001 }, -- Fibaro Open/Closed Sensor
  { manufacturerId = 0x010F, prod = 0x0501, productId = 0x1002 }  -- Fibaro Open/Closed Sensor
}

local function can_handle_fibaro_door_window_sensor(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(FIBARO_DOOR_WINDOW_SENSOR_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.prod, fingerprint.productId) then
      local subdriver = require("fibaro-door-window-sensor")
      return true, subdriver
    end
  end
  return false
end

local function parameterNumberToParameterName(preferences,parameterNumber)
  for id, parameter in pairs(preferences) do
    if parameter.parameter_number == parameterNumber then
      return id
    end
  end
end

local function update_preferences(driver, device, args)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end -- is Child device
  local preferences = preferencesMap.get_device_parameters(device)
  for id, value in pairs(device.preferences) do
    --preference values for app_version == 25
    local oldPreferenceValue1 = device:get_field(id)
    local newParameterValue1 = device.preferences[id]
    --preference values for app_version ~= 25
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = preferencesMap.to_numeric_value(device.preferences[id])
    local synchronized = device:get_field(id)
    if preferences and preferences[id] and (oldPreferenceValue ~= newParameterValue or synchronized == false) then
      if device:get_field("app_version") ~= 25 then
        device:send(Configuration:Set({parameter_number = preferences[id].parameter_number, size = preferences[id].size, configuration_value = newParameterValue}))
        device:set_field(id, false, {persist = true})
        device:send(Configuration:Get({parameter_number = preferences[id].parameter_number}))
        -- temp Sensitivity y Tamper report for model 700 v2.5       
      end
    end
    if device:get_field("app_version") == 25 and oldPreferenceValue1 ~= newParameterValue1 then
      device:set_field(id, newParameterValue, {persist = true})
      if id == "tempSensitivity" then
        device:send(Configuration:Set({parameter_number = 12, size = 1, configuration_value = device.preferences.tempSensitivity}))
      elseif id == "tamperAlarmCancel" then
        local tamper_value = 1
        if device.preferences.tamperAlarmCancel == false then tamper_value = 0 end
        device:send(Configuration:Set({parameter_number = 10, size = 1, configuration_value = tamper_value}))
      end
    end
  end
  if args.old_st_store.preferences.reportingInterval ~= device.preferences.reportingInterval then
    device:send(WakeUp:IntervalSet({node_id = driver.environment_info.hub_zwave_id, seconds = device.preferences.reportingInterval * 3600}))
  end
end

local function configuration_report(driver, device, cmd)
  print("<<< configuration_report in fibaro subdriver >>>")
  local preferences = preferencesMap.get_device_parameters(device)
  if preferences then
    local parameterName = parameterNumberToParameterName(preferences, cmd.args.parameter_number)
    local configValueSetByUser = device.preferences[parameterName]
    local configValueReportedByDevice = cmd.args.configuration_value
    if (parameterName and configValueSetByUser == configValueReportedByDevice) then
      device:set_field(parameterName, true, {persist = true})
    end
  end
end

local function device_added(self, device)
  device:refresh()
end

local function do_refresh(self, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end -- is Child device
  if  (device.zwave_product_type == 0x0700 and device.zwave_product_id== 0x2000) then
    device:send(SensorMultilevel:Get({sensor_type = SensorMultilevel.sensor_type.TEMPERATURE}, {dst_channels = {0x02}}))
  end
  device:send(Version:Get({}))

end

local function do_configure(self, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end -- is Child device
  configurations.initial_configuration(self, device)
  device:refresh()
  device:send(WakeUp:IntervalSet({node_id = self.environment_info.hub_zwave_id, seconds = FIBARO_DOOR_WINDOW_SENSOR_WAKEUP_INTERVAL}))
end

local function device_init(self, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end -- is Child device
  if device:get_field("app_version") == nil then
    device:set_field("app_version", 0, {persist = true})
  end

  local preferences = preferencesMap.get_device_parameters(device)
  if preferences then
    device:set_update_preferences_fn(update_preferences)
    for id, _  in pairs(preferences) do
      device:set_field(id, true, {persist = true})
    end
  end

    -- set selected device profile
    if device.preferences.useTempTileTwo == true then
      device:try_update_metadata({profile = "fibaro-door-window-sensor-temperature-icon"}) --model 0701
    elseif device.preferences.useTempTileTwo == false then
      device:try_update_metadata({profile = "fibaro-door-window-sensor-temperature"})  --model 0701
    end

end

---- preferences change handler
local function info_changed(driver, device, event, args)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end -- is Child device
  local preferences = preferencesMap.get_device_parameters(device)
  for id, value in pairs(device.preferences) do

    local oldPreferenceValue1 = device:get_field(id)
    local newParameterValue1 = device.preferences[id]

    if device.preferences.parameterSendDelay == "NoDelay" then
      local oldPreferenceValue = args.old_st_store.preferences[id]
      local newParameterValue = preferencesMap.to_numeric_value(device.preferences[id])
      local synchronized = device:get_field(id)
      if preferences and preferences[id] and (oldPreferenceValue ~= newParameterValue or synchronized == false) then
        if device:get_field("app_version") ~= 25 then
          device:send(Configuration:Set({parameter_number = preferences[id].parameter_number, size = preferences[id].size, configuration_value = newParameterValue}))
          device:set_field(id, false, {persist = true})
          device:send(Configuration:Get({parameter_number = preferences[id].parameter_number}))
        end
      end
    end
      --change profile to external temperature sensor
      if oldPreferenceValue1 ~= newParameterValue1 then
      --device:set_field(id, newParameterValue1, {persist = true})
      if id == "useExtTempSensor" then
        device:set_field(id, newParameterValue1, {persist = true})
        if device:get_field("app_version") ~= 25 then
          if device.preferences.useExtTempSensor == true then
            device:try_update_metadata({profile = "fibaro-door-window-sensor-ext-temp"}) --model 0700
          elseif device.preferences.useExtTempSensor == false then
            device:try_update_metadata({profile = "fibaro-door-window-sensor"})  --model 0700
          end
        else
          if device.preferences.useExtTempSensor == true then
            device:try_update_metadata({profile = "fibaro-door-window-sensor-ext-temp-v25"}) --model 0700 v2.5
          elseif device.preferences.useExtTempSensor == false then
            device:try_update_metadata({profile = "fibaro-door-window-sensor-v25"})  --model 0700 v2.5
          end
        end
      elseif id == "useTempTile" then
        device:set_field(id, newParameterValue1, {persist = true})
        if device:get_field("app_version") ~= 25 then
          if device.preferences.useTempTile == true and device.preferences.useExtTempSensor == true then
            device:try_update_metadata({profile = "fibaro-door-window-sensor-temp-icon"})  --model 0700 & 0701 1001
          elseif device.preferences.useTempTile == false and device.preferences.useExtTempSensor == true then
            device:try_update_metadata({profile = "fibaro-door-window-sensor-ext-temp"})  --model 0700 & 0701 1001
          end
        else
          if device.preferences.useTempTile == true and device.preferences.useExtTempSensor == true then
            device:try_update_metadata({profile = "fibaro-door-window-sensor-temp-icon-v25"})  --model 0700 & 0701 1001
          elseif device.preferences.useTempTile == false and device.preferences.useExtTempSensor == true then
            device:try_update_metadata({profile = "fibaro-door-window-sensor-ext-temp-v25"})  --model 0700 & 0701 1001
          end
        end
      elseif id == "useTempTileTwo" then
        device:set_field(id, newParameterValue1, {persist = true})
        if device.preferences.useTempTileTwo == true then
          device:try_update_metadata({profile = "fibaro-door-window-sensor-temperature-icon"})  --model 0701 2001
        elseif device.preferences.useTempTileTwo == false then
          device:try_update_metadata({profile = "fibaro-door-window-sensor-temperature"})  --model 0701 2001
        end
        -- temp Sensitivity y Tamper report for model 700 v2.5
      elseif id == "tempSensitivity" then
        device:set_field(id, newParameterValue1, {persist = true})
        device:send(Configuration:Set({parameter_number = 12, size = 1, configuration_value = device.preferences.tempSensitivity}))
      elseif id == "tamperAlarmCancel" then
        device:set_field(id, newParameterValue1, {persist = true})
        local tamper_value = 1
        if device.preferences.tamperAlarmCancel == false then tamper_value = 0 end
        device:send(Configuration:Set({parameter_number = 10, size = 1, configuration_value = tamper_value}))
      -- create child thermostat devoce
      elseif id == "childThermostat" and device.preferences.childThermostat == true then
        device:set_field(id, newParameterValue1, {persist = true})
        child_devices.create_new(driver, device, "main", "child-thermostat")
      elseif id == "configChild" and device.preferences.configChild == true then
        device:set_field(id, newParameterValue1, {persist = true})
        child_devices.create_new(driver, device, "config", "zwave-device-info")
      elseif id == "batteryType" and newParameterValue1 ~= nil then
            device:emit_event(capabilities.battery.type(newParameterValue1))
          elseif id == "batteryQuantity" and newParameterValue1 ~= nil then
            device:emit_event(capabilities.battery.quantity(newParameterValue1))
      end
    end
  end
  if args.old_st_store.preferences.reportingInterval ~= device.preferences.reportingInterval then
    device:send(WakeUp:IntervalSet({node_id = driver.environment_info.hub_zwave_id, seconds = device.preferences.reportingInterval * 3600}))
  end
end

local function notification_report_handler(self, device, cmd)
  local notificationType = cmd.args.notification_type
  local event = cmd.args.event

  if notificationType == Notification.notification_type.HOME_SECURITY then
    if event == Notification.event.home_security.STATE_IDLE then
      device:emit_event(capabilities.tamperAlert.tamper.clear())
    elseif event == Notification.event.home_security.TAMPERING_PRODUCT_COVER_REMOVED then
      device:emit_event(capabilities.tamperAlert.tamper.detected())
    end
  elseif notificationType == Notification.notification_type.ACCESS_CONTROL then
    if event == Notification.event.access_control.WINDOW_DOOR_IS_OPEN then
      device:emit_event(capabilities.contactSensor.contact.open())
    elseif event == Notification.event.access_control.WINDOW_DOOR_IS_CLOSED then
      device:emit_event(capabilities.contactSensor.contact.closed())
    end
  end
end

local function temperature_report_handler(self, device, cmd)
  if (cmd.args.sensor_type == SensorMultilevel.sensor_type.TEMPERATURE) then
    print("<<< cmd.src_channel:", cmd.src_channel)
    local temp_value = cmd.args.sensor_value
    local scale = "C"
    if (cmd.args.scale == SensorMultilevel.scale.temperature.FAHRENHEIT) then scale = "F" end

      -- if model 0700 v2.5 use custom temperature offset
      if device:get_field("app_version") ~= nil then
        if device:get_field("app_version") == 25 then
          if scale == "F" and device.preferences.tempUnits == "F" then
            temp_value = temp_value + device.preferences.temCustomOffset
          elseif scale == "F" and device.preferences.tempUnits == "C" then
            temp_value = temp_value + (device.preferences.temCustomOffset * 9/5)
          elseif scale == "C" and device.preferences.tempUnits == "C" then
            temp_value = temp_value + device.preferences.temCustomOffset
          elseif scale == "C" and device.preferences.tempUnits == "F" then
            temp_value = temp_value + (device.preferences.temCustomOffset * 5/9)
          end
        end
      end
    -- if model 0700 v2.5 use custom temperature offset
    --if device:get_field("app_version") ~= nil then
      --if device:get_field("app_version") == 25 then  
        --temp_value = cmd.args.sensor_value + device.preferences.temCustomOffset
      --end
    --end

    device:emit_event_for_endpoint(cmd.src_channel, capabilities.temperatureMeasurement.temperature({value = temp_value, unit = scale}))
  end
end

local function version_report_handler(driver, device, cmd)
 -- print("Version cmd >>>>>>", utils.stringify_table(cmd))
  print("<<< cmd.args.application_version >>>", cmd.args.application_version)
  print("<<< cmd.args.application_sub_version >>>", cmd.args.application_sub_version)
  if cmd.args.application_version == 2 and cmd.args.application_sub_version == 5 then
    -- firmware version 25 use endpoint 2 for temrperature
    if device:get_field("app_version") ~= 25 then
      device:set_field("app_version", 25, {persist = true})
    end
    if device.preferences.useTempTile == true and device.preferences.useExtTempSensor == true then
      device:try_update_metadata({profile = "fibaro-door-window-sensor-temp-icon-v25"})  --model 0700 v2.5
    elseif device.preferences.useTempTile == false and device.preferences.useExtTempSensor == true then
      device:try_update_metadata({profile = "fibaro-door-window-sensor-ext-temp-v25"})  --model 0700 v2.5
    elseif device.preferences.useExtTempSensor == false then
      device:try_update_metadata({profile = "fibaro-door-window-sensor-v25"})  --model 0700 v2.5
    end
  end
end

local fibaro_door_window_sensor = {
  NAME = "fibaro door window sensor",
  zwave_handlers = {
    [cc.NOTIFICATION] = {
      [Notification.REPORT] = notification_report_handler
    },
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report
    },
    --[cc.SENSOR_MULTILEVEL] = {
      --[SensorMultilevel.REPORT] = temperature_report_handler
    --},
    [cc.VERSION] = {
      [Version.REPORT] = version_report_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    doConfigure = do_configure,
    init = device_init,
    --infoChanged = update_preferences,
    infoChanged = info_changed
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh
    }
  },
  sub_drivers = {
    require("fibaro-door-window-sensor/fibaro-door-window-sensor-1"),
    require("fibaro-door-window-sensor/fibaro-door-window-sensor-2")
  },
  can_handle = can_handle_fibaro_door_window_sensor
}

return fibaro_door_window_sensor
