------- command handlred for mirror groups----
---- M. Colmenarejo 2023

local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local dimmer =require "dimmer"
local utils = require "st.utils"
local utils_xy = require "utils-xy-lidl"

local ColorControl = zcl_clusters.ColorControl

local CURRENT_X = "current_x_value" -- y value from xyY color space
local CURRENT_Y = "current_y_value" -- x value from xyY color space
local Y_TRISTIMULUS_VALUE = "y_tristimulus_value" -- Y tristimulus value which is used to convert color xyY -> RGB -> HSV

local level_Steps = capabilities["legendabsolute60149.levelSteps"]
local color_Temperature_Steps = capabilities["legendabsolute60149.colorTemperatureSteps"]
local mirror_Group_Function = capabilities["legendabsolute60149.mirrorGroupFunction"]
local effects_Set_Command = capabilities["legendabsolute60149.effectsSetCommand"]
local random_On_Off = capabilities["legendabsolute60149.randomOnOff1"]
local prog_On = capabilities["legendabsolute60149.progressiveOn1"]
local prog_Off = capabilities["legendabsolute60149.progressiveOff1"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep"]
local circadian_Light = capabilities["legendabsolute60149.circadian"]
local color_Changing = capabilities["legendabsolute60149.colorChanging"]
local color_Change_Timer = capabilities["legendabsolute60149.colorChangeTimer"]
local color_Change_Mode = capabilities["legendabsolute60149.colorChangeMode1"]
--local driver_Version = capabilities["legendabsolute60149.driverVersion1"]
local forced_On_Level = capabilities["legendabsolute60149.forcedOnLevel"]

local mirror_groups ={}


-- read atributtes for level colot Temp and color
local function attributes_read(self,device,command)
  local color_read = function(d)
    device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.CurrentHue:read(device))
    device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.CurrentSaturation:read(device))
  end
  local level_read = function(d)
    device:send_to_component(command.component, zcl_clusters.Level.attributes.CurrentLevel:read(device))
    device:send_to_component(command.component,zcl_clusters.OnOff.attributes.OnOff:read(device))
  end
  if device.preferences.levelTransTime ~= nil then
    device.thread:call_with_delay(device.preferences.levelTransTime + 1, level_read, "setLevel delayed read")
  end
  if device.preferences.colorTransTime ~= nil then
    device.thread:call_with_delay(device.preferences.colorTransTime + 2, color_read, "setColor delayed read")
  end
end

-- On handler
function mirror_groups.on_handler(driver, device, command)
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:emit_event(capabilities.switch.switch.on())
    local parent_device = device:get_parent_device()
    if parent_device:get_field("last_Level") == nil or parent_device:get_field("last_Level") <= 1 then parent_device:set_field("last_Level", parent_device.preferences.onLevelEnd, {persist = true}) end
    if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) <= 1 then
      device:emit_event(capabilities.switchLevel.level(math.floor((parent_device:get_field("last_Level")))))
    end
    if device:get_field("mirror_group_function") == "Active" then
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:get_field("mirror_group_function") == "Active" and
            device.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
              if device.preferences.logDebugPrint == true then
                print("<<<<<<<< mirror_groups.on_handler")
              end
              dimmer.on_handler (driver, dev, command)
          end 
        end
      end
    end
  else
    dimmer.on_handler (driver, device, command)
  end
end

-- Off handler
function mirror_groups.off_handler(driver, device, command)
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:emit_event(capabilities.switch.switch.off())
    if device:get_field("mirror_group_function") == "Active" then
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:get_field("mirror_group_function") == "Active" and
            device.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
              dimmer.off_handler (driver, dev, command)
          end
        end
      end
    end
  else
    dimmer.off_handler(driver, device, command)
  end
end

-------- color_control_handler sat and hue --------------
function mirror_groups.color_control_handler(self,device,command)
  if device.preferences.logDebugPrint == true then
    print("<<<<<<< color_control_handler >>>>>>")
  end
  local hue = math.floor((command.args.color.hue * 0xFE) / 100.0 + 0.5)
  local sat = math.floor((command.args.color.saturation * 0xFE) / 100.0 + 0.5)
  device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToHueAndSaturation(device, hue, sat, math.floor(device.preferences.colorTransTime * 10)))

  if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
    local last_Level = device:get_field("last_Level")
    if last_Level == nil then 
      last_Level = 100
      device:set_field("last_Level", 100, {persist = true})
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
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), math.floor(device.preferences.levelTransTime * 10)))
    end

    if last_Level == 0 then last_Level = 1 end
    device:send(zcl_clusters.OnOff.server.commands.On(device))

    attributes_read(self,device,command)
  else
    local color_read = function(d)
      device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.CurrentHue:read(device))
      device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.CurrentSaturation:read(device))
    end
    device.thread:call_with_delay(device.preferences.colorTransTime + 2, color_read, "setColor delayed read")
  end
end

-------------------- X,Y Color Handler -----------------------------
-- move to last level stored
local function move_to_last_level(driver, device, cmd)
  if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
    local last_Level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
    if last_Level == nil then 
      last_Level = 100
      device:set_field("last_Level", 100, {persist = true})
    end
    if last_Level < 1 then last_Level = 1 end
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
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(last_Level/100.0 * 254), (device.preferences.levelTransTime * 10)))
    end
    device:send(zcl_clusters.OnOff.server.commands.On(device))
    local level_read = function(d)
      device:send_to_component(cmd.component, zcl_clusters.Level.attributes.CurrentLevel:read(device))
      device:send_to_component(cmd.component, zcl_clusters.OnOff.attributes.OnOff:read(device))
    end
    if device.preferences.levelTransTime ~= nil then
      device.thread:call_with_delay(device.preferences.levelTransTime + 1.5, level_read, "setLevel delayed read")
    end
  end
end

local function store_xyY_values(device, x, y, Y)
  device:set_field(Y_TRISTIMULUS_VALUE, Y)
  device:set_field(CURRENT_X, x)
  device:set_field(CURRENT_Y, y)
end

local query_device = function(device)
  return function()
    device:send(ColorControl.attributes.CurrentX:read(device))
    device:send(ColorControl.attributes.CurrentY:read(device))
  end
end

function mirror_groups.set_color_handler(driver, device, cmd)
  if device.preferences.logDebugPrint == true then
    print("<<<< set_color_handler XY >>>>")
  end
  local hue = cmd.args.color.hue > 99 and 99 or cmd.args.color.hue
  local sat = cmd.args.color.saturation
  local x, y, Y = 0,0,0
  if device:get_manufacturer()=="IKEA of Sweden" then
   x, y, Y = utils.safe_hsv_to_xy(hue, sat)
  else
    x, y, Y = utils_xy.safe_hsv_to_xy(hue, sat)
  end
  store_xyY_values(device, x, y, Y)

  if device.preferences.logDebugPrint == true then
    print(">>>>> CURRENT_X=",x)
    print(">>>>> CURRENT_Y=",y)
    print(">>>>> Y_TRISTIMULUS_VALUE=",Y)
  end

  --switch_defaults.on(driver,device,cmd)
  --move_to_last_level(driver, device, cmd)
  device:send(ColorControl.commands.MoveToColor(device, x, y, device.preferences.colorTransTime * 10))
  move_to_last_level(driver, device, cmd)

  device.thread:call_with_delay(2, query_device(device))
end

--- level_Steps_handler
function mirror_groups.level_Steps_handler(driver, device, command)
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    local level = command.args.value
    device:emit_event(level_Steps.levelSteps(level))
    level = math.floor(level + device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))

    if level < 0 then 
      level = 0 
    elseif level > 100 then
      level = 100
    end

    device:emit_event(capabilities.switchLevel.level(level))
    if level > 0 then 
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
              dimmer.level_Steps_handler(driver, dev, command)
          end 
        end
      end
    end
  else
    dimmer.level_Steps_handler(driver, device, command)
  end
end

--- color_Temperature_Steps_handle
function mirror_groups.color_Temperature_Steps_handler(driver, device, command)
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    local colorTemp = command.args.value
    device:emit_event(color_Temperature_Steps.colorTempSteps(colorTemp))
    colorTemp = math.floor(utils.round(colorTemp + device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME)))
    device:emit_event(capabilities.colorTemperature.colorTemperature(colorTemp))
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
      device:emit_event(capabilities.switch.switch.on())
    end
    if device:get_field("mirror_group_function") == "Active" then
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:get_field("mirror_group_function") == "Active" and
            dev:supports_capability_by_id(capabilities.colorTemperature.ID) and
            device.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
              dimmer.color_Temperature_Steps_handler(driver, dev, command)
          end 
        end
      end
    end
  else
    dimmer.color_Temperature_Steps_handler(driver, device, command)
  end
end

---mirror_Group_Function_handler
function mirror_groups.mirror_Group_Function_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< mirror_Group_Function_handler:", command.args.value)
  end
  local mirror_group_function = command.args.value
  device:set_field("mirror_group_function", mirror_group_function, {persist = true})

  device:emit_event(mirror_Group_Function.mirrorGroupFunction(mirror_group_function))
end

---- effects_Set_Command_handler
function mirror_groups.effects_Set_Command_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< effects_Set_Command_handler:", command.args.value)
  end

  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    local effects_set_command = command.args.value
    device:set_field("effects_set_command", effects_set_command, {persist = true})
    device:emit_event(effects_Set_Command.effectsSetCommand(effects_set_command))
    device:emit_event(capabilities.switch.switch.on())
      if device:get_field("mirror_group_function") == "Active" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
                dimmer.effects_Set_handler(driver, dev, command)
            end 
          end
        end
      end
  else
    dimmer.effects_Set_handler(driver, device, command)
  end
end

---- random_on_off_handler
function mirror_groups.random_on_off_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< random_on_off_handler:", command.args.value)
  end

  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    local random_state = command.args.value
    device:emit_event(random_On_Off.randomOnOff(random_state))
    device:set_field("random_state", random_state, {persist = true})

    -- Inctive incompatibles functions
    device:set_field("progOn[device]", "Inactive", {persist = true})
    device:emit_event(prog_On.progOn("Inactive"))
    device:set_field("progOff[device]", "Inactive", {persist = true})
    device:emit_event(prog_Off.progOff("Inactive"))
    device:emit_event(circadian_Light.circadian("Inactive"))
    device:set_field("circadian[device]", "Inactive", {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})

      if device:get_field("mirror_group_function") == "Active" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
                dimmer.random_on_off_handler(driver, dev, command)
            end 
          end
        end
      end
  else
    dimmer.random_on_off_handler(driver, device, command)
  end
end

---- prog_On_handler
function mirror_groups.prog_On_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< prog_On_handler:", command.args.value)
  end
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    --local prog_On = command.args.value
    device:set_field("progOn[device]", command.args.value, {persist = true})
    device:emit_event(prog_On.progOn(command.args.value))

    -- Inctive incompatibles functions
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:set_field("random_state", "Inactive", {persist = true})
    device:emit_event(circadian_Light.circadian("Inactive"))
    device:set_field("circadian[device]", "Inactive", {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})

      if device:get_field("mirror_group_function") == "Active" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
                dimmer.prog_On_handler(driver, dev, command)
            end
          end
        end
      end
  else
    dimmer.prog_On_handler(driver, device, command)
  end
end

---- prog_Off_handler
function mirror_groups.prog_Off_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< prog_Off_handler:", command.args.value)
  end
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:set_field("progOff[device]", command.args.value, {persist = true})
    device:emit_event(prog_Off.progOff(command.args.value))

    -- Inctive incompatibles functions
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:set_field("random_state", "Inactive", {persist = true})
    device:emit_event(circadian_Light.circadian("Inactive"))
    device:set_field("circadian[device]", "Inactive", {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})

      if device:get_field("mirror_group_function") == "Active" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
                dimmer.prog_Off_handler(driver, dev, command)
            end
          end
        end
      end
  else
    dimmer.prog_Off_handler(driver, device, command)
  end
end

---- circadian_Light_handler
function mirror_groups.circadian_Light_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< circadian_Light_handler:", command.args.value)
  end
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:emit_event(circadian_Light.circadian(command.args.value))
    device:set_field("circadian[device]", command.args.value, {persist = true})

    -- Inctive incompatibles functions
    device:set_field("progOn[device]", "Inactive", {persist = true})
    device:emit_event(prog_On.progOn("Inactive"))
    device:set_field("progOff[device]", "Inactive", {persist = true})
    device:emit_event(prog_Off.progOff("Inactive"))
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:set_field("random_state", "Inactive", {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})

      if device:get_field("mirror_group_function") == "Active" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              dev:supports_capability_by_id(capabilities.colorTemperature.ID) and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
                dimmer.circadian_Light_handler(driver, dev, command)
            end
          end
        end
      end
  else
    dimmer.circadian_Light_handler(driver, device, command)
  end
end

---- color_Changing_handler
function mirror_groups.color_Changing_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< color_Changing_handler:", command.args.value)
  end
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:set_field("colorChanging", command.args.value, {persist = true})
    device:emit_event(color_Changing.colorChanging(command.args.value))

    -- Inctive incompatibles functions
    device:set_field("progOn[device]", "Inactive", {persist = true})
    device:emit_event(prog_On.progOn("Inactive"))
    device:set_field("progOff[device]", "Inactive", {persist = true})
    device:emit_event(prog_Off.progOff("Inactive"))
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:set_field("random_state", "Inactive", {persist = true})
    device:emit_event(circadian_Light.circadian("Inactive"))
    device:set_field("circadian[device]", "Inactive", {persist = true})

      if device:get_field("mirror_group_function") == "Active" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              dev:supports_capability_by_id(capabilities.colorControl.ID) and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
                dimmer.color_Changing_handler(driver, dev, command)
            end
          end
        end
      end
  else
    dimmer.color_Changing_handler(driver, device, command)
  end
end

---- color_Change_Timer_handler
function mirror_groups.color_Change_Timer_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< color_Change_Timer_handler:", command.args.value)
  end
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:set_field("colorTimer", command.args.value, {persist = true})
    device:emit_event(color_Change_Timer.colorChangeTimer(command.args.value))

      if device:get_field("mirror_group_function") == "Active" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              dev:supports_capability_by_id(capabilities.colorControl.ID) and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
                dimmer.color_Change_Timer_handler(driver, dev, command)
            end
          end
        end
      end
  else
    dimmer.color_Change_Timer_handler(driver, device, command)
  end
end

---- color_Change_Mode_handler
function mirror_groups.color_Change_Mode_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<< color_Change_Mode_handler:", command.args.value)
  end
  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    device:set_field("colorChangeModeList", command.args.value, {persist = true})
  device:emit_event(color_Change_Mode.colorChangeMode(command.args.value))

      if device:get_field("mirror_group_function") == "Active" then
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              dev:supports_capability_by_id(capabilities.colorControl.ID) and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
                dimmer.color_Change_Mode_handler(driver, dev, command)
            end
          end
        end
      end
  else
    dimmer.color_Change_Mode_handler(driver, device, command)
  end
end

return mirror_groups