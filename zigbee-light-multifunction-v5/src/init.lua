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
local utils = require "st.utils"
local Groups = zcl_clusters.Groups

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
local color_Changing = capabilities["legendabsolute60149.colorChanging"]
local color_Change_Timer = capabilities["legendabsolute60149.colorChangeTimer"]
local color_Change_Mode = capabilities["legendabsolute60149.colorChangeMode"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]

--- switch_level_handler
local function switch_level_handler(self,device,command)
  --print("handler_Level >>>>>>>>>>>>>>",command.args.level)
  local on_Level = command.args.level
  if device.preferences.levelTransTime == 0 then
    device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
  else
    device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), (device.preferences.levelTransTime * 4)))
  end
  --print("<<<< emit Level >>>>")
  --device:emit_event(capabilities.switchLevel.level(math.floor((on_Level / 254.0 * 100) + 0.5)))
end

---color_Temperature_handler
local function color_Temperature_handler(self,device,command)
  --print("handler_Color Temp >>>>>>>>>>>>>>",command.args.temperature)
  local colorTemp = command.args.temperature
  local colorTemp_Mireds= math.floor(1000000 / colorTemp)
  --print("colorTemp Mired", colorTemp_Mireds)
  --device:send(OnOff.server.commands.On(device))
  device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device:get_field("last_Level")/100.0 * 254), (device.preferences.onTransTime * 4)))
  device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds,(device.preferences.tempTransTime * 4)))
  --device:emit_event(capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))

end

--- color_control_handler
local function color_control_handler(self,device,command)
  local hue = math.floor((command.args.color.hue * 0xFE) / 100.0 + 0.5)
  local sat = math.floor((command.args.color.saturation * 0xFE) / 100.0 + 0.5)
  device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device:get_field("last_Level")/100.0 * 254), (device.preferences.onTransTime * 4)))
  device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToHueAndSaturation(device, hue, sat, (device.preferences.colorTransTime * 4)))
end


---- On-Off Emit event
local function on_off_attr_handler(self, device, value, zb_rx)
  --print("<<<<< Emit on_off >>>>>>")
  local attr = capabilities.switch.switch
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, value.value and attr.on() or attr.off())
 end
 
 ---- Level emit event
 local function level_attr_handler(driver, device, value, zb_rx)
   --print("<<<< emit Level >>>>")
   device:emit_event(capabilities.switchLevel.level(math.floor((value.value / 254.0 * 100) + 0.5)))
 end

 ----- Groups_handler
local function Groups_handler(driver, device, value, zb_rx)

  local zb_message = value
  local group_list = zb_message.body.zcl_body.group_list_list
  --Print table group_lists with function utils.stringify_table(group_list)
  print("group_list >>>>>>",utils.stringify_table(group_list))
  
  local group_Names =""
  for i, value in pairs(group_list) do
    print("Message >>>>>>>>>>>",group_list[i].value)
    group_Names = group_Names..tostring(group_list[i].value).."-"
  end
  --local text_Groups = "Groups Added: "..group_Names
  local text_Groups = group_Names
  if text_Groups == "" then text_Groups = "All Deleted" end
  print (text_Groups)
  device:emit_event(get_Groups.getGroups(text_Groups))
end

----- delete_all_groups_handler
local function delete_all_groups_handler(self, device, command)
  device:send(Groups.server.commands.RemoveAllGroups(device, {}))
  device:send(Groups.server.commands.GetGroupMembership(device, {}))
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
    circadian_Light,
    color_Changing,
    color_Change_Timer,
    color_Change_Mode,
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
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = switch_level_handler
    },
    [capabilities.colorTemperature.ID] = {
      [capabilities.colorTemperature.commands.setColorTemperature.NAME] = color_Temperature_handler
    },
    [capabilities.colorControl.ID] = {
      [capabilities.colorControl.commands.setColor.NAME] = color_control_handler
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
    },
    [color_Changing.ID] = {
      [color_Changing.commands.setColorChanging.NAME] = dimmer.color_Changing_handler,
    },
    [color_Change_Timer.ID] = {
      [color_Change_Timer.commands.setColorChangeTimer.NAME] = dimmer.color_Change_Timer_handler,
    },
    [color_Change_Mode.ID] = {
      [color_Change_Mode.commands.setColorChangeMode.NAME] = dimmer.color_Change_Mode_handler,
    },
    [get_Groups.ID] = {
      [get_Groups.commands.setGetGroups.NAME] = delete_all_groups_handler,
    },
  },
  zigbee_handlers = {
    global = {},
    cluster = {
        [zcl_clusters.Groups.ID] = {
          [zcl_clusters.Groups.commands.GetGroupMembershipResponse.ID] = Groups_handler
        }
    },
    attr = {
      --[zcl_clusters.OnOff.ID] = {
         --[zcl_clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
      --},
      --[LevelControlCluster.ID] = {
        --[LevelControlCluster.attributes.CurrentLevel.ID] = level_attr_handler
      --}
    },
  }
}
-- run driver
defaults.register_for_default_handlers(zigbee_bulb_driver_template, zigbee_bulb_driver_template.supported_capabilities)
local zigbee_bulb = ZigbeeDriver("zigbee_light_multifunctions", zigbee_bulb_driver_template)
zigbee_bulb:run()