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
--- @type st.utils
local utils = require "st.utils"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass.ThermostatSetpoint
local ThermostatSetpoint = (require "st.zwave.CommandClass.ThermostatSetpoint")({ version = 1 })
--- @type st.zwave.CommandClass.SensorMultilevel
local SensorMultilevel = (require "st.zwave.CommandClass.SensorMultilevel")({ version = 5 })
--- @type st.zwave.CommandClass.ThermostatMode
local ThermostatMode = (require "st.zwave.CommandClass.ThermostatMode")({version=2})
--- @type st.zwave.CommandClass.ThermostatOperatingState
local ThermostatOperatingState = (require "st.zwave.CommandClass.ThermostatOperatingState")({version=1})
--- @type st.zwave.CommandClass.Association
--local Association = (require "st.zwave.CommandClass.Association")({ version=2 })

local MH4_THERMOSTAT_FINGERPRINTS = {
  { manufacturerId = 0x0131, productType = 0x220A, productId = 0x1357 }, -- MCO Alloy MH4
  { manufacturerId = 0x015F, productType = 0x0401, productId = 0x5101 }, -- MCO MH4US

}

local function can_handle_mco_alloy_mh4(opts, driver, device, cmd, ...)
  for _, fingerprint in ipairs(MH4_THERMOSTAT_FINGERPRINTS) do
    if device:id_match( fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("mco-alloy-mh4")
      return true, subdriver
    end
  end

  return false
end

--- Default handler for thermostat setpoint reports for heating setpoint-implementing devices
---
--- This converts the command setpoint value to the equivalent heating setpoint event if the
--- setpoint type is "heating". It also stores the temperature scale used to report this value,
--- so that commands from the hub to the device will be sent in the same scale.
---
--- @param self st.zwave.Driver
--- @param device st.zwave.Device
--- @param cmd st.zwave.CommandClass.ThermostatSetpoint.Report
local function thermostat_setpoint_report_heating_handler(self, device, cmd)

  local mode = device:get_latest_state("main", capabilities.thermostatMode.ID, capabilities.thermostatMode.thermostatMode.NAME)
  local setpoint_type = cmd.args.setpoint_type

  if (mode == "energysaveheat" and setpoint_type == ThermostatSetpoint.setpoint_type.ENERGY_SAVE_HEATING) or
    (mode == "away" and setpoint_type == ThermostatSetpoint.setpoint_type.AWAY_HEATING) or
    ((mode == "heat" or mode == "off") and setpoint_type == ThermostatSetpoint.setpoint_type.HEATING_1) then

      local scale = 'C'
      if (cmd.args.scale == ThermostatSetpoint.scale.FAHRENHEIT) then scale = 'F' end
      device:set_field(constants.TEMPERATURE_SCALE, cmd.args.scale, {persist = true})
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = cmd.args.value, unit = scale }))
  end
end


local function set_heating_setpoint(driver, device, command)
  local value = command.args.setpoint
  if (value >= 40) then -- assume this is a fahrenheit value
    value = utils.f_to_c(value)
  end

  local scale = device:get_field(constants.TEMPERATURE_SCALE)
  if (scale == ThermostatSetpoint.scale.FAHRENHEIT) then
    value = utils.c_to_f(value) -- the device has reported using F, so set using F
  end

  local mode = device:get_latest_state("main", capabilities.thermostatMode.ID, capabilities.thermostatMode.thermostatMode.NAME)
  local setpoint_type = ThermostatSetpoint.setpoint_type.HEATING_1
  if mode == "energysaveheat" then
    setpoint_type = ThermostatSetpoint.setpoint_type.ENERGY_SAVE_HEATING
  elseif mode == "away" then
    setpoint_type = ThermostatSetpoint.setpoint_type.AWAY_HEATING 
  end
  local set = ThermostatSetpoint:Set({
    setpoint_type = setpoint_type,
    scale = scale,
    value = value
  })
  device:send_to_component(set, command.component)

  local follow_up_poll = function()
    device:send_to_component(
      ThermostatSetpoint:Get({setpoint_type = setpoint_type}), command.component)
  end

  device.thread:call_with_delay(1, follow_up_poll)

end


--- Default handler for thermostat mode reports for implementing devices
---
--- This converts the command mode to the equivalent smartthings capability value
---
--- @param self st.zwave.Driver
--- @param device st.zwave.Device
--- @param cmd st.zwave.CommandClass.ThermostatMode.Report
local function thermostat_mode_report_handler(self, device, cmd)
  local event = nil
  if (cmd.args.mode == ThermostatMode.mode.OFF) then
    event = capabilities.thermostatMode.thermostatMode.off()
  elseif (cmd.args.mode == ThermostatMode.mode.HEAT) then
    event = capabilities.thermostatMode.thermostatMode.heat()
  elseif (cmd.args.mode == ThermostatMode.mode.ENERGY_SAVE_HEAT) then
    event = capabilities.thermostatMode.thermostatMode.energysaveheat()
  elseif (cmd.args.mode == ThermostatMode.mode.AWAY) then
    event = capabilities.thermostatMode.thermostatMode.away()
  end

  if (event ~= nil) then
    device:emit_event_for_endpoint(cmd.src_channel, event)
  end
end

--- Default handler for thermostat mode supported reports for implementing devices
---
--- This converts the command supported modes to the equivalent smartthings capability value
---
--- @param self st.zwave.Driver
--- @param device st.zwave.Device
--- @param cmd st.zwave.CommandClass.ThermostatMode.SupportedReport
local function thermostat_supported_modes_report_handler(self, device, cmd)
  local supported_modes = {}
  if (cmd.args.off) then
    table.insert(supported_modes, "off")
  end
  if (cmd.args.heat) then
    table.insert(supported_modes, "heat")
  end
  if (cmd.args.away) then
    table.insert(supported_modes, "away")
  end
  if (cmd.args.energy_save_heat) then
    table.insert(supported_modes, "energysaveheat")
  end
  device:emit_event_for_endpoint(
    cmd.src_channel,
    capabilities.thermostatMode.supportedThermostatModes(
      supported_modes,
      { visibility = { displayed = false }}
    )
  )
end

local function do_refresh(self, device)
  device:send(ThermostatMode:SupportedGet({}))
  device:send(ThermostatMode:Get({}))
  device:send(ThermostatOperatingState:Get({}))
  device:send(SensorMultilevel:Get({}))
  device:send(ThermostatSetpoint:Get({}))
end

--- Default handler for the ThermostatMode.setThermostatMode command
---
--- This will send a thermostat mode set of the equivalent z-wave value, with a follow up
--- get to confirm.
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param command table The capability command table
local function set_thermostat_mode(driver, device, command)
  print("<<<< command.args.mode",command.args.mode)
  local mode = command.args.mode
  local setpoint_type = ThermostatSetpoint.setpoint_type.HEATING_1
  local modeValue = nil
  if mode == "off" then
    modeValue = ThermostatMode.mode.OFF
  elseif mode == "heat" then
    modeValue = ThermostatMode.mode.HEAT
  elseif mode == "energysaveheat" then
    modeValue = ThermostatMode.mode.ENERGY_SAVE_HEAT
    setpoint_type = ThermostatSetpoint.setpoint_type.ENERGY_SAVE_HEATING
  elseif mode == "away" then
    modeValue = ThermostatMode.mode.AWAY
    setpoint_type = ThermostatSetpoint.setpoint_type.AWAY_HEATING
  end

  if (modeValue ~= nil) then
    device:send_to_component(ThermostatMode:Set({mode = modeValue}), command.component)

    local follow_up_poll = function()
      device:send_to_component(ThermostatMode:Get({}), command.component)
      device:send(ThermostatSetpoint:Get({setpoint_type = setpoint_type}), command.component)
    end

    device.thread:call_with_delay(1, follow_up_poll)
  end

end

local mode_setter = function(mode_name)
  return function(driver, device, command)
    set_thermostat_mode(driver,device,{args={mode=mode_name}})
  end
end

local function device_added(self, device)
  --local _node_ids =  {self.environment_info.hub_zwave_id}
  --device:send(Association:Set({grouping_identifier = 1, node_ids =_node_ids}))
  --device:send(Association:Set({grouping_identifier = 7, node_ids =_node_ids}))
  --device:emit_event(capabilities.thermostatMode.supportedThermostatModes({"off", "heat", "energysaveheat", "away"}, { visibility = { displayed = false }}))
  do_refresh(self, device)
end

local function device_init(self, device)
  device:emit_event(capabilities.thermostatMode.supportedThermostatModes({"off", "heat", "energysaveheat", "away"}, { visibility = { displayed = false }}))
  do_refresh(self, device)
end

local mco_alloy_mh4 = {
  NAME = "MCO - Alloy MH4",
  zwave_handlers = {
    --[cc.SENSOR_MULTILEVEL] = {
      --[SensorMultilevel.REPORT] = sensor_multilevel_report_handler
    --},
    [cc.THERMOSTAT_MODE] = {
      [ThermostatMode.REPORT] = thermostat_mode_report_handler,
      [ThermostatMode.SUPPORTED_REPORT] = thermostat_supported_modes_report_handler
    },
    [cc.THERMOSTAT_SETPOINT] = {
      [ThermostatSetpoint.REPORT] = thermostat_setpoint_report_heating_handler
    }

  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh
    },
    [capabilities.thermostatHeatingSetpoint.ID] = {
      [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = set_heating_setpoint
    },
    [capabilities.thermostatMode.ID] ={
      [capabilities.thermostatMode.commands.setThermostatMode.NAME] = set_thermostat_mode,
      --[capabilities.thermostatMode.commands.away.NAME] = mode_setter(capabilities.thermostatMode.thermostatMode.away.NAME),
      --[capabilities.thermostatMode.commands.auto.NAME] = mode_setter(capabilities.thermostatMode.thermostatMode.auto.NAME),
      --[capabilities.thermostatMode.commands.heat.NAME] = mode_setter(capabilities.thermostatMode.thermostatMode.heat.NAME),
      --[capabilities.thermostatMode.commands.off.NAME] = mode_setter(capabilities.thermostatMode.thermostatMode.off.NAME)
    },
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init
  },
  can_handle = can_handle_mco_alloy_mh4,
}

return mco_alloy_mh4
