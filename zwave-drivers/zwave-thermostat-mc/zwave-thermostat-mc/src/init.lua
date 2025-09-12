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
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.CommandClass.Battery
local Battery = (require "st.zwave.CommandClass.Battery")({version=1})
--- @type st.zwave.CommandClass.SensorMultilevel
local SensorMultilevel = (require "st.zwave.CommandClass.SensorMultilevel")({version=2})
--- @type st.zwave.CommandClass.ThermostatFanMode
local ThermostatFanMode = (require "st.zwave.CommandClass.ThermostatFanMode")({version=3})
--- @type st.zwave.CommandClass.ThermostatMode
local ThermostatMode = (require "st.zwave.CommandClass.ThermostatMode")({version=2})
--- @type st.zwave.CommandClass.ThermostatOperatingState
local ThermostatOperatingState = (require "st.zwave.CommandClass.ThermostatOperatingState")({version=1})
--- @type st.zwave.CommandClass.ThermostatSetpoint
local ThermostatSetpoint = (require "st.zwave.CommandClass.ThermostatSetpoint")({version=1})

local TimeParameters = (require "st.zwave.CommandClass.TimeParameters")({version=1})
--local Time = (require "st.zwave.CommandClass.Time")({version=1})

local constants = require "st.zwave.constants"
local utils = require "st.utils"

local preferencesMap = require "preferences"
local Configuration = (require "st.zwave.CommandClass.Configuration")({version=1})

--- preferences update
local function info_changed(driver, device, event, args)
  local preferences = preferencesMap.get_device_parameters(device)

  for id, value in pairs(device.preferences) do
    --if preferences then
      if args.old_st_store.preferences[id] ~= value and preferences[id] then
        print("Preference Changed >>>", id, "Old Value >>>>>>>>>", args.old_st_store.preferences[id], "New Value >>", value)
        local new_parameter_value = preferencesMap.to_numeric_value(device.preferences[id])
        --2's complement value if needed
        if preferences[id].size == 4 and new_parameter_value > 2147483647 then
          new_parameter_value = new_parameter_value - 4294967296
        elseif preferences[id].size == 2 and new_parameter_value > 32767 then
          new_parameter_value = new_parameter_value - 65536
        elseif preferences[id].size == 1 and new_parameter_value > 127 then
          new_parameter_value = new_parameter_value - 256
        end
        print("new_parameter_value Sent >>>>",new_parameter_value)
          device:send(Configuration:Set({parameter_number = preferences[id].parameter_number, size = preferences[id].size, configuration_value = new_parameter_value}))
      --end
      elseif args.old_st_store.preferences[id] ~= value and id == "localTimeOffset" then
        if  device.zwave_manufacturer_id == 0x015F and device.zwave_product_type == 0x0712 and device.zwave_product_id == 0x5102 or
        device.zwave_manufacturer_id == 0x015F and device.zwave_product_type == 0x0702 and device.zwave_product_id == 0x5102 then
          print("Preference Changed >>>", id, "Old Value >>>>>>>>>", args.old_st_store.preferences[id], "New Value >>", value)
          device:set_field("last_time_Updated", os.time() - 45000) -- allow send new time to thermostat
          device:send(TimeParameters:Get({}))
        end
      elseif args.old_st_store.preferences[id] ~= value and id == "batteryType" and value ~= nil then
        device:emit_event(capabilities.battery.type(value))
      elseif args.old_st_store.preferences[id] ~= value and id == "batteryQuantity" and value ~= nil then
        device:emit_event(capabilities.battery.quantity(value))
      end
    --end
  end

  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end


local do_refresh = function(self, device)
  device:send(ThermostatFanMode:SupportedGet({}))
  device:send(ThermostatFanMode:Get({}))
  device:send(ThermostatMode:SupportedGet({}))
  device:send(ThermostatMode:Get({}))
  device:send(ThermostatOperatingState:Get({}))
  device:send(SensorMultilevel:Get({}))
  device:send(ThermostatSetpoint:Get({}))
  --device:send(ThermostatSetpoint:Get({}))
  device:send(Battery:Get({}))
  if device.zwave_manufacturer_id == 0x015F and device.zwave_product_type == 0x0712 and device.zwave_product_id == 0x5102 or
  device.zwave_manufacturer_id == 0x015F and device.zwave_product_type == 0x0702 and device.zwave_product_id == 0x5102 then
    print("<<<< GET Thermostat Date >>>>>")
    device:set_field("last_time_Updated", os.time() - 45000) -- allow send new time to thermostat
    device:send(TimeParameters:Get({}))
    --device:send(Time:Get({}))
    --device:send(Time:DateGet({}))
    --device:send(Time:OffsetGet({})) -- este da error
  end
end

--TODO: Update this once we've decided how to handle setpoint commands
local function convert_to_device_temp(command_temp, device_scale)
  -- under 40, assume celsius
  if (command_temp < 40 and device_scale == ThermostatSetpoint.scale.FAHRENHEIT) then
    command_temp = utils.c_to_f(command_temp)
  elseif (command_temp >= 40 and (device_scale == ThermostatSetpoint.scale.CELSIUS or device_scale == nil)) then
    command_temp = utils.f_to_c(command_temp)
  end
  return command_temp
end

local function set_setpoint_factory(setpoint_type)
  return function(driver, device, command)
    local scale = device:get_field(constants.TEMPERATURE_SCALE)
    local value = convert_to_device_temp(command.args.setpoint, scale)

    local set = ThermostatSetpoint:Set({
      setpoint_type = setpoint_type,
      scale = scale,
      value = value
    })
    
    -- temporal para el estonio listo
    if device.zwave_manufacturer_id == 0x0002 and device.zwave_product_type == 0x0003 and device.zwave_product_id == 0x8010 then -- Danfoss & Devolo RS 014G0160 Thermostat
    else
      device:send_to_component(set, command.component)
    end

    local follow_up_poll = function()
      device:send_to_component(ThermostatSetpoint:Get({setpoint_type = setpoint_type}), command.component)
    end

    device.thread:call_with_delay(1, follow_up_poll)
  end
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
local function lazy_load_if_possible(sub_driver_name)
  -- gets the current lua libs api version
  local version = require "version"

  --print("<<<<< Library Version:", version.api)
  -- version 9 will include the lazy loading functions
  if version.api >= 9 then
    return ZwaveDriver.lazy_load_sub_driver(require(sub_driver_name))
  else
    return require(sub_driver_name)
  end
end

-- temporal para el estonio listo
local function do_init(self, device)
  if device.zwave_manufacturer_id == 0x0002 and device.zwave_product_type == 0x0003 and device.zwave_product_id == 0x8010 then -- Danfoss & Devolo RS 014G0160 Thermostat
    device:try_update_metadata({profile = "temp-thermostat-heating-battery"})
  end
end

local driver_template = {
  supported_capabilities = {
    capabilities.temperatureAlarm,
    capabilities.temperatureMeasurement,
    capabilities.thermostatHeatingSetpoint,
    capabilities.thermostatCoolingSetpoint,
    capabilities.thermostatOperatingState,
    capabilities.thermostatMode,
    capabilities.thermostatFanMode,
    capabilities.relativeHumidityMeasurement,
    capabilities.battery,
    capabilities.powerMeter,
    capabilities.energyMeter
  },
  lifecycle_handlers = {
    init = do_init,
    added = do_refresh,
    infoChanged = info_changed,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh
    },
    [capabilities.thermostatCoolingSetpoint.ID] = {
      [capabilities.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME] = set_setpoint_factory(ThermostatSetpoint.setpoint_type.COOLING_1)
    },
    [capabilities.thermostatHeatingSetpoint.ID] = {
      [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = set_setpoint_factory(ThermostatSetpoint.setpoint_type.HEATING_1)
    }
  },
  sub_drivers = {
    lazy_load_if_possible("aeotec-radiator-thermostat"),
    lazy_load_if_possible("popp-radiator-thermostat"),
    lazy_load_if_possible("ct100-thermostat"),
    lazy_load_if_possible("fibaro-heat-controller"),
    lazy_load_if_possible("stelpro-ki-thermostat"),
    lazy_load_if_possible("qubino-flush-thermostat"),
    lazy_load_if_possible("thermostat-heating-battery"),
    lazy_load_if_possible("thermostat-date-time"),
    lazy_load_if_possible("mco-alloy-mh4")
  }
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local thermostat = ZwaveDriver("zwave_thermostat", driver_template)
thermostat:run()
