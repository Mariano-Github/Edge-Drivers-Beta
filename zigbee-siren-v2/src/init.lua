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

local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local zcl_global_commands = require "st.zigbee.zcl.global_commands"
local data_types = require "st.zigbee.data_types"
--local device_management = require "st.zigbee.device_management"

--ZCL
local zcl_clusters = require "st.zigbee.zcl.clusters"
local Status = require "st.zigbee.generated.types.ZclStatus"
local IASZone = zcl_clusters.IASZone
local IASWD = zcl_clusters.IASWD
local SirenConfiguration = IASWD.types.SirenConfiguration
local WarningMode = IASWD.types.WarningMode
local Strobe = IASWD.types.Strobe
local IaswdLevel = IASWD.types.IaswdLevel

--Capability
local capabilities = require "st.capabilities"
local alarm = capabilities.alarm
--local battery = capabilities.battery
local switch = capabilities.switch
--local temperatureMeasurement = capabilities.temperatureMeasurement

-- required module
local signal = require "signal-metrics"
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

-- Constants
local ALARM_COMMAND = "alarmCommand"
local ALARM_LAST_DURATION = "lastDuration"
local ALARM_MAX_DURATION = "maxDuration"

local ALARM_DEFAULT_MAX_DURATION = 0x00B4
local ALARM_DEFAULT_DURATION = 0xFFFE

local ALARM_STROBE_DUTY_CYCLE = 40

local alarm_command = {
  OFF = 0,
  SIREN = 1,
  STROBE = 2,
  BOTH = 3
}

local emit_alarm_event = function(device, cmd)
  if cmd == alarm_command.OFF then
    device:emit_event(capabilities.alarm.alarm.off())
    device:emit_event(capabilities.switch.switch.off())
  else
    if cmd == alarm_command.SIREN then
      device:emit_event(capabilities.alarm.alarm.siren())
    elseif cmd == alarm_command.STROBE then
      device:emit_event(capabilities.alarm.alarm.strobe())
    else
      device:emit_event(capabilities.alarm.alarm.both())
    end

    device:emit_event(capabilities.switch.switch.on())
  end
end

local send_siren_command = function(device, warning_mode, warning_siren_level, strobe_active, strobe_level)
  local max_duration = device:get_field(ALARM_MAX_DURATION)
  local warning_duration = max_duration and max_duration or ALARM_DEFAULT_MAX_DURATION
  local duty_cycle = ALARM_STROBE_DUTY_CYCLE

  device:set_field(ALARM_LAST_DURATION, warning_duration, {persist = true})

  local siren_configuration = SirenConfiguration(0x00)

  siren_configuration:set_warning_mode(warning_mode)
  siren_configuration:set_strobe(strobe_active)
  siren_configuration:set_siren_level(warning_siren_level)

  device:send(
      IASWD.server.commands.StartWarning(
          device,
          siren_configuration,
          data_types.Uint16(warning_duration),
          data_types.Uint8(duty_cycle),
          data_types.Enum8(strobe_level)
      )
  )
end

local default_response_handler = function(driver, device, zigbee_message)
  -- emit signal metrics
  if device:get_model() == "HESZB-120" then
    signal.metrics(device, zigbee_message)
  end

  local is_success = zigbee_message.body.zcl_body.status.value
  local command = zigbee_message.body.zcl_body.cmd.value
  local alarm_ev = device:get_field(ALARM_COMMAND)

  if command == IASWD.server.commands.StartWarning.ID and is_success == Status.SUCCESS then
    if alarm_ev ~= alarm_command.OFF then
      emit_alarm_event(device, alarm_ev)
      local lastDuration = device:get_field(ALARM_LAST_DURATION) or ALARM_DEFAULT_MAX_DURATION
      device.thread:call_with_delay(lastDuration, function(d)
        device:emit_event(capabilities.alarm.alarm.off())
        device:emit_event(capabilities.switch.switch.off())
      end)
    else
      emit_alarm_event(device,alarm_command.OFF)
    end
  end
end

local attr_max_duration_handler = function(driver, device, max_duration)
  device:set_field(ALARM_MAX_DURATION, max_duration.value, {persist = true})
end

local siren_switch_both_handler = function(driver, device, command)
  device:set_field(ALARM_COMMAND, alarm_command.BOTH, {persist = true})
  send_siren_command(device, WarningMode.BURGLAR, IaswdLevel.VERY_HIGH_LEVEL, Strobe.USE_STROBE, IaswdLevel.VERY_HIGH_LEVEL)
end

local siren_alarm_siren_handler = function(driver, device, command)
  device:set_field(ALARM_COMMAND, alarm_command.SIREN, {persist = true})
  send_siren_command(device, WarningMode.BURGLAR, IaswdLevel.VERY_HIGH_LEVEL, Strobe.NO_STROBE, IaswdLevel.LOW_LEVEL)
end

local siren_alarm_strobe_handler = function(driver, device, command)
  device:set_field(ALARM_COMMAND, alarm_command.STROBE, {persist = true})
  send_siren_command(device, WarningMode.STOP, IaswdLevel.LOW_LEVEL, Strobe.USE_STROBE, IaswdLevel.VERY_HIGH_LEVEL)
end

local siren_switch_on_handler = function(driver, device, command)
  siren_switch_both_handler(driver, device, command)
end

local siren_switch_off_handler = function(driver, device, command)
  device:set_field(ALARM_COMMAND, alarm_command.OFF, {persist = true})
  send_siren_command(device, WarningMode.STOP, IaswdLevel.LOW_LEVEL, Strobe.NO_STROBE, IaswdLevel.LOW_LEVEL)
end

local do_configure = function(self, device)
  device:send(IASWD.attributes.MaxDuration:write(device, ALARM_DEFAULT_DURATION))

  device:configure()
  device:refresh()
end

local device_init = function(self, device)
  device:set_field(ALARM_MAX_DURATION, ALARM_DEFAULT_MAX_DURATION, {persist = true})

  if device:get_manufacturer() == "_TYZB01_ynsiasng" and device:get_model() == "TS0219" then
    if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
      device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
    end
    local cap_value = device:get_latest_state("main", capabilities.powerSource.ID, capabilities.powerSource.powerSource.NAME)
    if cap_value == nil then
      device:emit_event(capabilities.powerSource.powerSource.mains())
    end
  end

  -- set battery type and quantity
  if device:supports_capability_by_id(capabilities.battery.ID) then
    local cap_status = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.type.NAME)
    if cap_status == nil and device.preferences.batteryType ~= nil then
      device:emit_event(capabilities.battery.type(device.preferences.batteryType))
    end

    cap_status = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.quantity.NAME)
    if cap_status == nil and device.preferences.batteryQuantity ~= nil then
      device:emit_event(capabilities.battery.quantity(device.preferences.batteryQuantity))
    end
  end

end

local function device_added(driver, device)
  device:emit_event(capabilities.alarm.alarm.off())
  device:emit_event(capabilities.switch.switch.off())
  
  if device:get_model() == "HESZB-120" then
    device:emit_event(capabilities.temperatureAlarm.temperatureAlarm("cleared"))
    if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
      device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
    end
  end
end

--- Update preferences after infoChanged recived---
local function do_preferences (self, device, event, args)
  for id, value in pairs(device.preferences) do
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
      if id == "batteryType" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.type(newParameterValue))
      elseif id == "batteryQuantity" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.quantity(newParameterValue))
      end
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
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
local version = require "version"
local lazy_handler
if version.api >= 15 then
  lazy_handler = require "st.utils.lazy_handler"
else
  lazy_handler = require
end
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

local zigbee_siren_driver_template = {
  supported_capabilities = {
    alarm,
    switch,
    capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.powerSource
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  zigbee_handlers = {
    global = {
        [IASWD.ID] = {
            [zcl_global_commands.DEFAULT_RESPONSE_ID] = default_response_handler
        }
    },
    attr = {
      [IASWD.ID] = {
        [IASWD.attributes.MaxDuration.ID] = attr_max_duration_handler
      }
    }
  },
  capability_handlers = {
    [alarm.ID] = {
      [alarm.commands.both.NAME] = siren_switch_both_handler,
      [alarm.commands.off.NAME] = siren_switch_off_handler,
      [alarm.commands.siren.NAME] = siren_alarm_siren_handler,
      [alarm.commands.strobe.NAME] = siren_alarm_strobe_handler
    },
    [switch.ID] = {
      [switch.commands.on.NAME] = siren_switch_on_handler,
      [switch.commands.off.NAME] = siren_switch_off_handler
    }
  },
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    doConfigure = do_configure,
    infoChanged = do_preferences
  },
  sub_drivers = { 
    lazy_load_if_possible("ozom"), 
    lazy_load_if_possible("frient"), 
    lazy_load_if_possible("frient-heat"), 
    lazy_load_if_possible("woox") 
  },
  cluster_configurations = {
    [alarm.ID] = {
      {
        cluster = IASZone.ID,
        attribute = IASZone.attributes.ZoneStatus.ID,
        minimum_interval = 0,
        maximum_interval = 180,
        data_type = IASZone.attributes.ZoneStatus.base_type
      }
    }
  },
  health_check = false
}

defaults.register_for_default_handlers(zigbee_siren_driver_template, zigbee_siren_driver_template.supported_capabilities)
local zigbee_siren = ZigbeeDriver("zigbee-siren", zigbee_siren_driver_template)
zigbee_siren:run()
