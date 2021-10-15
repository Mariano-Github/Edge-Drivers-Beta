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

-- ******* Created by Mariano Colmenarejo (sep 2021) *********

--- Smartthings library load ---
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff

-- driver local modules load
local dimmer =require "dimmer"

--- Custom Capabilities
local random_On_Off = capabilities["legendabsolute60149.randomOnOff1"]
local prog_On = capabilities["legendabsolute60149.progressiveOn1"]
local prog_Off = capabilities["legendabsolute60149.progressiveOff1"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep"]
local level_Steps = capabilities["legendabsolute60149.levelSteps"]
local color_Temperature_Steps = capabilities["legendabsolute60149.colorTemperatureSteps"]


----- driver template configuration-----
local zigbee_bulb_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.switchLevel,
    level_Steps,
    capabilities.colorTemperature,
    color_Temperature_Steps,
    random_On_Off,
    random_Next_Step,
    prog_On,
    prog_Off,
    capabilities.refresh
  },
  lifecycle_handlers = {
  init = dimmer.do_init,
  infoChanged = dimmer.do_Preferences,
  removed = dimmer.do_removed
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = dimmer.on_handler,
      [capabilities.switch.commands.off.NAME] = dimmer.off_handler
    },
    [random_On_Off.ID] = {
      [random_On_Off.commands.setRandomOnOff.NAME] = dimmer.random_on_off_handler,
    },
    [level_Steps.ID] = {
      [level_Steps.commands.setLevelSteps.ID] = dimmer.level_Steps_handler,
    },
    [color_Temperature_Steps.ID] = {
      [color_Temperature_Steps.commands.setColorTempSteps.ID] = dimmer.color_Temperature_Steps_handler,
    },
    [prog_On.ID] = {
      [prog_On.commands.setProgOn.NAME] = dimmer.prog_On_handler,
    },
    [prog_Off.ID] = {
      [prog_Off.commands.setProgOff.NAME] = dimmer.prog_Off_handler,
    }
  },
}
-- run driver
defaults.register_for_default_handlers(zigbee_bulb_driver_template, zigbee_bulb_driver_template.supported_capabilities)
local zigbee_bulb = ZigbeeDriver("Zigbee_Level_ColorTemperature_Bulb", zigbee_bulb_driver_template)
zigbee_bulb:run()