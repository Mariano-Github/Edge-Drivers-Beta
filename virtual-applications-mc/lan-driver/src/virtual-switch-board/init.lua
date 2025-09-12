--- M. Colmenarejo 2024
--- Smartthings library load ---
local capabilities = require "st.capabilities"
local log = require "log"
--local utils = require "st.utils"

local command_handlers = require "command_handlers"

-- Custom Capability Randon On Off
local name_Switch1 = capabilities["legendabsolute60149.nameSwitch1"]
local name_Switch2 = capabilities["legendabsolute60149.nameSwitch2"]
local name_Switch3 = capabilities["legendabsolute60149.nameSwitch3"]
local name_Switch4 = capabilities["legendabsolute60149.nameSwitch4"]
local name_Switch5 = capabilities["legendabsolute60149.nameSwitch5"]
local switchBoard_Type = capabilities["legendabsolute60149.switchBoardType"]
--local switchBoard_Status = capabilities["legendabsolute60149.switchBoardStatus"]

local can_handle = function(opts, driver, device)
  if device.preferences.switchNumber > 1 and  device.preferences.switchNumber < 6 then
    local subdriver = require("virtual-switch-board")
    return true, subdriver
  else
    return false
  end  
end

-- refresh handler
local function device_refresh(driver, device, command)
  local board_status = "Any Switch On"
  if device.preferences.switchNumber == 2 then
    if device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and 
      device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        board_status = "All Switch Off"
    end
      device.profile.components["switch-1"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME)))
      device.profile.components["switch-2"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME)))
      device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne(device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME)))
      device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo(device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME)))
      device:emit_event(switchBoard_Type.switchBoardType({value = device:get_latest_state("main", switchBoard_Type.ID, switchBoard_Type.switchBoardType.NAME)}, {visibility = {displayed = false }}))

  elseif device.preferences.switchNumber == 3 then
    if device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and 
      device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and
      device:get_latest_state("switch-3", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        board_status = "All Switch Off"
    end
    device.profile.components["switch-1"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-2"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-3"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-3", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne(device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME)))
    device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo(device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME)))
    device.profile.components["switch-3"]:emit_event(name_Switch3.nameSwitchThree(device:get_latest_state("switch-3", name_Switch3.ID, name_Switch3.nameSwitchThree.NAME)))
    device:emit_event(switchBoard_Type.switchBoardType({value = device:get_latest_state("main", switchBoard_Type.ID, switchBoard_Type.switchBoardType.NAME)}, {visibility = {displayed = false }}))
  
  elseif device.preferences.switchNumber == 4 then
    if device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and 
      device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and
      device:get_latest_state("switch-3", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and
      device:get_latest_state("switch-4", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        board_status = "All Switch Off"
    end
    device.profile.components["switch-1"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-2"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-3"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-3", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-4"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-4", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne(device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME)))
    device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo(device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME)))
    device.profile.components["switch-3"]:emit_event(name_Switch3.nameSwitchThree(device:get_latest_state("switch-3", name_Switch3.ID, name_Switch3.nameSwitchThree.NAME)))
    device.profile.components["switch-4"]:emit_event(name_Switch4.nameSwitchFour( device:get_latest_state("switch-4", name_Switch4.ID, name_Switch4.nameSwitchFour.NAME)))
    device:emit_event(switchBoard_Type.switchBoardType({value = device:get_latest_state("main", switchBoard_Type.ID, switchBoard_Type.switchBoardType.NAME)}, {visibility = {displayed = false }}))

  elseif device.preferences.switchNumber == 5 then
    if device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and 
      device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and
      device:get_latest_state("switch-3", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and
      device:get_latest_state("switch-4", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" and
      device:get_latest_state("switch-5", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        board_status = "All Switch Off"
    end
    device.profile.components["switch-1"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-2"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-3"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-3", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-4"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-4", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-5"]:emit_event(capabilities.switch.switch(device:get_latest_state("switch-5", capabilities.switch.ID, capabilities.switch.switch.NAME)))
    device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne(device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME)))
    device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo(device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME)))
    device.profile.components["switch-3"]:emit_event(name_Switch3.nameSwitchThree(device:get_latest_state("switch-3", name_Switch3.ID, name_Switch3.nameSwitchThree.NAME)))
    device.profile.components["switch-4"]:emit_event(name_Switch4.nameSwitchFour(device:get_latest_state("switch-4", name_Switch4.ID, name_Switch4.nameSwitchFour.NAME)))
    device.profile.components["switch-5"]:emit_event(name_Switch5.nameSwitchFive(device:get_latest_state("switch-5", name_Switch5.ID, name_Switch5.nameSwitchFive.NAME)))
    device:emit_event(switchBoard_Type.switchBoardType({value = device:get_latest_state("main", switchBoard_Type.ID, switchBoard_Type.switchBoardType.NAME)}, {visibility = {displayed = false }}))
  end

  if device.preferences.switchNumber > 1 and device.preferences.switchNumber < 6 then
    command_handlers.set_switchBoard_status (device, 0)
  end
end

-- added and refresh device
local function device_added(driver, device,command)
  log.info("[" .. device.id .. "] Adding new Virtual Device")
  --device.thread:call_with_delay(3, 
  --function()
    if device.preferences.switchNumber == 2 then
      device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
      if device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME) == nil then
        device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne("Enter name of Switch-1"))
      end
      if device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME) == nil then
        device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo("Enter name of Switch-2"))
      end
    elseif device.preferences.switchNumber == 3 then
      device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
      if device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME) == nil then
        device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne("Enter name of Switch-1"))
      end
      if device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME) == nil then
        device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo("Enter name of Switch-2"))
      end
      if device:get_latest_state("switch-3", name_Switch3.ID, name_Switch3.nameSwitchThree.NAME) == nil then
        device.profile.components["switch-3"]:emit_event(name_Switch3.nameSwitchThree("Enter name of Switch-3"))
      end
    elseif device.preferences.switchNumber == 4 then
      device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
      if device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME) == nil then
        device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne("Enter name of Switch-1"))
      end
      if device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME) == nil then
        device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo("Enter name of Switch-2"))
      end
      if device:get_latest_state("switch-3", name_Switch3.ID, name_Switch3.nameSwitchThree.NAME) == nil then
        device.profile.components["switch-3"]:emit_event(name_Switch3.nameSwitchThree("Enter name of Switch-3"))
      end
      if device:get_latest_state("switch-4", name_Switch4.ID, name_Switch4.nameSwitchFour.NAME) == nil then
        device.profile.components["switch-4"]:emit_event(name_Switch4.nameSwitchFour("Enter name of Switch-4"))
      end
    elseif device.preferences.switchNumber == 5 then
      device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
      device.profile.components["switch-5"]:emit_event(capabilities.switch.switch.off())
      if device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME) == nil then
        device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne("Enter name of Switch-1"))
      end
      if device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME) == nil then
        device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo("Enter name of Switch-2"))
      end
      if device:get_latest_state("switch-3", name_Switch3.ID, name_Switch3.nameSwitchThree.NAME) == nil then
        device.profile.components["switch-3"]:emit_event(name_Switch3.nameSwitchThree("Enter name of Switch-3"))
      end
      if device:get_latest_state("switch-4", name_Switch4.ID, name_Switch4.nameSwitchFour.NAME) == nil then
        device.profile.components["switch-4"]:emit_event(name_Switch4.nameSwitchFour("Enter name of Switch-4"))
      end
      if device:get_latest_state("switch-5", name_Switch5.ID, name_Switch5.nameSwitchFive.NAME) == nil then
        device.profile.components["switch-5"]:emit_event(name_Switch5.nameSwitchFive("Enter name of Switch-5"))
      end
    end
  --end)
end

local function device_init(driver, device) 
  log.info("[" .. device.id .. "] Initializing Virtual Device")

  -- mark device as online so it can be controlled from the app
  device:online()

  -- provisioning_state = "PROVISIONED"
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })

  device:try_update_metadata({profile = "switchboard-" .. device.preferences.switchNumber})

  if device.model ~= "Virtual Switchboard-".. device.preferences.switchNumber then
    device:try_update_metadata({ model = "Virtual Switchboard-" .. device.preferences.switchNumber})
    device.thread:call_with_delay(5, function() 
      print("<<<<< model= ", device.model)
    end)
  end

  local switch_Board = device.preferences.switchNumber .. " Independent Switches"
  if device.preferences.switchBoardType == "MaxOneSwitchOn" then
    switch_Board = device.preferences.switchNumber .. " Switches- Max 1 Switch On"
  end
  device:emit_event(switchBoard_Type.switchBoardType({value = switch_Board}, {visibility = {displayed = false }}))

  device.thread:call_with_delay(2, function() device_refresh(driver, device) end)
end


local virtual_switch_board = {
	NAME = "virtual switch board",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_refresh,
    },
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
  },

  can_handle = can_handle
}
return virtual_switch_board