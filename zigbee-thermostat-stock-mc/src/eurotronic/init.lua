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

local THERMOSTAT_MODE_MAP = {
  [ThermostatSystemMode.OFF]               = ThermostatMode.thermostatMode.off,
  [ThermostatSystemMode.HEAT]              = ThermostatMode.thermostatMode.heat,
  [ThermostatSystemMode.EMERGENCY_HEATING] = ThermostatMode.thermostatMode.emergency_heat
}

local EUROTRONIC_THERMOSTAT_FINGERPRINTS = {
  { mfr = "Eurotronic", model = "SPZB0001" }
}

local is_eurotronic_thermostat = function(opts, driver, device)
  for _, fingerprint in ipairs(EUROTRONIC_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      return true
    end
  end
  return false
end

local thermostat_mode_handler = function(driver, device, thermostat_mode)
  if THERMOSTAT_MODE_MAP[thermostat_mode.value] then
    device:emit_event(THERMOSTAT_MODE_MAP[thermostat_mode.value]())
  end
end

local set_thermostat_mode = function(driver, device, command)
  for zigbee_attr_val, st_cap_val in pairs(THERMOSTAT_MODE_MAP) do
    if command.args.mode == st_cap_val.NAME then
      device:send_to_component(command.component, Thermostat.attributes.SystemMode:write(device, zigbee_attr_val))
      device.thread:call_with_delay(1, function(d)
        device:send_to_component(command.component, Thermostat.attributes.SystemMode:read(device))
      end)
      break
    end
  end
end

local thermostat_mode_setter = function(mode_name)
  return function(driver, device, command)
    return set_thermostat_mode(driver, device, {component = command.component, args = {mode = mode_name}})
  end
end

--TODO: Update this once we've decided how to handle setpoint commands
local set_setpoint_factory = function(setpoint_attribute)
  return function(driver, device, command)
    local value = command.args.setpoint
    if (value >= 40) then -- assume this is a fahrenheit value
      value = utils.f_to_c(value)
    end
    device:send_to_component(command.component, setpoint_attribute:write(device, value*100))

    device.thread:call_with_delay(2, function(d)
      device:send_to_component(command.component, setpoint_attribute:read(device))
    end)
  end
end

local function thermostat_heating_demand_attr_handler(driver, device, value, zb_rx)
  local event = value.value < 5 and ThermostatOperatingState.thermostatOperatingState.idle() or
                 ThermostatOperatingState.thermostatOperatingState.heating()
  device:emit_event(event)
end

local function do_init(driver,device)
  --battery_defaults.build_linear_voltage_init(2.4, 3.2)

  --device:emit_event(ThermostatMode.supportedThermostatModes({"off","heat", "emergency heat"}, { visibility = { displayed = false } }))
  device:emit_event(ThermostatMode.supportedThermostatModes({"heat"}, { visibility = { displayed = false } }))
end

local function do_configure(self, device)
  device:send(device_management.build_bind_request(device, Thermostat.ID, self.environment_info.hub_zigbee_eui))
  device:send(Thermostat.attributes.LocalTemperature:configure_reporting(device, 10, 60, 50))
  device:send(Thermostat.attributes.OccupiedHeatingSetpoint:configure_reporting(device, 1, 600, 50))
  device:send(Thermostat.attributes.PIHeatingDemand:configure_reporting(device, 1, 3600, 1))
  device:send(Thermostat.attributes.SystemMode:configure_reporting(device, 1, 0, 1))
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1))
  --device:send(PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 30, 21600, 1))

end

local do_refresh = function(self, device)
  local attributes = {
    Thermostat.attributes.LocalTemperature,
    Thermostat.attributes.PIHeatingDemand,
    Thermostat.attributes.OccupiedHeatingSetpoint,
    Thermostat.attributes.SystemMode,
    --PowerConfiguration.attributes.BatteryVoltage,
    PowerConfiguration.attributes.BatteryPercentageRemaining
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

-- battery_percentage_handler
local function battery_percentage_handler(driver, device, raw_value, zb_rx)

  local percentage = utils.clamp_value(utils.round(raw_value.value / 2), 0, 100)
  device:emit_event(capabilities.battery.battery(percentage))
end

local eurotronic_thermostat = {
  NAME = "EUROTRONIC Thermostat Handler",
  capability_handlers = {
    [ThermostatMode.ID] = {
      [ThermostatMode.commands.setThermostatMode.NAME] = set_thermostat_mode,
      [ThermostatMode.commands.off.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.off.NAME),
      [ThermostatMode.commands.heat.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.heat.NAME),
      [ThermostatMode.commands.emergencyHeat.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.emergency_heat.NAME)
    },
    --[capabilities.thermostatHeatingSetpoint.ID] = {
      --[capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = set_setpoint_factory(clusters.Thermostat.attributes.OccupiedHeatingSetpoint)
    --},
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  zigbee_handlers = {
    attr = {
      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_percentage_handler 
      },
      [Thermostat.ID] = {
        [Thermostat.attributes.PIHeatingDemand.ID] = thermostat_heating_demand_attr_handler,
        [Thermostat.attributes.SystemMode.ID] = thermostat_mode_handler
      }
    }
  },
  lifecycle_handlers = {
    --init = battery_defaults.build_linear_voltage_init(2.4, 3.2)
    init = do_init,
    driverSwitched = driver_switched,
    doConfigure = do_configure,
    added = device_added
  },
  can_handle = is_eurotronic_thermostat
}

return eurotronic_thermostat