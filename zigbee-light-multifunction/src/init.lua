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
local LevelControlCluster = zcl_clusters.Level
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
local circadian_Light = capabilities["legendabsolute60149.circadian"]

---- On-Off Emit event
local function on_off_attr_handler(self, device, value, zb_rx)
  print("<<<<< Emit on_off >>>>>>")
  local attr = capabilities.switch.switch
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, value.value and attr.on() or attr.off())
 end
 
 ---- Level emit event
 local function level_attr_handler(driver, device, value, zb_rx)
   print("<<<< emit Level >>>>")
   device:emit_event(capabilities.switchLevel.level(math.floor((value.value / 254.0 * 100) + 0.5)))
 end

 ----- driver template configuration-----
local zigbee_bulb_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.switchLevel,
    capabilities.colorControl,
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
    },
    [circadian_Light.ID] = {
      [circadian_Light.commands.setCircadian.NAME] = dimmer.circadian_Light_handler,
    }
  },
  zigbee_handlers = {
    global = {},
    cluster = {},
    attr = {
      [zcl_clusters.OnOff.ID] = {
         [zcl_clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
      },
      [LevelControlCluster.ID] = {
        [LevelControlCluster.attributes.CurrentLevel.ID] = level_attr_handler
      }
    },
  }
}
-- run driver
defaults.register_for_default_handlers(zigbee_bulb_driver_template, zigbee_bulb_driver_template.supported_capabilities)
local zigbee_bulb = ZigbeeDriver("zigbee_light_multifunctions", zigbee_bulb_driver_template)
zigbee_bulb:run()