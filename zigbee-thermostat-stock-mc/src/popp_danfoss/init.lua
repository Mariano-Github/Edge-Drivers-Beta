local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local PowerConfiguration = clusters.PowerConfiguration
local ThermostatMode = capabilities.thermostatMode
local Thermostat = clusters.Thermostat


local supported_thermostat_modes_handler = function(driver, device, supported_modes)
  device:emit_event(ThermostatMode.supportedThermostatModes({"heat"}, { visibility = { displayed = false } }))
end

local popp_danfoss_thermostat = {
  NAME = "POPP Danfoss Thermostat Handler",
  zigbee_handlers = {
    attr = {
      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryVoltage.ID] = battery_defaults.battery_volt_attr_handler
      },
      [Thermostat.ID] = {
        [Thermostat.attributes.ControlSequenceOfOperation.ID] = supported_thermostat_modes_handler
      }
    }
  },
  lifecycle_handlers = {
    init = battery_defaults.build_linear_voltage_init(2.4, 3.2)
  },
  can_handle = require("popp_danfoss.can_handle"),
}

return popp_danfoss_thermostat