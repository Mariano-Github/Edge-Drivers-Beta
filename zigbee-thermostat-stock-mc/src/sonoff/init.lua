local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
--local battery_defaults = require "st.zigbee.defaults.battery_defaults"
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
  --[ThermostatSystemMode.AUTO]              = ThermostatMode.thermostatMode.auto
}

local SONOFF_THERMOSTAT_FINGERPRINTS = {
  { mfr = "SONOFF", model = "TRVZB" }
}

local is_sonoff_thermostat = function(opts, driver, device)
  for _, fingerprint in ipairs(SONOFF_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("sonoff")
      return true, subdriver
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

local function thermostat_operating_state_handler(driver, device, operating_state)
  if  operating_state:is_heat_on_set() then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.heating())
  else
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.idle())
  end
end

local function do_init(driver,device)
  --battery_defaults.build_linear_voltage_init(2.4, 3.2)

  device:emit_event(ThermostatMode.supportedThermostatModes({"off", "heat"}, { visibility = { displayed = false } }))
  -- set selected profile
  if device.preferences.changeProfileSonoff == "Single" then
    device:try_update_metadata({profile = "thermostat-sonoff"})
  elseif device.preferences.changeProfileSonoff == "Multi" then
    device:try_update_metadata({profile = "thermostat-sonoff-multi"})
  end

  -- set battery type and quantity
  local cap_status = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.type.NAME)
  if cap_status == nil and device.preferences.batteryType ~= nil then
    device:emit_event(capabilities.battery.type(device.preferences.batteryType))
  end

  cap_status = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.quantity.NAME)
  if cap_status == nil and device.preferences.batteryQuantity ~= nil then
    device:emit_event(capabilities.battery.quantity(device.preferences.batteryQuantity))
  end
end

local function do_configure(self, device)
  device:send(device_management.build_bind_request(device, Thermostat.ID, self.environment_info.hub_zigbee_eui))
  device:send(Thermostat.attributes.LocalTemperature:configure_reporting(device, 30, 300, 50))
  device:send(Thermostat.attributes.OccupiedHeatingSetpoint:configure_reporting(device, 1, 600, 50))
  device:send(Thermostat.attributes.SystemMode:configure_reporting(device, 1, 0, 1))
  device:send(Thermostat.attributes.ThermostatRunningState:configure_reporting(device, 30, 300))
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1))
  --device:send(PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 30, 21600, 1))

  print("doConfigure performed, transitioning device to PROVISIONED") --23/12/23
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
end

local do_refresh = function(self, device)
  local attributes = {
    Thermostat.attributes.LocalTemperature,
    Thermostat.attributes.ThermostatRunningState,
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
  --do_configure(self, device)
  device.thread:call_with_delay(2, function() 
    do_configure(self,device)
    --print("doConfigure performed, transitioning device to PROVISIONED")
    --device:try_update_metadata({ provisioning_state = "PROVISIONED" })
  end)
end

-- battery_percentage_handler
local function battery_percentage_handler(driver, device, raw_value, zb_rx)

  local percentage = utils.clamp_value(utils.round(raw_value.value / 2), 0, 100)
  device:emit_event(capabilities.battery.battery(percentage))
end

local sonoff_thermostat = {
  NAME = "SONOFF Thermostat Handler",
  capability_handlers = {
    [ThermostatMode.ID] = {
      [ThermostatMode.commands.setThermostatMode.NAME] = set_thermostat_mode,
    },
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
        [Thermostat.attributes.SystemMode.ID] = thermostat_mode_handler,
        [Thermostat.attributes.ThermostatRunningState.ID] = thermostat_operating_state_handler,
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
  can_handle = is_sonoff_thermostat
}

return sonoff_thermostat