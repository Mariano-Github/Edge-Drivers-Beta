local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local PowerConfiguration = clusters.PowerConfiguration
local ThermostatMode = capabilities.thermostatMode
local Thermostat = clusters.Thermostat

local ThermostatSystemMode      = Thermostat.attributes.SystemMode
local ThermostatOperatingState = capabilities.thermostatOperatingState
local utils             = require "st.utils"
local device_management = require "st.zigbee.device_management"
local data_types = require "st.zigbee.data_types"

local write = require "writeAttribute"

local THERMOSTAT_MODE_MAP = {
  [ThermostatSystemMode.OFF]               = ThermostatMode.thermostatMode.off,
  [ThermostatSystemMode.HEAT]              = ThermostatMode.thermostatMode.heat,
  [ThermostatSystemMode.AUTO]              = ThermostatMode.thermostatMode.auto,
  [ThermostatSystemMode.DRY]               = ThermostatMode.thermostatMode.dryair
}

local EUROTRONIC_THERMOSTAT_FINGERPRINTS = {
  { mfr = "NAMRON AS", model = "4512737" }
}

local is_namrom_thermostat = function(opts, driver, device)
  for _, fingerprint in ipairs(EUROTRONIC_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      return true
    end
  end
  return false
end

local thermostat_mode_handler = function(driver, device, thermostat_mode)
  print("<<<<< thermostat_mode.value >>>", thermostat_mode.value)
  print("<<<< device:get_field(away_mode)", device:get_field("away_mode"))
  if device:get_field("away_mode") == 0 or device:get_field("away_mode") == nil then
    if THERMOSTAT_MODE_MAP[thermostat_mode.value] then
      device:emit_event(THERMOSTAT_MODE_MAP[thermostat_mode.value]())
    end
  else
    device:emit_event(ThermostatMode.thermostatMode.away())
  end
end

local function set_thermostat_mode (driver, device, command)
  print("<<<< command.args.mode",command.args.mode)
  print("<<<< device:get_field(away_mode)", device:get_field("away_mode"))
  if command.args.mode ~= "away" then
    for zigbee_attr_val, st_cap_val in pairs(THERMOSTAT_MODE_MAP) do
      if command.args.mode == st_cap_val.NAME then
        device:send_to_component(command.component, Thermostat.attributes.SystemMode:write(device, zigbee_attr_val))
        device.thread:call_with_delay(1, function(d)
          device:send_to_component(command.component, Thermostat.attributes.SystemMode:read(device))
        end)
        break
      end
    end
  else
    --local value_send = 0x0001
    --local data_value = {value = value_send, ID = 0x30}
    --local cluster_id = {value = 0x0201}
    --local attr_id = 0x2002
    --mfg_code = 0x1224
    --write.write_attribute_function(device, cluster_id, attr_id, data_value)
    device:send(write.custom_write_attribute(device, 0x0201, 0x2002, data_types.Enum8, 0x0001, 0x1224))
  end
end

local function set_heating_setpoint(driver, device, command)
  device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = command.args.setpoint*1.0, unit = "C"}))
  if device:get_field("away_mode") == 0 then
    device:send_to_component(command.component, Thermostat.attributes.OccupiedHeatingSetpoint:write(device, command.args.setpoint*100))
  elseif device:get_field("away_mode") == 1 then
    device:send_to_component(command.component, Thermostat.attributes.UnoccupiedHeatingSetpoint:write(device, command.args.setpoint*100))
  end
end


local function thermostat_operating_state_handler(driver, device, operating_state)
  if  operating_state:is_heat_on_set() then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.heating())
  else
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.idle())
  end
end

local function heating_setpoint_handler(driver, device, value)
  if device:get_field("away_mode") ~= 1 then
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value.value/100.0, unit = "C"}))
  end
end

local function away_heating_setpoint_handler(driver, device, value) 
  if device:get_field("away_mode") == 1 then
    device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value.value/100.0, unit = "C"}))
  end
end


local function floor_Temperature_handler(driver, device, value, zb_rx)
  local raw_temp = value.value
  local celc_temp = raw_temp / 100.0
  local temp_scale = "C"
  -- All events from drivers should be in celsius and without offset manipulation
  device.profile.components["floorTemperature"]:emit_event(capabilities.temperatureMeasurement.temperature({value = celc_temp, unit = temp_scale }))
  --device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.temperatureMeasurement.temperature({value = celc_temp, unit = temp_scale }))
end

local function away_mode_handler(driver, device, value)
  print("<<<< Atribute 0x2002 value >>>>", value.value)
  device:set_field("away_mode", value.value, {persist = true})

  device.thread:call_with_delay(2, function(d)
    device:send(Thermostat.attributes.UnoccupiedHeatingSetpoint:read(device))
  end)
end

local function do_init(driver,device)
  device:emit_event(ThermostatMode.supportedThermostatModes({"off", "heat", "auto", "dryair", "away"}, { visibility = { displayed = false } }))
end

local function do_configure(self, device)
  -- Configure 0x2002 away mode set interval report
  local config ={
    cluster = 0x0201,
    attribute = 0x2002,
    minimum_interval = 30,
    maximum_interval = 600,
    data_type = data_types.Enum8,
    mfg_code = 0x1224
  }
  device:add_configured_attribute(config)
  device:add_monitored_attribute(config)
  device:configure()

  device:send(device_management.build_bind_request(device, Thermostat.ID, self.environment_info.hub_zigbee_eui))
  device:send(Thermostat.attributes.LocalTemperature:configure_reporting(device, 10, 60, 50))
  device:send(Thermostat.attributes.OutdoorTemperature:configure_reporting(device, 10, 60, 50))
  device:send(Thermostat.attributes.OccupiedHeatingSetpoint:configure_reporting(device, 1, 600, 50))
  device:send(Thermostat.attributes.UnoccupiedHeatingSetpoint:configure_reporting(device, 1, 600, 50))
  device:send(Thermostat.attributes.Occupancy:configure_reporting(device, 10, 300))
  device:send(Thermostat.attributes.ControlSequenceOfOperation:configure_reporting(device, 10, 600))
  device:send(Thermostat.attributes.SystemMode:configure_reporting(device, 10, 600))
  device:send(Thermostat.attributes.ThermostatRunningState:configure_reporting(device, 10, 300))
end

local do_refresh = function(self, device)
  local attributes = {
    Thermostat.attributes.LocalTemperature,
    Thermostat.attributes.OutdoorTemperature,
    Thermostat.attributes.UnoccupiedHeatingSetpoint,
    Thermostat.attributes.OccupiedHeatingSetpoint,
    Thermostat.attributes.SystemMode,
    Thermostat.attributes.ThermostatRunningState,
    Thermostat.attributes.Occupancy,
  }
  for _, attribute in pairs(attributes) do
    device:send(attribute:read(device))
  end
end

local device_added = function(self, device)
  do_refresh(self, device)
end

local driver_switched = function(self, device)
  do_refresh(self, device)
  do_configure(self, device)
end


local namrom_thermostat = {
  NAME = "NAMROM Thermostat Handler",
  capability_handlers = {
    [ThermostatMode.ID] = {
      [ThermostatMode.commands.setThermostatMode.NAME] = set_thermostat_mode,
    },
    [capabilities.thermostatHeatingSetpoint.ID] = {
      [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = set_heating_setpoint,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  zigbee_handlers = {
    attr = {
      [Thermostat.ID] = {
        [Thermostat.attributes.ThermostatRunningState.ID] = thermostat_operating_state_handler,
        [Thermostat.attributes.SystemMode.ID] = thermostat_mode_handler,
        [Thermostat.attributes.OccupiedHeatingSetpoint.ID] = heating_setpoint_handler,
        [Thermostat.attributes.UnoccupiedHeatingSetpoint.ID] = away_heating_setpoint_handler,
        [Thermostat.attributes.OutdoorTemperature.ID] = floor_Temperature_handler,
        [Thermostat.attributes.ControlSequenceOfOperation.ID] = do_init,
        [0x2002] = away_mode_handler
      }
    }
  },
  lifecycle_handlers = {
    init = do_init,
    driverSwitched = driver_switched,
    doConfigure = do_configure,
    added = device_added
  },
  can_handle = is_namrom_thermostat
}

return namrom_thermostat