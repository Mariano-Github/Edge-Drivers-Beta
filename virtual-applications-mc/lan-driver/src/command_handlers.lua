--local log = require "log"
local capabilities = require "st.capabilities"

local mirror_In = capabilities["legendabsolute60149.mirrorIn"]
local mirror_Out = capabilities["legendabsolute60149.mirrorOut"]
local name_Switch1 = capabilities["legendabsolute60149.nameSwitch1"]
local name_Switch2 = capabilities["legendabsolute60149.nameSwitch2"]
local name_Switch3 = capabilities["legendabsolute60149.nameSwitch3"]
local name_Switch4 = capabilities["legendabsolute60149.nameSwitch4"]
local name_Switch5 = capabilities["legendabsolute60149.nameSwitch5"]
local switchBoard_Status = capabilities["legendabsolute60149.switchBoardStatus"]

local command_handlers = {}

-- set SwitchBoard board_status
function command_handlers.set_switchBoard_status (device, command)
  --local board_status = "Any Switch On"
  local board_status = ""
  local s1_status = ""
  local s2_status = ""
  local s3_status = ""
  local s4_status = ""
  local s5_status = ""

  if device:get_latest_state("switch-1", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    s1_status = "S1:On"
    if device.preferences.switchBoardType == "MaxOneSwitchOn" then
      s1_status =  "S1->" .. device:get_latest_state("switch-1", name_Switch1.ID, name_Switch1.nameSwitchOne.NAME)
    end
  end

  if device:get_latest_state("switch-2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    s2_status = "S2:On"
    if device.preferences.switchBoardType == "MaxOneSwitchOn" then
      s2_status =  "S2->" .. device:get_latest_state("switch-2", name_Switch2.ID, name_Switch2.nameSwitchTwo.NAME)
    end
  end

  if device:get_latest_state("switch-3", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    s3_status = "S3:On"
    if device.preferences.switchBoardType == "MaxOneSwitchOn" then
      s3_status =  "S3->" .. device:get_latest_state("switch-3", name_Switch3.ID, name_Switch3.nameSwitchThree.NAME)
    end
  end

  if device:get_latest_state("switch-4", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    s4_status = "S4:On"
    if device.preferences.switchBoardType == "MaxOneSwitchOn" then
      s4_status =  "S4->" ..device:get_latest_state("switch-4", name_Switch4.ID, name_Switch4.nameSwitchFour.NAME)
    end
  end

  if device:get_latest_state("switch-5", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    s5_status = "S5:On"
    if device.preferences.switchBoardType == "MaxOneSwitchOn" then
      s5_status =  "S5->" .. device:get_latest_state("switch-5", name_Switch5.ID, name_Switch5.nameSwitchFive.NAME)
    end
  end

  if device.preferences.switchNumber == 2 then
    board_status = s1_status .. " " .. s2_status
    if s1_status == "" and s2_status == "" then
      board_status = "All Switch Off"
    elseif s1_status == "S1:On" and s2_status == "S2:On" then
      board_status = "All Switch On"
    end

  elseif device.preferences.switchNumber == 3 then
    board_status = s1_status .. " " .. s2_status.. " " .. s3_status
    if s1_status == "" and s2_status == "" and s3_status == "" then
      board_status = "All Switch Off"
    elseif s1_status == "S1:On" and s2_status == "S2:On" and s3_status == "S3:On" then
      board_status = "All Switch On"
    end

  elseif device.preferences.switchNumber == 4 then
    board_status = s1_status .. " " .. s2_status.. " " .. s3_status .. " " .. s4_status
    if s1_status == "" and s2_status == "" and s3_status == "" and s4_status == "" then
      board_status = "All Switch Off"
    elseif s1_status == "S1:On" and s2_status == "S2:On" and s3_status == "S3:On" and s4_status == "S4:On" then
      board_status = "All Switch On"
    end

  elseif device.preferences.switchNumber == 5 then
    board_status = s1_status .. " " .. s2_status.. " " .. s3_status .. " " .. s4_status.. " " .. s5_status
    if s1_status == "" and s2_status == "" and s3_status == "" and s4_status == "" and s5_status == "" then
      board_status = "All Switch Off"
    elseif s1_status == "S1:On" and s2_status == "S2:On" and s3_status == "S3:On" and s4_status == "S4:On"  and s5_status == "S5:On" then
      board_status = "All Switch On"
    end
  end

  device:emit_event(switchBoard_Status.switchBoardStatus({value = board_status}, {visibility = {displayed = false }}))

end


-- callback to handle an on-off capability command
function command_handlers.switch_on_off_handler(driver, device, command)
  print("<<<<<<<<<<<<<<<<<<<<<< On - Off Handler >>>>>>>>>>>>>>>>>>>>>>>")
  local own_state = command.command
  if command.component == "main" then
    if own_state == "on" then
      device:emit_event(capabilities.switch.switch.on())
      if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
        device:emit_event(mirror_Out.mirrorOut("Stop"))
        device:emit_event(mirror_Out.mirrorOut("On"))
      end
    elseif own_state == "off" then
      device:emit_event(capabilities.switch.switch.off())
      if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
        device:emit_event(mirror_Out.mirrorOut("Stop"))
        device:emit_event(mirror_Out.mirrorOut("Off"))
      end
    end
  else
    if own_state == "on" then
      device.profile.components[command.component]:emit_event(capabilities.switch.switch.on())
    elseif own_state == "off" then
      device.profile.components[command.component]:emit_event(capabilities.switch.switch.off())
    end
  end
    if device.preferences.switchBoardType == "MaxOneSwitchOn" then
      if command.component == "switch-1" then
        if device.preferences.switchNumber == 2 then
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 3 then
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 4 then
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 5 then
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-5"]:emit_event(capabilities.switch.switch.off())
        end
      elseif command.component == "switch-2" then
        if device.preferences.switchNumber == 2 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 3 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 4 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 5 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-5"]:emit_event(capabilities.switch.switch.off())
        end
      elseif command.component == "switch-3" then
        if device.preferences.switchNumber == 3 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 4 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 5 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-5"]:emit_event(capabilities.switch.switch.off())
        end
      elseif command.component == "switch-4" then
        if device.preferences.switchNumber == 4 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
        elseif device.preferences.switchNumber == 5 then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-5"]:emit_event(capabilities.switch.switch.off())
        end
      elseif command.component == "switch-5" then
          device.profile.components["switch-1"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-2"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-3"]:emit_event(capabilities.switch.switch.off())
          device.profile.components["switch-4"]:emit_event(capabilities.switch.switch.off())
      end
    end
    if device.preferences.switchNumber > 1 and device.preferences.switchNumber < 6 then
      device.thread:call_with_delay(2, function() command_handlers.set_switchBoard_status(device, command) end)
    end
end


-- Handler mirror_in
function command_handlers.mirror_in(driver, device, command)
  print("Mirror In command:", command.args.value)
  if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
    device:emit_event(mirror_In.mirrorIn(command.args.value))
  end

  if command.args.value == "On" then
    device:emit_event(capabilities.switch.switch.on())
  elseif command.args.value == "Off" then
    device:emit_event(capabilities.switch.switch.off())
  end
end

-- Handler mirror_out
function command_handlers.mirror_out(driver, device, command)
  print("Mirror Out command:", command.args.value)
  if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then 
    device:emit_event(mirror_Out.mirrorOut("Stop"))
  end
end

--command_handlers.setNameSwitch_One_handler
function command_handlers.setNameSwitch_One_handler(driver, device, command)
  device.profile.components["switch-1"]:emit_event(name_Switch1.nameSwitchOne(command.args.value))
end

--command_handlers.setNameSwitch_Two_handler
function command_handlers.setNameSwitch_Two_handler(driver, device, command)
  device.profile.components["switch-2"]:emit_event(name_Switch2.nameSwitchTwo(command.args.value))
end

--command_handlers.setNameSwitch_Three_handler
function command_handlers.setNameSwitch_Three_handler(driver, device, command)
  device.profile.components["switch-3"]:emit_event(name_Switch3.nameSwitchThree(command.args.value))
end

--command_handlers.setNameSwitch_Four_handler
function command_handlers.setNameSwitch_Four_handler(driver, device, command)
  device.profile.components["switch-4"]:emit_event(name_Switch4.nameSwitchFour(command.args.value))
end

--command_handlers.setNameSwitch_Five_handler
function command_handlers.setNameSwitch_Five_handler(driver, device, command)
  device.profile.components["switch-5"]:emit_event(name_Switch5.nameSwitchFive(command.args.value))
end

return command_handlers
