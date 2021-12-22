-- Copyright 2021 SmartThings
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

-------- Author Mariano Colmenarejo (Oct 2021)

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local ElectricalMeasurement = zcl_clusters.ElectricalMeasurement
local SimpleMetering = zcl_clusters.SimpleMetering


-- driver local modules load
local random = require "random"

--- Custom Capabilities
local random_On_Off = capabilities["legendabsolute60149.randomOnOff1"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep"]

local do_configure = function(self, device)
  device:refresh()
  device:configure()

  -- Additional one time configuration
  if device:supports_capability(capabilities.energyMeter) or device:supports_capability(capabilities.powerMeter) then
    -- Divisor and multipler for EnergyMeter
    device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
    device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
    -- Divisor and multipler for PowerMeter
    device:send(SimpleMetering.attributes.Divisor:read(device))
    device:send(SimpleMetering.attributes.Multiplier:read(device))
  end
end


---- Driver template config
local zigbee_switch_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.powerMeter,
    capabilities.energyMeter,
    random_On_Off,
    random_Next_Step,
    capabilities.refresh
  },
  lifecycle_handlers = {
    infoChanged = random.do_Preferences,
    init = random.do_init,
    removed = random.do_removed,
    doConfigure = do_configure,
    driverSwitched = do_configure
  },
  capability_handlers = {
    [random_On_Off.ID] = {
      [random_On_Off.commands.setRandomOnOff.NAME] = random.random_on_off_handler,
    },
  },
}
-- run driver
defaults.register_for_default_handlers(zigbee_switch_driver_template, zigbee_switch_driver_template.supported_capabilities)
local zigbee_switch = ZigbeeDriver("Zigbee_Switch", zigbee_switch_driver_template)
zigbee_switch:run()