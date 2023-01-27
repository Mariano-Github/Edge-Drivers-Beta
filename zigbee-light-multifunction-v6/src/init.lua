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

local switch_defaults = require "st.zigbee.defaults.switch_defaults"
local LAST_KELVIN_SET = "last_kelvin_set"
local CONVERSION_CONSTANT = 1000000

-- driver local modules load
local dimmer =require "dimmer"
--local write =require "writeAttribute"

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
local color_Change_Mode = capabilities["legendabsolute60149.colorChangeMode1"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]
local forced_On_Level = capabilities["legendabsolute60149.forcedOnLevel"]

-- read atributtes for level colot Temp and color
local function attributes_read(self,device,command)
  local color_read = function(d)
    device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.CurrentHue:read(device))
    device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.CurrentSaturation:read(device))
  end
  local color_temp_read = function(d)
    device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
  end
  local level_read = function(d)
    device:send_to_component(command.component, zcl_clusters.Level.attributes.CurrentLevel:read(device))
    if device:get_model() == "GL-B-008Z" or 
      device:get_model() == "ZB-CL01" or
      device:get_model() == "GL-D-004ZS" or
      device:get_model() == "GL-MC-001" then
        device:send_to_component(command.component,zcl_clusters.OnOff.attributes.OnOff:read(device))
    end
  end
  if device.preferences.levelTransTime ~= nil then
    device.thread:call_with_delay(device.preferences.levelTransTime + 0.5, level_read, "setLevel delayed read")
  end
  if device.preferences.tempTransTime ~= nil and command.args.temperature ~= nil then
    device.thread:call_with_delay(device.preferences.tempTransTime + 1, color_temp_read, "setColorTemp delayed read")
  end
  if device.preferences.colorTransTime ~= nil then
    device.thread:call_with_delay(device.preferences.colorTransTime + 2, color_read, "setColor delayed read")
  end
end

--- switch_level_handler
local function switch_level_handler(self,device,command)
  print("handler_Level >>>>>>>>>>>>>>",command.args.level)
  local on_Level = command.args.level
  if on_Level < device.preferences.setLevelMin then on_Level = device.preferences.setLevelMin end
  device:set_field("last_Level", on_Level, {persist = true})

  if device:get_manufacturer() == "IKEA of Sweden" then
    device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0x0))
  else
    if device.preferences.levelTransTime == 0 then
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
      if device:get_manufacturer() == "_TZ3210_dxroobu3" or device:get_manufacturer() =="_TZ3210_09hzmirw" then
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
      end
    else
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), math.floor((device.preferences.levelTransTime * 4))))
      if device:get_manufacturer() == "_TZ3210_dxroobu3" or device:get_manufacturer() =="_TZ3210_09hzmirw" then
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), math.floor((device.preferences.levelTransTime * 4))))
      end
    end
  end
  
  local level_read = function(d)
    device:send_to_component(command.component, zcl_clusters.Level.attributes.CurrentLevel:read(device))
    if device:get_model() == "GL-B-008Z" or
      device:get_model() == "GL-C-008" or
      device:get_model() == "ZB-CL01" or
      device:get_model() == "GL-D-004ZS" or
      device:get_model() == "GL-MC-001" then
      device:send_to_component(command.component,zcl_clusters.OnOff.attributes.OnOff:read(device))
    end
  end
    device.thread:call_with_delay(device.preferences.levelTransTime + 1, level_read, "setLevel delayed read")
end

---color_Temperature_handler
local function set_color_Temperature_handler(self,device,command)
  print("handler_Color Temp >>>>>>>>>>>>>>",command.args.temperature)
  local colorTemp = command.args.temperature
  if device.preferences.limitColorTemp == true then 
    if colorTemp > device.preferences.colorTempMaxim then 
      colorTemp = tonumber(math.floor(device.preferences.colorTempMaxim))
    elseif colorTemp < device.preferences.colorTempMinim then 
      colorTemp = tonumber(math.floor(device.preferences.colorTempMinim))
    end
  end
  device:set_field(LAST_KELVIN_SET .. command.component, colorTemp)
  local colorTemp_Mireds= utils.round(1000000 / colorTemp)
  --print("colorTemp Mired", colorTemp_Mireds)

  local last_Level = device:get_field("last_Level")
  if last_Level == nil then 
    last_Level = 100
    device:set_field("last_Level", 100, {persist = true})
  end

  if device:get_manufacturer() == "IKEA of Sweden" then
    device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), 0x0))
  else
    if device.preferences.levelTransTime == 0 then
      --:to_endpoint(endpoint)
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), 0xFFFF))
    else
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), math.floor((device.preferences.levelTransTime * 4))))
    end
  end

  device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds,math.floor((device.preferences.tempTransTime * 4))))
  attributes_read(self,device,command)
end

--- color_control_handler
local function color_control_handler(self,device,command)
  print("<<<<<<< color_control_handler >>>>>>")
  local hue = math.floor((command.args.color.hue * 0xFE) / 100.0 + 0.5)
  local sat = math.floor((command.args.color.saturation * 0xFE) / 100.0 + 0.5)
  --local last_Level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
  local last_Level = device:get_field("last_Level")
  if last_Level == nil then 
    last_Level = 100
    device:set_field("last_Level", 100, {persist = true})
  end

  if device:get_manufacturer() == "IKEA of Sweden" then
    device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), 0x0))
  else
    if device.preferences.levelTransTime == 0 then
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), 0xFFFF))
    else
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), math.floor(device.preferences.levelTransTime * 4)))
    end
  end

  device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToHueAndSaturation(device, hue, sat, math.floor(device.preferences.colorTransTime * 4)))
  attributes_read(self,device,command)
end

---- On-Off Emit event
local function on_off_attr_handler(self, device, value, zb_rx)
  --print("<<<<< Emit on_off >>>>>>")
  --print("table zb_rx >>>>>>",utils.stringify_table(zb_rx))

  --print("LQI >>>>>",zb_rx.lqi.value)
  --print("RSSI >>>>>",zb_rx.rssi.value)
  --print (string.format("src_Address: 0x%04X", zb_rx.address_header.src_addr.value))

  local visible_satate = false
  if device.preferences.signalMetricsVisibles == "Yes" then
    visible_satate = true
  end
  
  local gmt = os.date("%Y/%m/%d Time: %H:%M",os.time())
  local dni = string.format("0x%04X", zb_rx.address_header.src_addr.value)
  --local metrics = "<em table style='font-size:70%';'font-weight: bold'</em>".. <b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
  local metrics = "<em table style='font-size:75%';'font-weight: bold'</em>".. "<b>GMT: </b>".. gmt .."<BR>"
  metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"

  device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))

  local attr = capabilities.switch.switch
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, value.value and attr.on() or attr.off())
 end

 ----Level emit event
 local function level_attr_handler(driver, device, value, zb_rx)
  print("<<<< emit Level >>>>")

  -- device:set_field("last_Level", math.floor((value.value / 254.0 * 100) + 0.5), {persist = true})

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

---- color_temperature_handler
local function color_temperature_handler(driver, device, value, zb_rx)
  print("<< Emit Color temp >>")
  local endpoint_id = zb_rx.address_header.src_endpoint.value
  local component_id = device:get_component_id_for_endpoint(endpoint_id)
  local temp_in_mired = value.value
  local last_kelvin_set = device:get_field(LAST_KELVIN_SET .. component_id)
  local temp_in_kelvin = utils.round(CONVERSION_CONSTANT / temp_in_mired)

  if device.preferences.logDebugPrint == true then
    print("temp_in_mired >>>>>",value.value)
    print("last_kelvin_set >>>>>", last_kelvin_set)
    print("temp_in_kelvin >>>>>", temp_in_kelvin)
  end
  -- Because we are converting from Kelvin to mireds and back, we often get rounding errors over the round trip
  -- this value substitution insures that the number the user sets in the UI matches what is generated by the event
  if last_kelvin_set ~= nil and
    last_kelvin_set >= utils.round(CONVERSION_CONSTANT/(temp_in_mired + 1)) and last_kelvin_set <= utils.round(CONVERSION_CONSTANT/(temp_in_mired - 1)) then
    temp_in_kelvin = last_kelvin_set
    print("Corrected temp_in_kelvin >>>>>", temp_in_kelvin)
  else
    if last_kelvin_set == nil then
      temp_in_kelvin = tonumber(math.floor(device.preferences.colorTempMaxim))
    else
      temp_in_kelvin = last_kelvin_set
    end
  end
  if device.preferences.limitColorTemp == true then 
    if temp_in_kelvin > device.preferences.colorTempMaxim then 
      temp_in_kelvin = tonumber(math.floor(device.preferences.colorTempMaxim))
    elseif temp_in_kelvin < device.preferences.colorTempMinim then 
      temp_in_kelvin = tonumber(math.floor(device.preferences.colorTempMinim))
    end
  end
  if device.preferences.logDebugPrint == true then
    print("<<<< temp_in_kelvin emit >>>>>",temp_in_kelvin)
  end
  device:set_field(LAST_KELVIN_SET .. component_id, temp_in_kelvin)
  device:emit_event_for_endpoint(endpoint_id, capabilities.colorTemperature.colorTemperature(temp_in_kelvin))
end

---color_hue_handler
local function color_hue_handler(driver, device, value, zb_rx)
  if device:get_field("colorChanging") =="Active" then return end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.colorControl.hue(math.floor(value.value / 0xFE * 100)))
end

---  color_Saturation_handler
local function  color_Saturation_handler(driver, device, value, zb_rx)
  if device:get_field("colorChanging") =="Active" then return end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.colorControl.saturation(math.floor(value.value / 0xFE * 100)))
end

--forced_On_Level_handler
local function forced_On_Level_handler(driver, device, command)
  print("<<< forced_On_Level_handler:", command.args.value)
  local forced_Level = command.args.value
  device:set_field("forced_Level", forced_Level, {persist = true})

  device:emit_event(forced_On_Level.forcedOnLevel(forced_Level))

end

-- driver_Switched set profile selected
local function driver_Switched(driver,device)
  ------ Change profile RGBW color temperature
  print("<<<< device.preferences.changeProfile",device.preferences.changeProfile)
  if device.preferences.changeProfile == "20006500" then
    print("<< rgbw-level-colortemp-2000-6500 >>")
    device:try_update_metadata({profile = "rgbw-level-colortemp-2000-6500"})
  elseif device.preferences.changeProfile == "27006500" and device.preferences.colorTempMinim >= 2700 then
    print("<< rgbw-level-colortemp-2700-6500 >>")
    device:try_update_metadata({profile = "rgbw-level-colortemp-2700-6500"})
  elseif device.preferences.changeProfile == "22004000" and device.preferences.colorTempMaxim <= 4000 and device.preferences.colorTempMinim >= 2200 then
    print("<< rgbw-level-colortemp-2200-4000 >>")
    device:try_update_metadata({profile = "rgbw-level-colortemp-2200-4000"})
  end 
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
    removed = dimmer.do_removed,
    driverSwitched = driver_Switched
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
      [capabilities.colorTemperature.commands.setColorTemperature.NAME] = set_color_Temperature_handler
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
    [forced_On_Level.ID] = {
      [forced_On_Level.commands.setForcedOnLevel.NAME] = forced_On_Level_handler,
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
      [zcl_clusters.OnOff.ID] = {
        [zcl_clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
      },
      --[LevelControlCluster.ID] = {
        --[LevelControlCluster.attributes.CurrentLevel.ID] = level_attr_handler
      --},
      --[zcl_clusters.ColorControl.ID] = {
        --[zcl_clusters.ColorControl.attributes.ColorTemperatureMireds.ID] = color_temperature_handler
      --},
      [zcl_clusters.ColorControl.ID] = {
        [zcl_clusters.ColorControl.attributes.CurrentHue.ID] = color_hue_handler,
        [zcl_clusters.ColorControl.attributes.CurrentSaturation.ID] = color_Saturation_handler,
        [zcl_clusters.ColorControl.attributes.ColorTemperatureMireds.ID] = color_temperature_handler
      }
    },
  },
  sub_drivers = {
    require("xy-color-bulb")
  },
}
-- run driver
defaults.register_for_default_handlers(zigbee_bulb_driver_template, zigbee_bulb_driver_template.supported_capabilities)
local zigbee_bulb = ZigbeeDriver("zigbee_light_multifunctions", zigbee_bulb_driver_template)
zigbee_bulb:run()