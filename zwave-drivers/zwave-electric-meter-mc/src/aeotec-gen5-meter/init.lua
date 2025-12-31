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
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=1 })
-- @type st.zwave.CommandClass.Meter
local Meter = (require "st.zwave.CommandClass.Meter")({version=3})
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"

local POWER_UNIT_WATT = "W"
local ENERGY_UNIT_KWH = "kWh"

local function meter_report_handler(self, device, cmd)

  if cmd.args.scale == Meter.scale.electric_meter.KILOWATT_HOURS then
    local event_arguments = {
      value = cmd.args.meter_value,
      unit = ENERGY_UNIT_KWH
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.energyMeter.energy(event_arguments)
    )
    --- power_consumption_report calculation for Energy app
    local delta_energy = 0.0
    local value_watt = cmd.args.meter_value * 1000 -- need energy in Wh units
    local current_power_consumption = device:get_latest_state("main", capabilities.powerConsumptionReport.ID,
      capabilities.powerConsumptionReport.powerConsumption.NAME)
    if current_power_consumption ~= nil then
      --delta_energy = math.max(value_watt - current_power_consumption.energy, 0.0)
      delta_energy = value_watt - current_power_consumption.energy
    end
    device:emit_event(capabilities.powerConsumptionReport.powerConsumption({ energy = value_watt, deltaEnergy = delta_energy })) -- the unit of these values should be 'Wh'

  elseif cmd.args.scale == Meter.scale.electric_meter.WATTS then
    local event_arguments = {
      value = cmd.args.meter_value,
      unit = POWER_UNIT_WATT
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.powerMeter.power(event_arguments)
    )
  elseif cmd.args.scale == Meter.scale.electric_meter.VOLTS then
    local event_arguments = {
      value = cmd.args.meter_value,
      unit = "V"
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.voltageMeasurement.voltage(event_arguments)
    )

  elseif cmd.args.scale == Meter.scale.electric_meter.AMPERES then
    local event_arguments = {
      value = cmd.args.meter_value,
      unit = "A"
    }
    device:emit_event_for_endpoint(
      cmd.src_channel,
      capabilities.currentMeasurement.current(event_arguments)
    )
  end
end

local function get_refresh_commands(driver, device)
   device:send(Meter:Get({scale = Meter.scale.electric_meter.WATTS}))
   device:send(Meter:Get({scale = Meter.scale.electric_meter.KILOWATT_HOURS}))
   device:send(Meter:Get({scale = Meter.scale.electric_meter.VOLTS}))
   device:send(Meter:Get({scale = Meter.scale.electric_meter.AMPERES}))
end

local do_configure = function (self, device)
  device:send(Configuration:Set({parameter_number = 2, size = 1, configuration_value = 0}))     -- Solar readings of energy, 0 = absolute value w and kwh
  device:send(Configuration:Set({parameter_number = 3, size = 1, configuration_value = 0}))    -- enabling automatic reports, disabled selective reporting...
  device:send(Configuration:Set({parameter_number = 13, size = 1, configuration_value = 0}))   -- disable CRC16 encapsulation
  device:send(Configuration:Set({parameter_number = 101, size = 4, configuration_value = 15}))   -- report total power in Watts and total energy in kWh...A and V for group 1
  device:send(Configuration:Set({parameter_number = 111, size = 4, configuration_value = 300})) -- ...every 5 min for group 1
  device:send(Configuration:Set({parameter_number = 102, size = 4, configuration_value = 0}))   -- disable group 2...
  --device:send(Configuration:Set({parameter_number = 103, size = 4, configuration_value = 0}))   -- disable group 3...
  device:send(Configuration:Set({parameter_number = 112, size = 4, configuration_value = 3600})) -- ...every 60 min for group 2
  device:send(Configuration:Set({parameter_number = 252, size = 1, configuration_value = 0}))    -- disabling settings lock
end

--- do_driverSwitched
local function do_driverSwitched(driver, device)
  print("<<<< DriverSwitched >>>>")
  device.thread:call_with_delay(2, function(d)
    device:send(Configuration:Set({parameter_number = 101, size = 4, configuration_value = 15}))   -- report total power in Watts and total energy in kWh...A and V for group 1
    local value = tonumber(device.preferences.selectiveReporting)
    device:send(Configuration:Set({parameter_number = 2, size = 1, configuration_value = value}))     -- Solar readings of energy, 0 = absolute value w and kwh
    value = tonumber(device.preferences.thresholdWatt)
    device:send(Configuration:Set({parameter_number = 3, size = 1, configuration_value = value}))    -- enabling automatic reports, disabled selective reporting...
    value = tonumber(device.preferences.crcSixteen)
    device:send(Configuration:Set({parameter_number = 13, size = 1, configuration_value = value}))   -- disable CRC16 encapsulation
    value = tonumber(device.preferences.group1Time)
    device:send(Configuration:Set({parameter_number = 111, size = 4, configuration_value = value})) -- ...interval report for group 1
    value = tonumber(device.preferences.configLock)
    device:send(Configuration:Set({parameter_number = 252, size = 1, configuration_value = value}))    -- disabling or enabling settings lock
    get_refresh_commands(driver, device)
  end, "configure")
end

local aeotec_gen5_meter = {
  lifecycle_handlers = {
    doConfigure = do_configure,
    added = get_refresh_commands,
    driverSwitched = do_driverSwitched,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = get_refresh_commands,
    },
  },
  zwave_handlers = {
    [cc.METER] = {
      [Meter.REPORT] = meter_report_handler
    }
  },
  NAME = "aeotec gen5 meter",
  can_handle = require("aeotec-gen5-meter.can_handle"),
}

return aeotec_gen5_meter
