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

-- *******  Created by Mariano Colmenarejo (sep 2021) *********

--- Smartthings library load ---
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local LevelControlCluster = zcl_clusters.Level
local utils = require "st.utils"
local Groups = zcl_clusters.Groups

--local switch_defaults = require "st.zigbee.defaults.switch_defaults"
local LAST_KELVIN_SET = "last_kelvin_set"
local CONVERSION_CONSTANT = 1000000

-- driver local modules load
local dimmer = require "dimmer"
local mirror_groups = require "mirror-groups"

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
--local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]
local forced_On_Level = capabilities["legendabsolute60149.forcedOnLevel"]
local mirror_Group_Function = capabilities["legendabsolute60149.mirrorGroupFunction"]
local effects_Set_Command = capabilities["legendabsolute60149.effectsSetCommand"]
local hue_Steps = capabilities["legendabsolute60149.hueSteps"]

--- switch_level_handler
local function switch_level_handler(self,device,command)
  if device.preferences.logDebugPrint == true then
    print("handler_Level >>>>>>>>>>>>>>",command.args.level)
  end
  local on_Level = command.args.level
  if on_Level < device.preferences.setLevelMin then on_Level = device.preferences.setLevelMin end
  if on_Level == 0 then 
   device:set_field("last_Level", 1, {persist = false})
  else
    device:set_field("last_Level", on_Level, {persist = false})
  end

    if device.preferences.levelTransTime == 0 then
      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
      if device:get_manufacturer() == "_TZ3210_dxroobu3" or device:get_manufacturer() =="_TZ3210_09hzmirw" then
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
      end
    else
      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), math.floor(device.preferences.levelTransTime * 10))
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), math.floor((device.preferences.levelTransTime * 10))))
      if device:get_manufacturer() == "_TZ3210_dxroobu3" or device:get_manufacturer() =="_TZ3210_09hzmirw" then
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), math.floor((device.preferences.levelTransTime * 10))))
      end
    end

  if on_Level > 0 and device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
    device:send(zcl_clusters.OnOff.server.commands.On(device))
    local on_off_read = function(d)
      if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
        device:send_to_component(command.component,zcl_clusters.OnOff.attributes.OnOff:read(device))
      end
    end
    device.thread:call_with_delay(device.preferences.onTransTime + 2, on_off_read, "on-off delayed read")
  end
  
  local level_read = function(d)
    local level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
    if math.abs(level - on_Level) > 1 then
      device:send_to_component(command.component, zcl_clusters.Level.attributes.CurrentLevel:read(device))
    end
  end
  device.thread:call_with_delay(device.preferences.levelTransTime + 2, level_read, "setLevel delayed read")
end

---color_Temperature_handler
local function set_color_Temperature_handler(self,device,command)
  if device.preferences.logDebugPrint == true then
    print("handler_Color Temp >>>>>>>>>>>>>>",command.args.temperature)
  end
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

  device:send(zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds,math.floor((device.preferences.tempTransTime * 10))))

  if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
    local last_Level = device:get_field("last_Level")
    if last_Level == nil then 
      last_Level = 100
      device:set_field("last_Level", 100, {persist = false})
    end

    if device.preferences.levelTransTime == 0 then
      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(last_Level/100.0 * 254), 0xFFFF)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), 0xFFFF))
    else
      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(last_Level/100.0 * 254), device.preferences.levelTransTime * 10)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), math.floor((device.preferences.levelTransTime * 10))))
    end
    if last_Level > 0 then
      device:send(zcl_clusters.OnOff.server.commands.On(device))
      local on_off_read = function(d)
        if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
          device:send_to_component(command.component,zcl_clusters.OnOff.attributes.OnOff:read(device))
          device:send_to_component(command.component, zcl_clusters.Level.attributes.CurrentLevel:read(device))
        end
      end
      device.thread:call_with_delay(device.preferences.onTransTime + 2, on_off_read, "on-off delayed read")
    end
    --device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds,math.floor((device.preferences.tempTransTime * 10))))
  end
  local color_temp_read = function(d)
    local current_colorTemp = device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME)
    if math.abs(current_colorTemp - colorTemp) > 20 then
      device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
    end
  end
  device.thread:call_with_delay(device.preferences.tempTransTime + 2, color_temp_read, "setColorTemp delayed read")

end

 ----Level emit event
local function level_attr_handler(driver, device, value, zb_rx)
  if device.preferences.logDebugPrint == true then
    print("<<<< emit Level >>>>")
  end

  local level = math.floor((value.value / 254.0 * 100) + 0.5)
  --device:set_field("last_Level", level, {persist = false}) --no volver a poner esto

  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.switchLevel.level(level))

  -- emit event in child device
  local child_device = device:get_child_by_parent_assigned_key("main")
  if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
    child_device:emit_event(capabilities.switchLevel.level(level))
  end
end

 ----- Groups_handler
local function Groups_handler(driver, device, value, zb_rx)

  local zb_message = value
  local group_list = zb_message.body.zcl_body.group_list_list
  --Print table group_lists with function utils.stringify_table(group_list)
  print("group_list >>>>>>",utils.stringify_table(group_list))
  
  local group_Names =""
  for i, value in pairs(group_list) do
    if device.preferences.logDebugPrint == true then
      print("Message >>>>>>>>>>>",group_list[i].value)
    end
    group_Names = group_Names..tostring(group_list[i].value).."-"
  end
  -- local text_Groups = "Groups Added: "..group_Names
  local text_Groups = group_Names
  if text_Groups == "" then text_Groups = "DeleteAllGroups" end
  if device.preferences.logDebugPrint == true then
    print (text_Groups)
  end
  device:emit_event(get_Groups.getGroups(text_Groups))
end

----- delete_all_groups_handler
local function delete_all_groups_handler(self, device, command)
  device:send(Groups.server.commands.RemoveAllGroups(device, {}))
  device:send(Groups.server.commands.GetGroupMembership(device, {}))
end

---- color_temperature_handler
local function color_temperature_handler(driver, device, value, zb_rx)
  if device.preferences.logDebugPrint == true then
    print("<< Emit Color temp >>")
  end
  if device:supports_capability_by_id(capabilities.colorTemperature.ID) then
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
      --print("Corrected temp_in_kelvin >>>>>", temp_in_kelvin)
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

    -- emit event in child device
    local child_device = device:get_child_by_parent_assigned_key("main")
    if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
      child_device:emit_event( capabilities.colorTemperature.colorTemperature(temp_in_kelvin))
    end
  end
end

---color_hue_handler
local function color_hue_handler(driver, device, value, zb_rx)
  if device:get_field("colorChanging") =="Active" then return end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.colorControl.hue(math.floor(value.value / 0xFE * 100)))

  -- emit event in child device
  local child_device = device:get_child_by_parent_assigned_key("main")
  if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
    child_device:emit_event(capabilities.colorControl.hue(math.floor(value.value / 0xFE * 100)))
  end
end

---  color_Saturation_handler
local function  color_Saturation_handler(driver, device, value, zb_rx)
  if device:get_field("colorChanging") =="Active" then return end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.colorControl.saturation(math.floor(value.value / 0xFE * 100)))

  -- emit event in child device
  local child_device = device:get_child_by_parent_assigned_key("main")
  if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
    child_device:emit_event(capabilities.colorControl.saturation(math.floor(value.value / 0xFE * 100)))
  end
end

-- forced_On_Level_handler
local function forced_On_Level_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< forced_On_Level_handler:", command.args.value)
  end
  local forced_Level = command.args.value
  device:set_field("forced_Level", forced_Level, {persist = false})
  device:emit_event(forced_On_Level.forcedOnLevel(forced_Level))
    
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    if device:get_field("mirror_group_function") == "Active" then
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:get_field("mirror_group_function") == "Active" and
            device.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
              dev:set_field("forced_Level", forced_Level, {persist = false})
              dev:emit_event(forced_On_Level.forcedOnLevel(forced_Level))
          end
        else
          if dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
              dev:set_field("forced_Level", forced_Level, {persist = false})
              dev:emit_event(forced_On_Level.forcedOnLevel(forced_Level))
          end
        end
      end
    end
  end

end

-- device do_configure
local function do_Configure(driver, device)
  -- Configure OnOff interval report
  local interval =  device.preferences.onOffReports
  if  device.preferences.onOffReports == nil then interval = 300 end
  local config ={
    cluster = zcl_clusters.OnOff.ID,
    attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
    minimum_interval = 0,
    maximum_interval = interval,
    data_type = zcl_clusters.OnOff.attributes.OnOff.base_type
  }
  --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, device.preferences.onOffReports))
  device:add_configured_attribute(config)
  device:add_monitored_attribute(config)
  device:configure()
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
end

--driver_Switched set profile selected
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

  --dimmer.do_init (driver, device)
  --dimmer.do_Preferences(driver, device)
  --do_Configure(driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is not Child device)
    device.thread:call_with_delay(2, function(d) -- 23/12/23
      do_Configure(driver, device)
    end, "configure")
  end
end

-- do added
local function do_added(driver,device)
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    print("Adding EDGE:CHILD device...")

    if device:get_field("mirror_group_function") == nil then
      device:set_field("mirror_group_function", "Inactive", {persist = false})
    end

    device:emit_event(mirror_Group_Function.mirrorGroupFunction(device:get_field("mirror_group_function")))

    local value = device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME)
    if value == nil or value == "off" then
      device:emit_event(capabilities.switch.switch.off())
    else
      device:emit_event(capabilities.switch.switch.off())
    end

    local level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
    if level == nil then level = 100 end
    device:emit_event(capabilities.switchLevel.level(level))

    local colorTemp = device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME)
    if colorTemp == nil then colorTemp = 4000 end
    colorTemp = math.floor(utils.round(colorTemp))
    device:emit_event(capabilities.colorTemperature.colorTemperature(colorTemp))

    local sat = device:get_latest_state("main", capabilities.colorControl.ID, capabilities.colorControl.saturation.NAME)
    local hue = device:get_latest_state("main", capabilities.colorControl.ID, capabilities.colorControl.hue.NAME)
    if sat == nil then sat = 100 end
    if hue == nil then hue = 100 end
    device:emit_event(capabilities.colorControl.saturation(sat))
    device:emit_event(capabilities.colorControl.hue(hue))

  else
    device:refresh()
    --dimmer.do_Preferences (driver, device)
  end
  --dimmer.do_Preferences (driver, device)
end

local function group_switch_level_handler(driver, device, command)
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    local level = command.args.level
    if level == 0 then level = 1 end
    device:emit_event(capabilities.switchLevel.level(level))
    if level > 1 then 
      device:emit_event(capabilities.switch.switch.on())
    else
      device:emit_event(capabilities.switch.switch.off())
    end
    if device:get_field("mirror_group_function") == "Active" then
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:get_field("mirror_group_function") == "Active" and
            dev:supports_capability_by_id(capabilities.switchLevel.ID) and
            device.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
              switch_level_handler(driver,dev,command)
          end 
        end
      end
    end
  else
    switch_level_handler(driver,device,command)
  end
end

local function group_set_color_Temperature_handler(driver, device, command)
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    local colorTemp = command.args.temperature
    device:emit_event(capabilities.colorTemperature.colorTemperature(colorTemp))
    device:emit_event(capabilities.switch.switch.on())
    if device:get_field("mirror_group_function") == "Active" then
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:get_field("mirror_group_function") == "Active" and
            dev:supports_capability_by_id(capabilities.colorTemperature.ID) and
            device.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
              set_color_Temperature_handler(driver,dev,command)
          end 
        end
      end
    end
  else
    set_color_Temperature_handler(driver,device,command)
  end
end

local function group_color_control_handler(driver, device, command)
  print("<<<< group_set_color_handler in Main driver >>>>")
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    local hue = math.floor((command.args.color.hue))
    local sat = math.floor((command.args.color.saturation))
    device:emit_event(capabilities.colorControl.saturation(sat))
    device:emit_event(capabilities.colorControl.hue(hue))
    device:emit_event(capabilities.switch.switch.on())
    if device:get_field("mirror_group_function") == "Active" then
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:get_field("mirror_group_function") == "Active" and
            dev:supports_capability_by_id(capabilities.colorControl.ID) and
            device.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
              --print("dev:get_field(zll_xy)", dev:get_field("zll_xy"))
              if dev:get_field("zll_xy") == "yes" then
                mirror_groups.set_color_handler(driver, dev, command)
              elseif dev:get_field("zll_xy") == "no" then
                mirror_groups.color_control_handler(driver,dev,command)
              end
          end 
        end
      end
    end
  else
    --color_control_handler(driver,device,command)
    mirror_groups.color_control_handler(driver,device,command)
  end
end

-----  driver template configuration -----
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
    driverSwitched = driver_Switched,
    added = do_added,
    doConfigure = do_Configure
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      --[capabilities.switch.commands.on.NAME] = dimmer.on_handler,
      --[capabilities.switch.commands.off.NAME] = dimmer.off_handler
      [capabilities.switch.commands.on.NAME] = mirror_groups.on_handler,
      [capabilities.switch.commands.off.NAME] = mirror_groups.off_handler
    },
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = group_switch_level_handler
    },
    [capabilities.colorTemperature.ID] = {
      [capabilities.colorTemperature.commands.setColorTemperature.NAME] =group_set_color_Temperature_handler
    },
    [capabilities.colorControl.ID] = {
      [capabilities.colorControl.commands.setColor.NAME] = group_color_control_handler
    },
    [random_On_Off.ID] = {
      [random_On_Off.commands.setRandomOnOff.NAME] = mirror_groups.random_on_off_handler,
    },
    [level_Steps.ID] = {
      [level_Steps.commands.setLevelSteps.ID] = mirror_groups.level_Steps_handler,
    },
    [color_Temperature_Steps.ID] = {
      [color_Temperature_Steps.commands.setColorTempSteps.ID] = mirror_groups.color_Temperature_Steps_handler,
    },
    [prog_On.ID] = {
      [prog_On.commands.setProgOn.NAME] = mirror_groups.prog_On_handler,
    },
    [prog_Off.ID] = {
      [prog_Off.commands.setProgOff.NAME] = mirror_groups.prog_Off_handler,
    },
    [circadian_Light.ID] = {
      [circadian_Light.commands.setCircadian.NAME] = mirror_groups.circadian_Light_handler,
    },
    [color_Changing.ID] = {
      [color_Changing.commands.setColorChanging.NAME] = mirror_groups.color_Changing_handler,
    },
    [color_Change_Timer.ID] = {
      [color_Change_Timer.commands.setColorChangeTimer.NAME] = mirror_groups.color_Change_Timer_handler,
    },
    [color_Change_Mode.ID] = {
      [color_Change_Mode.commands.setColorChangeMode.NAME] = mirror_groups.color_Change_Mode_handler,
    },
    [get_Groups.ID] = {
      [get_Groups.commands.setGetGroups.NAME] = delete_all_groups_handler,
    },
    [forced_On_Level.ID] = {
      [forced_On_Level.commands.setForcedOnLevel.NAME] = forced_On_Level_handler,
    },
    [mirror_Group_Function.ID] = {
      [mirror_Group_Function.commands.setMirrorGroupFunction.NAME] = mirror_groups.mirror_Group_Function_handler,
    },
    [effects_Set_Command.ID] = {
      [effects_Set_Command.commands.setEffectsSetCommand.NAME] = mirror_groups.effects_Set_Command_handler,
    },
    [hue_Steps.ID] = {
      [hue_Steps.commands.setHueSteps.NAME] = mirror_groups.hue_Steps_handler,
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
        [zcl_clusters.OnOff.attributes.OnOff.ID] = dimmer.on_off_attr_handler
      },
      [LevelControlCluster.ID] = {
        [LevelControlCluster.attributes.CurrentLevel.ID] = level_attr_handler
      },
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
  health_check = false
}
-- run driver
defaults.register_for_default_handlers(zigbee_bulb_driver_template, zigbee_bulb_driver_template.supported_capabilities)
local zigbee_bulb = ZigbeeDriver("zigbee_light_multifunctions", zigbee_bulb_driver_template)
zigbee_bulb:run()