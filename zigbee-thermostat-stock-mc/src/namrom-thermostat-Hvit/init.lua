local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local ThermostatMode = capabilities.thermostatMode
local Thermostat = clusters.Thermostat

local ThermostatOperatingState = capabilities.thermostatOperatingState
local ElectricalMeasurement = clusters.ElectricalMeasurement
local SimpleMetering = clusters.SimpleMetering
local device_management = require "st.zigbee.device_management"


local function thermostat_operating_state_handler(driver, device, operating_state)
  if  operating_state == 0x04 then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.heating())
  elseif  operating_state == 0x03 then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.cooling())
  else
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.idle())
  end
end

local function do_init(driver,device)
  device:emit_event(ThermostatMode.supportedThermostatModes({"off", "heat", "auto", "cool"}, { visibility = { displayed = false } }))
end

local function do_configure(self, device)

  device:configure()

  device:send(device_management.build_bind_request(device, Thermostat.ID, self.environment_info.hub_zigbee_eui))
  device:send(Thermostat.attributes.LocalTemperature:configure_reporting(device, 10, 300, 50))
  device:send(Thermostat.attributes.OccupiedHeatingSetpoint:configure_reporting(device, 1, 600, 50))
  device:send(Thermostat.attributes.OccupiedCoolingSetpoint:configure_reporting(device, 1, 600, 50))
  device:send(Thermostat.attributes.ControlSequenceOfOperation:configure_reporting(device, 10, 600))
  device:send(Thermostat.attributes.SystemMode:configure_reporting(device, 10, 600))
  device:send(Thermostat.attributes.ThermostatRunningMode:configure_reporting(device, 10, 600))

  -- Additional one time configuration
    -- Divisor and multipler for ElectricalMeasurement
    device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
    device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
    -- Divisor and multipler for SimpleMetering
    device:send(SimpleMetering.attributes.Divisor:read(device))
    device:send(SimpleMetering.attributes.Multiplier:read(device))

  print("doConfigure performed, transitioning device to PROVISIONED") --23/12/23
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
end

local do_refresh = function(self, device)
  local attributes = {
    Thermostat.attributes.LocalTemperature,
    Thermostat.attributes.OccupiedCoolingSetpoint,
    Thermostat.attributes.OccupiedHeatingSetpoint,
    Thermostat.attributes.SystemMode,
    Thermostat.attributes.ThermostatRunningMode,
    ElectricalMeasurement.attributes.ActivePower,
    SimpleMetering.attributes.CurrentSummationDelivered
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

  device.thread:call_with_delay(2, function() 
    do_configure(self,device)
  end)
end


local namrom_hvit_thermostat = {
  NAME = "NAMROM Thermostat Hvit Handler",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  zigbee_handlers = {
    attr = {
      [Thermostat.ID] = {
        [Thermostat.attributes.ThermostatRunningMode.ID] = thermostat_operating_state_handler,
        [Thermostat.attributes.ControlSequenceOfOperation.ID] = do_init,
      }
    }
  },
  lifecycle_handlers = {
    init = do_init,
    driverSwitched = driver_switched,
    doConfigure = do_configure,
    added = device_added
  },
  can_handle = require("namrom-thermostat-Hvit.can_handle"),
}

return namrom_hvit_thermostat