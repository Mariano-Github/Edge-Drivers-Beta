local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
--local battery_defaults = require "st.zigbee.defaults.battery_defaults"
--local PowerConfiguration = clusters.PowerConfiguration
local ThermostatMode = capabilities.thermostatMode
local Thermostat = clusters.Thermostat

local ElectricalMeasurement = clusters.ElectricalMeasurement
local SimpleMetering = clusters.SimpleMetering

local ThermostatSystemMode      = Thermostat.attributes.SystemMode
local ThermostatOperatingState = capabilities.thermostatOperatingState
--local utils             = require "st.utils"
local device_management = require "st.zigbee.device_management"
local data_types = require "st.zigbee.data_types"

local write = require "writeAttribute"

local THERMOSTAT_MODE_MAP = {
  [ThermostatSystemMode.OFF]               = ThermostatMode.thermostatMode.off,
  [ThermostatSystemMode.HEAT]              = ThermostatMode.thermostatMode.heat,
  [ThermostatSystemMode.SLEEP]              = ThermostatMode.thermostatMode.asleep,
}

local NAMROM_THERMOSTAT_FINGERPRINTS = {
  { mfr = "NAMRON AS", model = "4512749-N" }
}

local is_namrom_plug_thermostat = function(opts, driver, device)
  for _, fingerprint in ipairs(NAMROM_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("namrom-plug")
      return true, subdriver
    end
  end
  return false
end

local thermostat_mode_handler = function(driver, device, thermostat_mode)
  print("<<<<< thermostat_mode.value >>>", thermostat_mode.value)
  if THERMOSTAT_MODE_MAP[thermostat_mode.value] then
    device:emit_event(THERMOSTAT_MODE_MAP[thermostat_mode.value]())
  end
end

local function set_thermostat_mode (driver, device, command)
  print("<<<< command.args.mode",command.args.mode)
    for zigbee_attr_val, st_cap_val in pairs(THERMOSTAT_MODE_MAP) do
      if command.args.mode == st_cap_val.NAME then
        --device:send(Thermostat.attributes.SystemMode:write(device, zigbee_attr_val))
        device:send(write.custom_write_attribute(device, 0x0201, 0x001C, data_types.Enum8, zigbee_attr_val))
        device.thread:call_with_delay(1, function(d)
          device:send(Thermostat.attributes.SystemMode:read(device))
        end)
        break
      end
    end
end

local function set_heating_setpoint(driver, device, command)
  device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = command.args.setpoint*1.0, unit = "C"}))
  --device:send(Thermostat.attributes.OccupiedHeatingSetpoint:write(device, command.args.setpoint*100))
  device:send(write.custom_write_attribute(device, 0x0201, 0x0012, data_types.Int16, command.args.setpoint * 100))
end


local function thermostat_operating_state_handler(driver, device, operating_state)
  if  operating_state:is_heat_on_set() then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.heating())
  else
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.idle())
  end
end

local function heating_setpoint_handler(driver, device, value)
  device:emit_event(capabilities.thermostatHeatingSetpoint.heatingSetpoint({value = value.value/100.0, unit = "C"}))
end

--- voltage_handler
local function voltage_handler(driver, device, value, zb_rx)
  print(">>>> Voltage handler")
  local raw_value = value.value / 10

  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.voltageMeasurement.voltage(raw_value))
end

local function do_init(driver,device)
  device:emit_event(ThermostatMode.supportedThermostatModes({"off", "heat", "asleep"}, { visibility = { displayed = false } }))
end

local function do_configure(self, device)

  -- Additional one time configuration
      -- Divisor and multipler for ElectricalMeasurement
      device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
      device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
      -- Divisor and multipler for SimpleMetering
      device:send(SimpleMetering.attributes.Divisor:read(device))
      device:send(SimpleMetering.attributes.Multiplier:read(device))

  device:configure()
  device:send(ElectricalMeasurement.attributes.RMSVoltage:configure_reporting(device, 30, 1800, 10))
  device:send(device_management.build_bind_request(device, Thermostat.ID, self.environment_info.hub_zigbee_eui, 2):to_endpoint (2))
  device:send(Thermostat.attributes.LocalTemperature:configure_reporting(device, 10, 60, 50):to_endpoint (2))
  device:send(Thermostat.attributes.OccupiedHeatingSetpoint:configure_reporting(device, 1, 600, 50):to_endpoint (2))
  device:send(Thermostat.attributes.ControlSequenceOfOperation:configure_reporting(device, 10, 600):to_endpoint (2))
  device:send(Thermostat.attributes.SystemMode:configure_reporting(device, 10, 600):to_endpoint (2))
  device:send(Thermostat.attributes.ThermostatRunningState:configure_reporting(device, 10, 300):to_endpoint (2))

  print("doConfigure performed, transitioning device to PROVISIONED") --23/12/23
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
end

local do_refresh = function(self, device)
  local attributes = {
    Thermostat.attributes.LocalTemperature,
    Thermostat.attributes.OccupiedHeatingSetpoint,
    Thermostat.attributes.SystemMode,
    Thermostat.attributes.ThermostatRunningState,
    ElectricalMeasurement.attributes.RMSVoltage
  }
  for _, attribute in pairs(attributes) do
    device:send(attribute:read(device))
  end
  device:refresh()
end

local device_added = function(self, device)
  -- set operation thermostat function, value 0 = plug, valure = 1 thermostat
  --local value_send = 0x0001
    --local data_value = {value = value_send, ID = 0x30}
    --local cluster_id = {value = 0x0000}
    --local attr_id = 0x1000
    --mfg_code = 0x1224
    --write.write_attribute_function(device, cluster_id, attr_id, data_value)
  device:send(write.custom_write_attribute(device, 0x0000, 0x1000, data_types.Enum8, 1, 0x1224))
  do_refresh(self, device)
end

local driver_switched = function(self, device)
  do_refresh(self, device)
  --do_configure(self, device)
  device.thread:call_with_delay(2, function() 
    do_configure(self,device)
    --print("doConfigure performed, transitioning device to PROVISIONED")
    --device:try_update_metadata({ provisioning_state = "PROVISIONED" })
  end)
end


local namrom_plug_thermostat = {
  NAME = "NAMROM Plug Thermostat",
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
        [Thermostat.attributes.ControlSequenceOfOperation.ID] = do_init,
      },
      [ElectricalMeasurement.ID] = {
        [ElectricalMeasurement.attributes.RMSVoltage.ID] = voltage_handler,
      },
    }
  },
  lifecycle_handlers = {
    init = do_init,
    driverSwitched = driver_switched,
    doConfigure = do_configure,
    added = device_added
  },
  can_handle = is_namrom_plug_thermostat
}

return namrom_plug_thermostat