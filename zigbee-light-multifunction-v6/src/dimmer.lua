--- Smartthings library load ---
local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local Groups = zcl_clusters.Groups
local utils = require "st.utils"
local utils_xy = require "utils-xy-lidl"
local LAST_KELVIN_SET = "last_kelvin_set"
--local MONITORED_ATTRIBUTES_KEY = "__monitored_attributes"

local write = require "writeAttribute"
local child_devices = require "child-devices"

local ColorControl = zcl_clusters.ColorControl
local CURRENT_X = "current_x_value" -- y value from xyY color space
local CURRENT_Y = "current_y_value" -- x value from xyY color space
local Y_TRISTIMULUS_VALUE = "y_tristimulus_value" -- Y tristimulus value which is used to convert color xyY -> RGB -> HSV

local last_signal_emit_time = os.time()
local set_status_timer 

---- Load handlers written in dimmer.lua
local driver_handler = {}

------ dimming tables variables init
local progOn = {}
local onStatus = {}
local onTotalSteps = {}
local onStep = {}
local onNewLevel ={}
local onStepLevel = {}
local onTimer ={}
local onStartDim = {}
local dimJump = {}
local progOff = {}
local offStatus ={}
local offTotalSteps = {}
local offStep = {}
local offNewLevel ={}
local offStepLevel = {}
local offLevelStart = {}
local offJump = {}
local offTimer ={}
local device_running = {}

-- Random tables variables
local random_Step = {}
local random_totalStep = {}
local random_timer = {}

--[[ Circadian Rhythm table sun angle replaced by a calculation formula
local circadian_Time_Angle ={
  ["06"] = 0,
  ["07"] = 15,
  ["08"] = 30,
  ["09"] = 45,
  ["10"] = 60,
  ["11"] = 75,
  ["12"] = 90,
  ["13"] = 75,
  ["14"] = 60,
  ["15"] = 45,
  ["16"] = 30,
  ["17"] = 15,
  ["18"] = 0,
  ["19"] = 0,
 } ]]

local circadian_Running = {}
local circadian = {}

-- Color Change variables
local hueMin = {}
local hueMax = {}
local hueStep = {}

local cap_status -- for initialice capabilties

-- Custom Capability Declaration
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
--local driver_Version = capabilities["legendabsolute60149.driverVersion1"]
local forced_On_Level = capabilities["legendabsolute60149.forcedOnLevel"]
local mirror_Group_Function = capabilities["legendabsolute60149.mirrorGroupFunction"]
local effects_Set_Command = capabilities["legendabsolute60149.effectsSetCommand"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]
local hue_Steps = capabilities["legendabsolute60149.hueSteps"]

----- do_init device tables create for dimming variables ----
function driver_handler.do_init (self, device)

  print("<<<<< Device Init >>>>>>")
  print("<<<<< device:", device)

  -- set ZLL_xy device to "no" defaults
  --device:set_field("zll_xy", "no") -- quitado por no necesario

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NOT Child device)

    device_running[device]= device
    onStatus[device] = "stopped"
    onTotalSteps[device] = 2
    onStep[device] = 0
    onNewLevel[device] = 1
    onStepLevel[device] = 1
    onTimer[device]= 2
    dimJump[device] = "no"
    offStatus[device] = "stopped"
    offTotalSteps[device] = 2
    offStep[device] = 0
    offNewLevel[device] = 1
    offStepLevel[device] = 1
    offTimer[device]= 2
    offLevelStart[device] = 10
    offJump[device] = "no"
    random_Step[device] = 1
    random_totalStep[device] =2
    random_timer[device] = math.random(10, 20)

    ----- print device init values for debug------
    local id = device
    if device.preferences.logDebugPrint == true then
      print("<<<<<<<<< device_running[id] >>>>>>>>>>",device_running[id])
      print("progOn=",progOn[id])
      print("onStatus=",onStatus[id])
      print("onTotalSteps=", onTotalSteps[id])
      print("onStep=", onStep[id])
      print("deviceonNewLevel=",onNewLevel[id])
      print("offStepLevel=",onStepLevel[id])
      print("dimJump=", dimJump[id])
      print("progOff=",progOff[id])
      print("offStatus=", offStatus[id])
      print("offTotalSteps=", offTotalSteps[id])
      print("offStep=", offStep[id])
      print("offNewLevel=", offNewLevel[id])
      print("offStepLevel=", offStepLevel[id])
      print("offLevelStart=", offLevelStart[id])
      print("offJump=", offJump[id])
      print("random_Step=",random_Step[id])
      print("random_totalStep=",random_totalStep[id])
      print("random_timer=",random_timer[id])
      print("circadian_Running=",circadian_Running[id])
      print("circadian=",circadian[id])
    end
  end

  ----- INIT status for all devices real and child --------

  --- restart prog-On status
  cap_status =  device:get_latest_state("main", prog_On.ID, prog_On.progOn.NAME)
  if cap_status == nil then
    device:emit_event(prog_On.progOn("Inactive"))
    progOn[device] = "Inactive"
    device:set_field("progOn[device]", progOn[device], {persist = false})
  else
    device:set_field("progOn[device]", cap_status, {persist = false})
    progOn[device] = device:get_field("progOn[device]")
  end

  --- restart prog-Off status
  cap_status = device:get_latest_state("main", prog_Off.ID, prog_Off.progOff.NAME)
  if cap_status == nil then
    device:emit_event(prog_Off.progOff("Inactive"))
    progOff[device] = "Inactive"
    device:set_field("progOff[device]", progOff[device], {persist = false})
  else
    device:set_field("progOff[device]", cap_status, {persist = false})
    progOff[device] = device:get_field("progOff[device]")
  end

  -- restart Circadian status
  cap_status = device:get_latest_state("main", circadian_Light.ID, circadian_Light.circadian.NAME)
  if cap_status == nil then
    device:emit_event(circadian_Light.circadian("Inactive"))
    circadian[device] = "Inactive"
    device:set_field("circadian[device]", circadian[device], {persist = false})
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
  else
    device:set_field("circadian[device]", cap_status, {persist = false})
    circadian[device] = device:get_field("circadian[device]")
    if circadian[device] == "Active" and device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      circadian_Running[device] = "running"
    elseif circadian[device] == "Inactive" or device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
      circadian_Running[device] = "stopped"
    end
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
  end

  -- send zigbee event for random on-off if inactive or nil
  cap_status = device:get_latest_state("main", random_On_Off.ID, random_On_Off.randomOnOff.NAME)
  if cap_status == nil then
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NOT Child device)
      cap_status = device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
      if cap_status == nil then
        device:emit_event(random_Next_Step.randomNext("Inactive"))
      end
    end
    device:set_field("random_state", "Inactive", {persist = false})
  else
    device:set_field("random_state", cap_status, {persist = false})
  end

  -- restore forced level
  local forced_level= device:get_latest_state("main", forced_On_Level.ID, forced_On_Level.forcedOnLevel.NAME)
  if forced_level == nil then 
    forced_level= 0
    device:emit_event(forced_On_Level.forcedOnLevel(forced_level))  
    device:set_field("forced_Level", forced_level, {persist = false})
  else
    device:set_field("forced_Level", forced_level, {persist = false})
  end

  -- restore last level
  cap_status = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
  if cap_status == nil or cap_status <= 1 then cap_status =  100 end
  device:set_field("last_Level", cap_status, {persist = false})

  --- ReStart Timer color chanaging function 
  if device:supports_capability_by_id(capabilities.colorControl.ID) then
    cap_status = device:get_latest_state("main", color_Change_Timer.ID, color_Change_Timer.colorChangeTimer.NAME)
    if cap_status == nil then
      device:emit_event(color_Change_Timer.colorChangeTimer(2))
      device:set_field("colorTimer", 2 , {persist = false})
    else
      device:set_field("colorTimer", cap_status , {persist = false})
    end

    --colorChangeModeList
    cap_status = device:get_latest_state("main", color_Change_Mode.ID, color_Change_Mode.colorChangeMode.NAME)
    if cap_status == nil then
      device:emit_event(color_Change_Mode.colorChangeMode("Random"))
      device:set_field("colorChangeModeList", "Random", {persist = false})
    else
      device:set_field("colorChangeModeList", cap_status, {persist = false})
    end

    --"colorChanging"
    cap_status = device:get_latest_state("main", color_Changing.ID, color_Changing.colorChanging.NAME)
    if cap_status == nil then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = false})
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    else
      device:set_field("colorChanging", cap_status, {persist = false})
      if cap_status == "Active" and device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
        device:set_field("colorChanging_timer", "running", {persist = false})  -- timer need restart
      elseif device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
        device:set_field("colorChanging_timer", "stopped", {persist = false}) -- timmer is canceled
      end
    end
    
    if device:get_field("colorChanging") == "Active" and device:get_field("colorChanging_timer") == "running" then

      if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NOT Child device)
        local group = false
        local child_device = device:get_child_by_parent_assigned_key("main")
        if child_device ~= nil then
          cap_status = child_device:get_latest_state("main", color_Changing.ID, color_Changing.colorChanging.NAME)
          if cap_status == nil then
            child_device:set_field("colorChanging", "Inactive", {persist = false})
            child_device:set_field("colorChanging_timer", "stopped", {persist = false})
          else
            child_device:set_field("colorChanging", cap_status, {persist = false})
          end
          -- if virtual group change color is running
          if child_device:get_field("colorChanging") == "Active" and child_device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
              group = true
              child_device:set_field("colorChanging_timer", "stopped", {persist = false})
          end
        end
        if device:get_field("colorChanging_timer") == "running" then
          device:set_field("colorChanging_timer", "stopped", {persist = false})
          driver_handler.color_Changing_timer_on(self, device, "Continue", group) -- false = is single device, not group
        end
      end

    elseif device:get_field("colorChanging") == "Inactive" then
      cap_status = device:get_latest_state("main", color_Changing.ID, color_Changing.colorChanging.NAME)
      if cap_status ~= "Inactive" then
        device:emit_event(color_Changing.colorChanging("Inactive"))
      end
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    end
  end

  -- initialice mirror_Group_Function status
  cap_status = device:get_latest_state("main", mirror_Group_Function.ID, mirror_Group_Function.mirrorGroupFunction.NAME)
  if cap_status == nil then
    device:emit_event(mirror_Group_Function.mirrorGroupFunction("Inactive"))
    device:set_field("mirror_group_function", "Inactive", {persist = false})
  else
    device:set_field("mirror_group_function", cap_status, {persist = false})
  end

  -- initialice effects_Set_Command_Function status
  cap_status = device:get_latest_state("main", effects_Set_Command.ID, effects_Set_Command.effectsSetCommand.NAME)
  if cap_status == nil then
    device:emit_event(effects_Set_Command.effectsSetCommand("Inactive"))
    device:set_field("effects_set_command", "Inactive", {persist = false})
  else
    device:set_field("effects_set_command", cap_status, {persist = false})
  end

  -- initialize level steps
  cap_status = device:get_latest_state("main", level_Steps.ID, level_Steps.levelSteps.NAME)
  if cap_status == nil then 
    cap_status = 0
    device:emit_event(level_Steps.levelSteps(cap_status))
  end

  -- initialize color temp steps
  if device:supports_capability_by_id(capabilities.colorTemperature.ID) then
    cap_status = device:get_latest_state("main", color_Temperature_Steps.ID, color_Temperature_Steps.colorTempSteps.NAME)
    if cap_status == nil then 
      cap_status = 0
      device:emit_event(color_Temperature_Steps.colorTempSteps(cap_status))
    end
  end

  -- initialize hue steps
  if device:supports_capability_by_id(capabilities.colorControl.ID) then
    cap_status = device:get_latest_state("main", hue_Steps.ID, hue_Steps.hueSteps.NAME)
    if cap_status == nil then 
      cap_status = 0
      device:emit_event(hue_Steps.hueSteps(cap_status))
    end
  end

  ----- restart timers if is ON ----------
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NOT Child device)

    --- restart random on-off if active
    if device.preferences.logDebugPrint == true then
      print("random_state >>>>>",device:get_field("random_state"))
    end
    if device:get_field("random_state") == "Active" then  
      driver_handler.random_on_off_handler(self,device,"Active")
    end
  
    --- restart Circadian timer if activated
    if circadian_Running[device] == "running" and circadian[device] == "Active" then
      driver_handler.circadian_handler(self, device)
    end
  
    --- restart prog-On if is running
    device:set_field("onStatus", "stopped", {persist = false})
    if progOn[device] == "Active" and device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      onStartDim[device] = -1 -- this value will made continue the dimming On with last level
      driver_handler.on_handler (self, device, onStartDim[device])
    end

     --- restart prog-Off if is running
    if device:get_field("offStatus") == "running" then
      driver_handler.off_handler (self, device, "off")
    end

    -- restart effects timer command if on
    if device:get_field("effects_set_command") ~= "Inactive" and device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      driver_handler.effects_Set_handler(self, device, "Continue")
    end

    -- Configure OnOff monitoring attribute
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
  end
end

---- do_removed device procedure: delete all device data
function driver_handler.do_removed(self,device)
  for id, value in pairs(device_running) do
    if device_running[id] == device then
    device_running[device] =nil
    progOn[device] = nil
    onStatus[device] = nil
    onTotalSteps[device] = nil
    onStep[device] = nil
    onNewLevel[device] = nil
    onStepLevel[device] = nil
    onStartDim[device]= nil
    onTimer[device]= nil
    dimJump[device] = nil
    progOff[device] = nil
    offStatus[device] =nil
    offTotalSteps[device] = nil
    offStep[device] = nil
    offNewLevel[device] = nil
    offStepLevel[device] = nil
    offLevelStart[device] = nil
    offTimer[device]= nil
    offJump[device] = nil

    random_Step[device] = nil
    random_totalStep[device] = nil
    random_timer[device] = nil
    circadian_Running[device] = nil
    circadian[device] = nil

    hueMin[device] = nil
    hueMax[device] = nil
    hueStep[device] = nil
   end
  end
  
  -----print tables of devices no removed from driver ------
  if device.preferences.logDebugPrint == true then
    for id, value in pairs(device_running) do
      print("<<<<<<<<< device_running[id] >>>>>>>>>>",device_running[id])
      print("progOn=",progOn[id])
      print("onStatus=",onStatus[id])
      print("onTotalSteps=", onTotalSteps[id])
      print("onStep=", onStep[id])
      print("deviceonNewLevel=",onNewLevel[id])
      print("offStepLevel=",onStepLevel[id])
      print("dimJump=", dimJump[id])
      print("progOff=",progOff[id])
      print("offStatus=", offStatus[id])
      print("offTotalSteps=", offTotalSteps[id])
      print("offStep=", offStep[id])
      print("offNewLevel=", offNewLevel[id])
      print("offStepLevel=", offStepLevel[id])
      print("offLevelStart=", offLevelStart[id])
      print("offJump=", offJump[id])
      print("random_Step=",random_Step[id])
      print("random_totalStep=",random_totalStep[id])
      print("random_timer=",random_timer[id])
      print("circadian_Running=",circadian_Running[id])
      print("circadian=",circadian[id])
      print("hueMin=", hueMin[id])
      print("hueMax=", hueMax[id])
      print("hueStep=", hueStep[id])
    end
  end
end

-----------------------------------------------
---------------- Timers Cancel ----------------
local function timers_Cancel(driver,device)
  if device.preferences.logDebugPrint == true then
    print("<<< timers_Cancel >>>")
  end
  if circadian_Running[device] == "stopped" or circadian[device] == "Inactive" then
    if onStatus[device] == "running" or device:get_field("onStatus") == "running" then
      onStatus[device] ="stopped"
      device:set_field("onStatus", onStatus[device], {persist = false})
    end
    if offStatus[device] == "running" or device:get_field("offStatus") == "running" then
      offStatus[device] = "stopped"
      device:set_field("offStatus", offStatus[device], {persist = true})
    end

    set_status_timer = device:get_field("timer_random")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancelando Random timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_random", nil)
    end
    set_status_timer = device:get_field("timer_progOn")
    if set_status_timer then
      print("<<<<< Cancelando ProgOn timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_progOn", nil)
    end
    set_status_timer = device:get_field("timer_progOff")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancelando ProgOff timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_progOff", nil)
    end
    set_status_timer = device:get_field("timer_circadian")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancelando Circadian timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_circadian", nil)
      --circadian_Running[device] = "stopped"
      --device:set_field("circadian_Running[device]", "stopped", {persist = false})
    end
    set_status_timer = device:get_field("timer_color")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancelando Color Changing timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_color", nil)
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    end
  end
end

--- Update preferences after infoChanged recived---
function driver_handler.do_Preferences (self, device, event, args)
  for id, value in pairs(device.preferences) do
    --oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      if device.preferences.logDebugPrint == true then
        print("<<< Preference changed:",id,"Old Value:",oldPreferenceValue,"New Value:", newParameterValue)
      end

    --- Groups code preference value changed
      if id == "groupAdd" then
        if device.preferences[id] > 0 then
          print("Add Groups >>>>>>>>>>>>>>>>>")
          local data = device.preferences[id]
          device:send(Groups.server.commands.AddGroup(device, data, "Group"..tostring(data)))
          device:send(Groups.server.commands.GetGroupMembership(device, {}))
        else
          device:send(Groups.server.commands.GetGroupMembership(device, {}))
        end
 
        break
      elseif id == "groupRemove" then
        print("Remove Groups >>>>>>>>>>>>>>>>>")
        if device.preferences[id] > 0 then
        device:send(Groups.server.commands.RemoveGroup(device, device.preferences[id]))
        else
        device:send(Groups.server.commands.RemoveAllGroups(device, {}))
        end
        device:send(Groups.server.commands.GetGroupMembership(device, {}))

        break
        ------ Change profile RGBW color temperature
      elseif id == "changeProfile" then
        if newParameterValue == "20006500" then
          print("<< rgbw-level-colortemp-2000-6500 >>")
          device:try_update_metadata({profile = "rgbw-level-colortemp-2000-6500"})
        elseif newParameterValue == "27006500" and device.preferences.colorTempMinim >= 2700 then
          print("<< rgbw-level-colortemp-2700-6500 >>")
          device:try_update_metadata({profile = "rgbw-level-colortemp-2700-6500"})
        elseif newParameterValue == "22004000" and device.preferences.colorTempMaxim <= 4000 and device.preferences.colorTempMinim >= 2200 then
          print("<< rgbw-level-colortemp-2200-4000 >>")
          device:try_update_metadata({profile = "rgbw-level-colortemp-2200-4000"})
        elseif newParameterValue == "RGB" then
          print("<< level-rgb-rgbw >>")
          -- stop circadian function if active
          if circadian[device] == "Active" then
            ---- Timers Cancel ------
            circadian_Running[device] = "stopped"
            device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
            timers_Cancel(self,device)
            device:emit_event(circadian_Light.circadian("Inactive"))
            circadian[device] = "Inactive"
            device:set_field("circadian[device]", circadian[device], {persist = false})
          end

          device:try_update_metadata({profile = "level-rgb-rgbw"})
        end
        break
      elseif id == "onOffReports" then
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
        device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, interval))
        --device:add_configured_attribute(config)
        device:add_monitored_attribute(config)

        break
        --- Configure on-off cluster, attributte 0x8002 and 4003 to value restore state in preferences
      elseif id == "restoreState" then
        if device.preferences.logDebugPrint == true then
          print("<<< Write restore state >>>")
        end
        local value_send = tonumber(newParameterValue)
        local data_value = {value = value_send, ID = 0x30}
        local cluster_id = {value = 0x0006}
        --write atribute for standard devices
        local attr_id = 0x4003
        write.write_attribute_function(device, cluster_id, attr_id, data_value)

        --write atribute for Tuya devices (Restore previous state = 0x02)
        if newParameterValue == "255" then data_value = {value = 0x02, ID = 0x30} end
        attr_id = 0x8002
        write.write_attribute_function(device, cluster_id, attr_id, data_value)

      -- Call to Create child device
      elseif id == "groupChild" then
        if oldPreferenceValue ~= nil and newParameterValue == true then
         child_devices.create_new_device(self, device, "main", "child-rgbw-2000-6500")
        end
        break
      elseif id == "circadianTimeStart" or id == "circadianTimeEnd" then
        if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" and circadian[device] == "Active" then
          driver_handler.circadian_handler(self, device)
        end
        break
      end
    end
  end
  
  -- ********* Emit event for new driver version availabale ********

  --local new_version = " New Driver Version 6 Available: " .. os.date("%Y:%m:%d",os.time())
  --print("new_version >>>>>",new_version)
  --device:emit_event(driver_Version.driverVersion(new_version))

  -- ***************************************************************

  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len)
  local firmware_full_version = device.data.firmwareFullVersion
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

---------------------------------------------------------
------------- color_Changing_handler --------------------

function driver_handler.color_Changing_handler(driver, device, command)
  --print("<< color_Changing_handler >>")

  if device.preferences.logDebugPrint == true then
    print("colorChanging Value", command.args.value)
  end
  local colorChanging = command.args.value

    ---- Timers Cancel ------
    timers_Cancel(driver,device)

  device:set_field("colorChanging_timer", "stopped", {persist = false})

  if colorChanging == "Active" then
    device:set_field("colorChanging", colorChanging, {persist = false})
    device:emit_event(color_Changing.colorChanging("Active"))

      -----cancel progressive ON & OFF and Circadian
    if progOn[device] == "Active" then
      progOn[device] = "Inactive"
      device:set_field("progOn[device]", progOn[device], {persist = false})
      device:emit_event(prog_On.progOn("Inactive"))
    end
    if progOff[device] == "Active" then
     progOff[device] = "Inactive"
      device:set_field("progOff[device]", progOff[device], {persist = false})
      device:emit_event(prog_Off.progOff("Inactive"))
    end
    if circadian[device] == "Active" then
      device:emit_event(circadian_Light.circadian("Inactive"))
      circadian[device] = "Inactive"
      device:set_field("circadian[device]", circadian[device], {persist = false})
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
    end
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:set_field("random_state", "Inactive", {persist = false})
      device:emit_event(random_Next_Step.randomNext("Inactive"))
    end

  elseif colorChanging == "Inactive" then
    device:set_field("colorChanging", colorChanging, {persist = false})
    device:emit_event(color_Changing.colorChanging("Inactive"))
  end

end

-- send zigbee On event for color change mode
local function change_color_on_command(driver, device)
  if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
    if device:get_field("last_Level") == nil or device:get_field("last_Level") < 1 then device:set_field("last_Level", device.preferences.onLevelEnd, {persist = false}) end
    local on_Level = device:get_field("last_Level")
    if device.preferences.onTransTime == 0 then
      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
    else
      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), device.preferences.onTransTime * 10)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
    end
    device:send(zcl_clusters.OnOff.server.commands.On(device)) 
  end
end

 -- Emit command and color event for color chande mode
local function emit_change_color_event(driver, device, newHue, newSaturation)
  --print("ZLL device >>>>>>>",device:get_field("zll_xy"))
  if device:get_field("zll_xy") == "no" then
    --print("ZLL device No >>>>>>>",device:get_field("zll_xy"))
    device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToHueAndSaturation(device, newHue, newSaturation, 0x0000))    
  else
    --print("<<<< convert to x,y >>>>")
    local hue = math.floor(newHue / 0xFE * 100) > 99 and 99 or math.floor(newHue / 0xFE * 100)
    local sat = math.floor(newSaturation / 0xFE * 100)
    local x, y, Y = 0,0,0
    if device:get_manufacturer()=="IKEA of Sweden" then
      x, y, Y = utils.safe_hsv_to_xy(hue, sat)
    else
      x, y, Y = utils_xy.safe_hsv_to_xy(hue, sat)
    end
    device:set_field(Y_TRISTIMULUS_VALUE, Y)
    device:set_field(CURRENT_X, x)
    device:set_field(CURRENT_Y, y)
    if device.preferences.logDebugPrint == true then
      print(">>>>> CURRENT_X=",x)
      print(">>>>> CURRENT_Y=",y)
      print(">>>>> Y_TRISTIMULUS_VALUE=",Y)
    end

    device:send(ColorControl.commands.MoveToColor(device, x, y, 0x0000))
  end
  
  device:emit_event_for_endpoint("main",capabilities.colorControl.hue({value = math.floor(newHue / 0xFE * 100)}, {visibility = {displayed = false }}))
  device:emit_event_for_endpoint("main",capabilities.colorControl.saturation({value = math.floor(newSaturation / 0xFE * 100)}, {visibility = {displayed = false }}))
  --child device emit event
  local child_device = device:get_child_by_parent_assigned_key("main")
  if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
    child_device:emit_event(capabilities.colorControl.hue({value = math.floor(newHue / 0xFE * 100)}, {visibility = {displayed = false }}))
    child_device:emit_event(capabilities.colorControl.saturation({value = math.floor(newSaturation / 0xFE * 100)}, {visibility = {displayed = false }}))
  end
end

-- start color changinng timer
function driver_handler.color_Changing_timer_on(driver, device, command, group)

  if device:get_field("colorChanging_timer") == "stopped" then

    --if device_num == nil then device_num = 1 end
    ---- Timers Cancel ------
    timers_Cancel(driver,device)

    --- Set ColorChangeMode
    local colorChangeMode = device:get_field("colorChangeMode")
    if colorChangeMode == nil then colorChangeMode = 1 end
    local colorTimer = device:get_field("colorTimer")
    if colorTimer == nil then colorTimer = 1 end
    -- Set steps numbers to 0
    local stepsNumber = device:get_field("stepsNumber")
    if stepsNumber == nil then stepsNumber = 0 end
    local stepsNumberMax = device:get_field("stepsNumberMax")
    if stepsNumberMax == nil then stepsNumberMax = 100 end
    local direction = math.random(1, 10)
    if direction <= 5 then direction = 1 else direction = -1 end
    --print("<<< Direction >>>", direction)

    local colorChangeModeList = device:get_field("colorChangeModeList")
    hueMin[device], hueMax[device] = 1, 255
    local satMin, satMax = 190, 240
    local saturationStep = 2
    hueStep[device] = -1
    if colorChangeModeList == "Random" then
      colorChangeMode = 2
    elseif colorChangeModeList == "AllModes" then
      colorChangeMode = math.random(1, 2)
      --colorTimer = math.random(1, 2)
      stepsNumberMax = math.random(30, 80)
      saturationStep = 0.5
      hueStep[device] = -2 * direction
      --device:emit_event(color_Change_Timer.colorChangeTimer(colorTimer))
    else
      colorChangeMode = 1
      if colorChangeModeList == "Continuousallcolors" then
        hueMin[device] = 1
        hueMax[device] = 255
        saturationStep = 0.5
        hueStep[device] = -2 * direction
      elseif colorChangeModeList == "Continuousredorange" then
        hueMin[device] = 1
        hueMax[device] = 34
      elseif colorChangeModeList == "Continuousorangeyellow" then
        hueMin[device] = 20
        hueMax[device] = 48
      elseif colorChangeModeList == "Continuousyellowgreen" then
        hueMin[device] = 36
        hueMax[device] = 114
      elseif colorChangeModeList == "Continuousgreen" then
        hueMin[device] = 51
        hueMax[device] = 114
      elseif colorChangeModeList == "Continuousgreenblue" then
        hueMin[device] = 51
        hueMax[device] = 191
      elseif colorChangeModeList == "Continuousblue" then
        hueMin[device] = 115
        hueMax[device] = 191
      elseif colorChangeModeList == "Continuousbluepurple" then
        hueMin[device] = 115
        hueMax[device] = 238
      elseif colorChangeModeList == "Continuouspurplered" then
        hueMin[device] = 193
        hueMax[device] = 255
      end
    end

    device:set_field("colorChangeMode", colorChangeMode, {persist = false})
    device:set_field("colorTimer",  colorTimer, {persist = false})
    device:set_field("stepsNumber",  stepsNumber, {persist = false})
    device:set_field("stepsNumberMax",  stepsNumberMax, {persist = false})

    local newSaturation = math.random(satMin, satMax)
    --print("<<<<< newSaturation >>>>>",newSaturation )
    device:set_field("newSaturation",  newSaturation, {persist = false})
    local newHue = math.random(hueMin[device], hueMax[device])
    -- print("<<<<< newHue >>>>>",newHue)
    device:set_field("newHue", newHue, {persist = false})

    --local child_device = device:get_child_by_parent_assigned_key("main")
    if group == true then

      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
          if dev:get_field("mirror_group_function") == "Active" and
            dev:supports_capability_by_id(capabilities.colorControl.ID) and
            device.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup > 0 and
            dev.preferences.onOffGroup == device.preferences.onOffGroup then
             
            -- send zigbee On event
            change_color_on_command(driver, dev)
            -- Emit first command and color event
            emit_change_color_event(driver, dev, newHue, newSaturation)

            -- set timer = "running" for group of this child device mirror controller
            local child_device = device:get_child_by_parent_assigned_key("main")
            if child_device ~= nil and dev.id == device.id then
              child_device:set_field("colorChanging_timer", "running", {persist = false})
            end
          end
        end
      end
    elseif group == false then
      -- send zigbee On event
      change_color_on_command(driver, device)
      -- Emit first command and color event
      emit_change_color_event(driver, device, newHue, newSaturation)
    end

    device:set_field("colorChanging_timer", "running", {persist = false})

    ------ Timer Color Changing activation
    set_status_timer = device.thread:call_on_schedule(colorTimer,
    function ()
      
      -- Incremet steps for AllModes Ramdom Mode
      if colorChangeModeList == "AllModes" then
        stepsNumber = device:get_field("stepsNumber")
        stepsNumber = stepsNumber + 1
        if stepsNumber >= device:get_field("stepsNumberMax") and colorChangeModeList == "AllModes" then
          colorChangeMode = math.random(1, 2)
          stepsNumberMax = math.random(30, 80)
          saturationStep = 0.5
          hueStep[device] = -2 * direction
          hueMin[device] = 1
          hueMax[device] = 255
          stepsNumber = 0
        end
        device:set_field("stepsNumber",  stepsNumber, {persist = false})
        device:set_field("stepsNumberMax",  stepsNumberMax, {persist = false})
        device:set_field("colorChangeMode", colorChangeMode, {persist = false})


        if device.preferences.logDebugPrint == true then
          print("<< stepsNumber, stepsNumberMax >>", stepsNumber, stepsNumberMax)
        end

        colorChangeMode = device:get_field("colorChangeMode")
        if colorChangeMode == nil then colorChangeMode = 2 end
      end

      if device.preferences.logDebugPrint == true then
        print("<<< colorChangeModeList", colorChangeModeList)
        print("<<< Color Changing Mode >>>>>>>", colorChangeMode)
        print("*** color Timer ***", colorTimer)
      end

      if colorChangeMode == 1 then
        newSaturation = newSaturation + saturationStep
        if newSaturation > satMax then 
          saturationStep = saturationStep * -1
          newSaturation = satMax
        elseif newSaturation < satMin then
          saturationStep = saturationStep * -1
          newSaturation = satMin
        end
        newHue = newHue + hueStep[device]
        if newHue > hueMax[device] then
          if colorChangeModeList == "Continuousallcolors" then
            newHue = hueMin[device]
          else
            hueStep[device] = hueStep[device] * -1
            newHue = hueMax[device]
          end
        elseif newHue < hueMin[device] then
          if colorChangeModeList == "Continuousallcolors" then
            newHue = hueMax[device]
          else
            hueStep[device] = hueStep[device] * -1
            newHue = hueMin[device]
          end
        end
   
      elseif colorChangeMode == 2 then
        newSaturation = math.random(satMin, satMax)
        newHue = math.random(hueMin[device], hueMax[device])
        if device.preferences.logDebugPrint == true then
          print("<<<<< newSaturation >>>>>",newSaturation )
          print("<<<<< newHue >>>>>",newHue)
        end
      end
    
      -- Emit command and color event
      if group == true then -- emit commands and events for all group devices
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev:get_field("mirror_group_function") == "Active" and
              dev:supports_capability_by_id(capabilities.colorControl.ID) and
              device.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup > 0 and
              dev.preferences.onOffGroup == device.preferences.onOffGroup then
              -- Emit command and color event
              emit_change_color_event(driver, dev, newHue, newSaturation)
            end
          end
        end
      elseif group == false then
        emit_change_color_event(driver, device, newHue, newSaturation)
      end
    end
     ,'ColorChanging')
     device:set_field("timer_color", set_status_timer) 
  end
end

---------------------------------------------------------
--------------- color_Change_Timer_handler --------------

function driver_handler.color_Change_Timer_handler(driver, device, command, group)
  if command.args.value == device:get_field("colorTimer") then return end
  if device.preferences.logDebugPrint == true then
    print("colorChangeTimer Value >>>", command.args.value)
  end
  local colorTimer = command.args.value
  device:set_field("colorTimer", colorTimer, {persist = false})
  device:emit_event(color_Change_Timer.colorChangeTimer(colorTimer))

  --- goto color chanaging function
  local child_device = device:get_child_by_parent_assigned_key("main")
  if device:get_field("colorChanging") == "Active" and device:get_field("colorChanging_timer") == "running" then   
    if group == true then
      if child_device ~= nil then
        if child_device:get_field("colorChanging_timer") == "running" then
          child_device:set_field("colorChanging_timer", "stopped", {persist = false})
          device:set_field("colorChanging_timer", "stopped", {persist = false})
          driver_handler.color_Changing_timer_on(driver, device, command, group)
        end
      end
    else
      if child_device ~= nil and child_device:get_field("colorChanging_timer") ~= "running" then -- if group of device is running then not change mode
        device:set_field("colorChanging_timer", "stopped", {persist = false})
        driver_handler.color_Changing_timer_on(driver, device, command, group)
      end
    end
  end
end

--------------------------------------------------------
------------- color_Change_Mode_handler ----------------

function driver_handler.color_Change_Mode_handler(driver, device, command, group)
  if command.args.value == device:get_field("colorChangeModeList") then return end
  if device.preferences.logDebugPrint == true then
    print("colorChangeMode Value >>>", command.args.value)
  end
  local colorChangeModeList = command.args.value
  device:set_field("colorChangeModeList", colorChangeModeList, {persist = false})
  device:emit_event(color_Change_Mode.colorChangeMode(colorChangeModeList))

  --- goto color chanaging function
  if device:get_field("colorChanging") == "Active" and device:get_field("colorChanging_timer") == "running" then   
    local child_device = device:get_child_by_parent_assigned_key("main")
    if group == true then
      if child_device ~= nil then
        if child_device:get_field("colorChanging_timer") == "running" then
          child_device:set_field("colorChanging_timer", "stopped", {persist = false}) 
          device:set_field("colorChanging_timer", "stopped", {persist = false})
          driver_handler.color_Changing_timer_on(driver, device, command, group)
        end
      end
    else
      if child_device ~= nil and child_device:get_field("colorChanging_timer") ~= "running" then -- if group of device is running then not change mode
        device:set_field("colorChanging_timer", "stopped", {persist = false})
        driver_handler.color_Changing_timer_on(driver, device, command, group)
      end
    end
  end
end

 --------------------------------------------------------
 --------- Handler Random ON-OFF ------------------------

function driver_handler.random_on_off_handler(driver,device,command)
  if command == nil then
    if command.args.value == device:get_field("random_state") then return end
  end
  local random_state = "-"
  if command == "Active" then -- re-actiate timer random due to driver init or hub reboot
    random_state = "Active"
  else
    random_state = command.args.value
  end
  if device.preferences.logDebugPrint == true then
    print("randomOnOff Value >>>", random_state)
  end
  if random_state == "Inactive" then

    cap_status =  device:get_latest_state("main", random_On_Off.ID, random_On_Off.randomOnOff.NAME)
    if cap_status ~= "Inactive" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
    end
    device:set_field("random_state", "Inactive", {persist = false})
    -- send zigbee event
    device:send(OnOff.server.commands.Off(device))
    if device:supports_capability_by_id(capabilities.colorTemperature.ID) then
      circadian_Running[device]= "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
    end

    ---- All Timers Cancel ------
    timers_Cancel(driver,device)

    --device:emit_event(random_On_Off.randomOnOff("Inactive"))
    --emit time for next change
    local nextChange = "Inactive"
    cap_status =  device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
    if cap_status ~= "Inactive" then
      device:emit_event(random_Next_Step.randomNext(nextChange))
    end

  elseif random_state == "Active" then

    cap_status =  device:get_latest_state("main", random_On_Off.ID, random_On_Off.randomOnOff.NAME)
    if cap_status ~= "Active" then
      device:emit_event(random_On_Off.randomOnOff("Active"))
    end
    device:set_field("random_state", "Active", {persist = false})

    -----cancel progressive ON & OFF, Circadian and Color Changing
    if progOn[device] == "Active" then
      progOn[device] = "Inactive"
      device:set_field("progOn[device]", progOn[device], {persist = false})
      device:emit_event(prog_On.progOn("Inactive"))
    end
    if progOff[device] == "Active" then
      progOff[device] = "Inactive"
      device:set_field("progOff[device]", progOff[device], {persist = false})
      device:emit_event(prog_Off.progOff("Inactive"))
    end
    if device:supports_capability_by_id(capabilities.colorTemperature.ID) and circadian[device] == "Active" then
      device:emit_event(circadian_Light.circadian("Inactive"))
      circadian[device] = "Inactive"
      device:set_field("circadian[device]", circadian[device], {persist = false})
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
    end
    if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = false})
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    end

    ---- All Timers Cancel ------
    timers_Cancel(driver,device)

    random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
    random_Step[device] = 0
    random_totalStep[device] = math.ceil(random_timer[device] / 30)

    local nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)

    --emit time for next change
    device:emit_event(random_Next_Step.randomNext(nextChange))
    if device.preferences.logDebugPrint == true then
      print("random_totalStep=",random_totalStep[device])
      print("NextChange=",nextChange)
    end

    ------ Timer activation
    set_status_timer = device.thread:call_on_schedule(30,
      function ()
        random_Step[device] = random_Step[device] + 1
        if random_Step[device] >= random_totalStep[device] then
          -- emit on-off command
          if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
            device:send(OnOff.server.commands.Off(device))
          else
            device:send(OnOff.server.commands.On(device))
          end

          random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
          random_Step[device] = 0
          random_totalStep[device] = math.ceil(random_timer[device] / 30)
          nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)

          --emit time for next change
          device:emit_event(random_Next_Step.randomNext(nextChange))
          if device.preferences.logDebugPrint == true then
            print("NEW-random_totalStep=",random_totalStep[device])
            print("NextChange=",nextChange)
          end
        end
      end
      ,'Random-ON-OFF')
      device:set_field("timer_random", set_status_timer) 
  end
end

----------------------------------------------------------------
-------- Progressive ON activation & deativation ---------------

function driver_handler.prog_On_handler(driver, device, command)
  if command.args.value == device:get_field("progOn[device]") then return end
  if device.preferences.logDebugPrint == true then
    print("ProgOn Value >>>", command.args.value)
  end
  if command.args.value == "Inactive" then
    progOn[device] = "Inactive"
    device:set_field("progOn[device]", progOn[device], {persist = false})
    cap_status =  device:get_latest_state("main", prog_On.ID, prog_On.progOn.NAME)
    if cap_status ~= "Inactive" then
      device:emit_event(prog_On.progOn("Inactive"))
    end
      if onStatus[device] == "running" then
        ---- Timers Cancel ------
        timers_Cancel(driver,device)
      end
  elseif command.args.value == "Active" then
    progOn[device] = "Active"
    device:set_field("progOn[device]", progOn[device], {persist = false})
    cap_status =  device:get_latest_state("main", prog_On.ID, prog_On.progOn.NAME)
    if cap_status ~= "Active" then
      device:emit_event(prog_On.progOn("Active"))
    end
    ---- Cancel Random On-OFF color Changing and Circadian
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:emit_event(random_Next_Step.randomNext("Inactive"))
      device:set_field("random_state", "Inactive", {persist = false})

    elseif circadian[device] == "Active" then
      device:emit_event(circadian_Light.circadian("Inactive"))
      circadian[device] = "Inactive"
      device:set_field("circadian[device]", circadian[device], {persist = false})
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})

    elseif device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = false})
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    end
    ---- Timers Cancel ------
    timers_Cancel(driver,device)
  end
  
end

-----------------------------------------------------------------
-------- Progressive OFF activation & deativation ---------------

function driver_handler.prog_Off_handler(driver, device, command)
  if command.args.value == device:get_field("progOff[device]") then return end
  if device.preferences.logDebugPrint == true then
    print("ProgOff Value >>>", command.args.value)
  end
  if command.args.value == "Inactive" then
    progOff[device] = "Inactive"
    device:set_field("progOff[device]", progOff[device], {persist = false})
    cap_status =  device:get_latest_state("main", prog_Off.ID, prog_Off.progOff.NAME)
    if cap_status ~= "Inactive" then
      device:emit_event(prog_Off.progOff("Inactive"))
    end
    if offStatus[device] == "running" then
      ---- Timers Cancel ------
      timers_Cancel(driver,device)
    end
  elseif command.args.value == "Active" then
    progOff[device] = "Active"
    device:set_field("progOff[device]", progOff[device], {persist = false})
    cap_status =  device:get_latest_state("main", prog_Off.ID, prog_Off.progOff.NAME)
    if cap_status ~= "Active" then
      device:emit_event(prog_Off.progOff("Active"))
    end
    ---- Cancel Random On-OFF color Changing and Circadian
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:emit_event(random_Next_Step.randomNext("Inactive"))
      device:set_field("random_state", "Inactive", {persist = false})
    elseif circadian[device] == "Active" then
      device:emit_event(circadian_Light.circadian("Inactive"))
      circadian[device] = "Inactive"
     device:set_field("circadian[device]", circadian[device], {persist = false})
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
    elseif device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = false})
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    end
    ---- Timers Cancel ------
    timers_Cancel(driver,device)
  end
end

-----------------------------------------------
--------- level_Steps_handler -----------------

function driver_handler.level_Steps_handler(driver, device, command)

  ---- Cancel Random On-OFF color Changing and Circadian stopped
  if device:get_field("random_state") == "Active" then
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    device:set_field("random_state", "Inactive", {persist = false})
  end
  if circadian_Running[device] == "running" then
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
  end
  if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = false})
    device:set_field("colorChanging_timer", "stopped", {persist = false})
  end

  ---- Timers Cancel ------
  timers_Cancel(driver,device)

  ---- next level calculation  
  if device.preferences.logDebugPrint == true then
    print("Level Steps Value =", command.args.value)
  end
  local level = command.args.value
  device:emit_event(level_Steps.levelSteps(level))
  
  local direction = 0x00
  if level < 0 then direction = 0x01 end

  if device.preferences.levelExtStepsMode == "Step" or device.preferences.levelExtStepsMode == nil then
    if device.preferences.levelTransTime == 0 then
      local command1 = zcl_clusters.Level.commands.StepWithOnOff(device, direction, math.floor((math.abs(level)/100.0 * 254)), 0xFFFF)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.StepWithOnOff(device, direction, math.floor((math.abs(level)/100.0 * 254)), 0xFFFF))
    else
      local command1 = zcl_clusters.Level.commands.StepWithOnOff(device, direction, math.floor((math.abs(level)/100.0 * 254)), device.preferences.levelTransTime * 10)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.StepWithOnOff(device, direction, math.floor((math.abs(level)/100.0 * 254)), math.floor(device.preferences.levelTransTime * 10)))
    end

    local prev_level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
    level = level + prev_level

    if level < 0 then 
      level = 0 
    elseif level > 100 then
      level = 100
    end
    device:set_field("last_Level", level, {persist = false})

    local level_read = function(d)
      device:send_to_component(command.component, zcl_clusters.Level.attributes.CurrentLevel:read(device))
    end
    device.thread:call_with_delay(device.preferences.levelTransTime + 1, level_read, "setLevel delayed read")
  elseif device.preferences.levelExtStepsMode == "Continuos" and level ~= 0 then
    local command1 = zcl_clusters.Level.commands.MoveWithOnOff(device, direction, math.floor(math.abs(level)/100.0 * 254 + 0.5))
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
  elseif device.preferences.levelExtStepsMode == "Continuos" and level == 0 then
    local command1 = zcl_clusters.Level.commands.StopWithOnOff(device)
    if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
      command1.body.zcl_body.options_mask = nil
      command1.body.zcl_body.options_override = nil
    end
    device:send(command1) 
  end

end

-----------------------------------------------
--------- color_Temperature_Steps_handler -----------------

function driver_handler.color_Temperature_Steps_handler(driver, device, command)

  if device.preferences.logDebugPrint == true then
    print("Color Temperature Steps Value >>>", command.args.value)
  end

    ---- Cancel Random On-OFF color Changing and Circadian stopped
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:emit_event(random_Next_Step.randomNext("Inactive"))
      device:set_field("random_state", "Inactive", {persist = false})
    end
    if circadian_Running[device] == "running" then
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
    end
    if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = false})
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    end
  
    ---- Timers Cancel ------
    timers_Cancel(driver,device)

    ---Next Color Temperature calculation
    local colorTemp_step = command.args.value
    device:emit_event(color_Temperature_Steps.colorTempSteps(colorTemp_step))

    local colorTemp_prev = device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME)
    --local colorTemp = math.floor(utils.round(colorTemp_step + device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME)))
    local colorTemp = math.floor(utils.round(colorTemp_step + colorTemp_prev))
    
    -- check if colortemp is limited
    if device.preferences.limitColorTemp == true then 
      if colorTemp > device.preferences.colorTempMaxim then 
        colorTemp = math.floor(device.preferences.colorTempMaxim)
      elseif colorTemp < device.preferences.colorTempMinim then 
        colorTemp = math.floor(device.preferences.colorTempMinim)
      end
    end

    --print("colorTemp", colorTemp)
    device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
    local colorTemp_Mireds = utils.round(1000000 / colorTemp)
    --print("colorTemp Mired", colorTemp_Mireds)
    device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, math.floor(device.preferences.tempTransTime * 10)))

    local color_temp_read = function(d)
      device:send_to_component(command.component, zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
    end
    device.thread:call_with_delay(device.preferences.tempTransTime + 1, color_temp_read, "setColorTemp delayed read")

end

----------------------------------------------
--------- hue_Steps_handler -----------------

function driver_handler.hue_Steps_handler(driver, device, command)

  if device.preferences.logDebugPrint == true then
    print("Hue Steps Value >>>", command.args.value)
  end

    ---- Cancel Random On-OFF color Changing and Circadian stopped
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:emit_event(random_Next_Step.randomNext("Inactive"))
      device:set_field("random_state", "Inactive", {persist = false})
    end
    if circadian_Running[device] == "running" then
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
    end
    if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = false})
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    end
  
    ---- Timers Cancel ------
    timers_Cancel(driver,device)

    ---Next Color  calculation
    local hue_step = command.args.value
    device:emit_event(hue_Steps.hueSteps(hue_step))
    hue_step = math.ceil(hue_step  / 100 * 254)
    local new_hue = device:get_latest_state("main", capabilities.colorControl.ID, capabilities.colorControl.hue.NAME)
    new_hue = math.ceil(new_hue / 100 * 254) + hue_step
    if new_hue > 255 then
      new_hue = 255
    elseif new_hue < 0 then
      new_hue = 0
    end

    local new_sat = device:get_latest_state("main",capabilities.colorControl.ID,capabilities.colorControl.saturation.NAME)
    new_sat = math.ceil(new_sat / 100 * 254)

    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
      device:send(OnOff.server.commands.On(device))
    end
    emit_change_color_event(driver, device, new_hue, new_sat)

end

-----------------------------------------------
----------- circadian_Light_handler -----------

function driver_handler.circadian_Light_handler(driver, device, command)
  if command.args.value == device:get_field("circadian[device]") then return end
  if device.preferences.logDebugPrint == true then
    print("Circadian Value", command.args.value)
  end

  if command.args.value == "Inactive" then
    cap_status =  device:get_latest_state("main", circadian_Light.ID, circadian_Light.circadian.NAME)
    if cap_status ~= "Inactive" then
      device:emit_event(circadian_Light.circadian("Inactive"))
    end
    circadian[device] = "Inactive"
    device:set_field("circadian[device]", circadian[device], {persist = false})
    
    ---- Timers status ------
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})

  else
    cap_status =  device:get_latest_state("main", circadian_Light.ID, circadian_Light.circadian.NAME)
    if cap_status ~= "Active" then
      device:emit_event(circadian_Light.circadian("Active"))
    end
    circadian[device] = "Active"
    device:set_field("circadian[device]", circadian[device], {persist = false})
    -----cancel progressive ON & OFF color Changing and Random On-Off
    if progOn[device] == "Active" then
      progOn[device] = "Inactive"
      device:set_field("progOn[device]", progOn[device], {persist = false})
      device:emit_event(prog_On.progOn("Inactive"))
    end
    -- cancel progressive Off --------
    if progOff[device] == "Active" then
      progOff[device] = "Inactive"
      device:set_field("progOff[device]", progOff[device], {persist = false})
      device:emit_event(prog_Off.progOff("Inactive"))
    end
    if device:get_field("random_state") == "Active" then
      device:emit_event(random_On_Off.randomOnOff("Inactive"))
      device:set_field("random_state", "Inactive", {persist = false})
      device:emit_event(random_Next_Step.randomNext("Inactive"))
    --end
    elseif device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:emit_event(color_Changing.colorChanging("Inactive"))
      device:set_field("colorChanging", "Inactive", {persist = false})
      device:set_field("colorChanging_timer", "stopped", {persist = false})
    end

    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      ---- Timers Cancel ------
      timers_Cancel(driver,device)

      driver_handler.circadian_handler(driver, device)
    end
  end
  ---- Timers Cancel ------
  timers_Cancel(driver,device)  
end

----------------------------------------------- 
---------- Circadian rhythm Timer run-------------------
function driver_handler.circadian_handler(self, device)

  if device.preferences.logDebugPrint == true then
    print("<<<<<<<<<<<<<<< In Circadian timer On >>>>>>>>>>>>>>>>")
  end

  local colorTemp = device.preferences.colorTempMinim --2700
  local colorTempHour = device.preferences.colorTempMinim --2700
  local colorTempNextHour = device.preferences.colorTempMinim --2700
  local newLevel = (device.preferences.circadLevelMin + device.preferences.circadLevelMax) / 2
  local localHour= tonumber(os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600)))
  if localHour == 0 then localHour = 24 end
  local localNextHour= tonumber(os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600) + 3600))
  if localNextHour == 0 then localNextHour = 24 end
  local localMinutes= tonumber(os.date("%M",os.time() + device.preferences.localTimeOffset))
  local hour_int = device.preferences.circadianTimeStart
  if hour_int == nil then hour_int = 6 end
  local hour_end = device.preferences.circadianTimeEnd
  if hour_end == nil then hour_end = 18 end
  if device.preferences.logDebugPrint == true then
    print("localHour, localMinutes =", localHour, localMinutes)
  end
  if localHour >= hour_int and localHour < hour_end then
    circadian_Running[device] = "running"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = false})
    if device.preferences.logDebugPrint == true then
      print("circadian_Running=", circadian_Running[device])
    end

    -- set initial color temperature
    -- Sun angle run from 0º (sunrise) to 90º (noon) and 0º (sunset)
    local circadian_med_period = (hour_end + hour_int) / 2  -- calculate the middle of time period
    local sun_angle_hour= ((localHour - hour_int) / (circadian_med_period - hour_int)) -- calcualte sun angle for current Local Hour
    if sun_angle_hour > 1 then -- 0 = sunrise, 1 = 100% of 90º sun angle, > 1 then sun angle pass noon of day and run from 90º to 0º
      sun_angle_hour = (2 - sun_angle_hour) * 90
    else
      sun_angle_hour = sun_angle_hour * 90
    end

    local sun_angle_next_hour= ((localNextHour - hour_int) / (circadian_med_period - hour_int))
    if sun_angle_next_hour > 1 then -- 0 = sunrise, 1 = 100% of 90º sun angle, > 1 then sun angle pass noon of day and run from 90º to 0º
      sun_angle_next_hour = (2 - sun_angle_next_hour) * 90
    else
      sun_angle_next_hour = sun_angle_next_hour * 90
    end

    if device.preferences.logDebugPrint == true then
      print("<< sun_angle_hour:",sun_angle_hour)
      print("<< sun_angle_next_hour:",sun_angle_next_hour)
    end
   
    -- initial color temperature
    colorTempHour = device.preferences.colorTempMinim + ((device.preferences.colorTempMaxim - device.preferences.colorTempMinim) * math.sin(math.rad(sun_angle_hour)))
    colorTempNextHour = device.preferences.colorTempMinim + ((device.preferences.colorTempMaxim - device.preferences.colorTempMinim) * math.sin(math.rad(sun_angle_next_hour)))
    colorTemp =  math.floor(utils.round(colorTempHour + ((colorTempNextHour - colorTempHour) * localMinutes /60)))
    if colorTemp < device.preferences.colorTempMinim then colorTemp = device.preferences.colorTempMinim end

    --- new level calculation
    newLevel = math.ceil(device.preferences.circadLevelMin + (((colorTemp - device.preferences.colorTempMinim) / (device.preferences.colorTempMaxim - device.preferences.colorTempMinim)) * (device.preferences.circadLevelMax - device.preferences.circadLevelMin)))
    if newLevel > 100 then
      newLevel = 100
    elseif newLevel < 0 then
      newLevel = 0
    end
    device:set_field("last_Level", newLevel, {persist = false})

    if device.preferences.logDebugPrint == true then
      print("TempHour", colorTempHour, "TempNextHour",colorTempNextHour)
      print("colorTemp =", colorTemp)
      print("New Level=", newLevel)
    end

    --send initial values
    if device:get_manufacturer() == "IKEA of Sweden" then
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0x0))
    else
      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(newLevel/100.0 * 254), 0xFFFF)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1)
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0xFFFF)) 
    end
    --print("colorTemp =", colorTemp)
    device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
    local colorTemp_Mireds = utils.round(1000000 / colorTemp)
    --print("colorTemp Mired", colorTemp_Mireds)
    device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
    local color_temp_read = function(d)
      device:send_to_component("main", zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
    end

    -- added to ZLL devices get turn on state
    device.thread:call_with_delay(2, function(d)
      --print("<<<< refresh Delay")
        device:refresh()
    end)
    --device.thread:call_with_delay(2, color_temp_read, "setColorTemp delayed read")

    
    set_status_timer = device:get_field("timer_circadian")
    if set_status_timer ~= nil then return end
    ---- Set timer for circadian cycle
    set_status_timer = device.thread:call_on_schedule(300, 
    function ()
      localHour= tonumber(os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600)))
      if localHour == 0 then localHour = 24 end
      localNextHour= tonumber(os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600) + 3600))
      if localNextHour == 0 then localNextHour = 24 end
      localMinutes= tonumber(os.date("%M",os.time() + device.preferences.localTimeOffset))

      if localHour >= hour_int and localHour < hour_end then

        --- New colorTemperature Calculation
        --Sun angle run from 0º (sunrise) to 90º (noon) and 0º (sunset)
        sun_angle_hour= ((localHour - hour_int) / (circadian_med_period - hour_int)) -- calcualte sun angle for current Local Hour
        if sun_angle_hour > 1 then -- 0 = sunrise, 1 = 100% of 90º sun angle, > 1 then sun angle pass noon of day and run from 90º to 0º
          sun_angle_hour = (2 - sun_angle_hour) * 90
        else
          sun_angle_hour = sun_angle_hour * 90
        end

        sun_angle_next_hour= ((localNextHour - hour_int) / (circadian_med_period - hour_int))
        if sun_angle_next_hour > 1 then -- 0 = sunrise, 1 = 100% of 90º sun angle, > 1 then sun angle pass noon of day and run from 90º to 0º
          sun_angle_next_hour = (2 - sun_angle_next_hour) * 90
        else
          sun_angle_next_hour = sun_angle_next_hour * 90
        end

        if device.preferences.logDebugPrint == true then
          print("localHour, localMinutes =", localHour, localMinutes)
          print("<< sun_angle_hour:",sun_angle_hour)
          print("<< sun_angle_next_hour:",sun_angle_next_hour)
        end

        colorTempHour = device.preferences.colorTempMinim + ((device.preferences.colorTempMaxim - device.preferences.colorTempMinim) * math.sin(math.rad(sun_angle_hour)))
        colorTempNextHour = device.preferences.colorTempMinim + ((device.preferences.colorTempMaxim - device.preferences.colorTempMinim) * math.sin(math.rad(sun_angle_next_hour)))
        colorTemp =  math.floor(utils.round(colorTempHour + ((colorTempNextHour - colorTempHour) * localMinutes /60)))
        if colorTemp < device.preferences.colorTempMinim then colorTemp = device.preferences.colorTempMinim end
        --- new level calculation)
        newLevel = math.ceil(device.preferences.circadLevelMin + (((colorTemp - device.preferences.colorTempMinim) / (device.preferences.colorTempMaxim - device.preferences.colorTempMinim)) * (device.preferences.circadLevelMax - device.preferences.circadLevelMin)))

        if newLevel > 100 then
          newLevel = 100
        elseif newLevel < 0 then
          newLevel = 0
        end
        
        if device.preferences.logDebugPrint == true then
          print("TempHour", colorTempHour, "TempNextHour",colorTempNextHour)
          print("colorTemp =", colorTemp)
          print("New Level=", newLevel)
        end

        device:set_field("last_Level", newLevel, {persist = false})

        --send values
        if device:get_manufacturer() == "IKEA of Sweden" then
          device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0x0))
        else
          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(newLevel/100.0 * 254), 0xFFFF)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0xFFFF)) 
        end

        --print("colorTemp =", colorTemp)
        device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
        colorTemp_Mireds = utils.round(1000000 / colorTemp)
        --print("colorTemp Mired", colorTemp_Mireds)
        device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
        color_temp_read = function(d)
          device:send_to_component("main", zcl_clusters.Level.attributes.CurrentLevel:read(device))
          device:send_to_component("main", zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
        end
        device.thread:call_with_delay(2, color_temp_read, "setColorTemp delayed read")
      end
    end,
    "Circadian_timer")
    device:set_field("timer_circadian", set_status_timer)
  else
    if device.preferences.logDebugPrint == true then
      print("<<< Circadian time out of period >>>")
    end
    if device.preferences.circadianNightSetting == false then
      --print("<<<<<<< circadianNightSetting (false)>>>>>>>>>",device.preferences.circadianNightSetting)
      local on_Level = device:get_field("last_Level")
      -- detect if forced Level actived
      if device:get_field("forced_Level") > 0 then
        --if on_Level >= device:get_field("forced_Level") then
          on_Level = device:get_field("forced_Level")
          device:set_field("last_Level", on_Level, {persist = false})
        --end
      end
      if device.preferences.onTransTime == 0 then
        --device:send(OnOff.server.commands.On(device))
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1) 
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
      else
        --print("Turn On >>>>>>>>>>>>>>>>")
        if on_Level == nil then on_Level = device.preferences.onLevelEnd end
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), device.preferences.onTransTime * 10)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), math.floor(device.preferences.onTransTime * 10)))
      end
      device:send(OnOff.server.commands.On(device))
    else
      --print("<<<<<<< circadianNightSetting (true)>>>>>>>>>",device.preferences.circadianNightSetting)
      local on_Level = device.preferences.circadLevelMin
      device:set_field("last_Level", on_Level, {persist = false})
      if device:get_manufacturer() == "IKEA of Sweden" then
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0x0))
      else
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1) 
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF)) 
      end

      colorTemp = math.floor(device.preferences.colorTempMinim)
      device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
      local colorTemp_Mireds = utils.round(1000000 / colorTemp)
      device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
      device:send(OnOff.server.commands.On(device))
      local color_temp_read = function(d)
        device:send_to_component("main", zcl_clusters.ColorControl.attributes.ColorTemperatureMireds:read(device))
      end
      --device.thread:call_with_delay(2, color_temp_read, "setColorTemp delayed read")
    end

    -- added to ZLL devices get turn on state
    device.thread:call_with_delay(2, function(d)
      --print("<<<< refresh Delay")
        device:refresh()
      end)
  end
end

-----------------------------------------------
---------------- TURN ON handler --------------

function driver_handler.on_handler (driver, device, command, group)
  print("Turn On handler >>>>>>>>>>>")
      -- capability reference
  local attr = capabilities.switch.switch

   ----- detect progressive turn On activated--
    if progOn[device]  ==  "Active" and circadian[device] == "Inactive" then
      if device.preferences.logDebugPrint == true then
        print ("turnOn.onStatus =", onStatus[device])
      end
      if onStatus[device] =="stopped" then

        if device.preferences.ifPushSwitch == "Change" or onStartDim[device] == -1 then
          --print("<<<<<<<< Estoy en change on start Dim")
          if onStartDim[device] == -1 then
            onStartDim[device] = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
          else
            onStartDim[device] = device.preferences.onLevelStart
            -- detect if forced Level actived
            if device:get_field("forced_Level") > 0 then
              if onStartDim[device] > device:get_field("forced_Level") then
                onStartDim[device] = device:get_field("forced_Level")
              end
            end
          end
        else
          onStartDim[device] = device.preferences.onLevelStart
          -- detect if forced Level actived
          if device:get_field("forced_Level") > 0 then
            if onStartDim[device] > device:get_field("forced_Level") then
              onStartDim[device] = device:get_field("forced_Level")
            end
          end
        end

      --ON dimming timer calculation
      local diff_level = device.preferences.onLevelEnd - onStartDim[device]
      if diff_level == 0 then 
        onTimer[device] = 1
      else
        onTimer[device] = math.abs(device.preferences.onTimeMax * 60 / diff_level)
        if onTimer[device] < 0.3 then onTimer[device] = 0.3 end
      end
      onTotalSteps[device] = math.floor(device.preferences.onTimeMax * 60 / onTimer[device])
      onStepLevel[device] = ((device.preferences.onLevelEnd - onStartDim[device])+ 0.1) / onTotalSteps[device]

      if device.preferences.logDebugPrint == true then
        print("<< onTimer =",onTimer[device])
        print ("turnOn.onTotalSteps =", onTotalSteps[device])
        print ("turnOn.onStepLevel =", onStepLevel[device])
      end

      onStep[device] = 0
      onStatus[device] ="running"
      device:set_field("onStatus", onStatus[device], {persist = false})

      -- set the initial level On
      onNewLevel[device] = onStartDim[device]
      onStep[device] = onStep[device] + 1

      local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF)
      if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
        command1.body.zcl_body.options_mask = nil
        command1.body.zcl_body.options_override = nil
      end
      device:send(command1) 
      --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF))

      device:send(OnOff.server.commands.On(device))
      device:emit_event(attr.on())

      ---- Change Temp Color if option activated -----
      if device.preferences.progLevelColor == "Yes" then
        local colorTemp =  math.floor((utils.round(onNewLevel[device])/100 * ((device.preferences.colorTempMaxim) - device.preferences.colorTempMinim)) + device.preferences.colorTempMinim)
        device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
        local colorTemp_Mireds= utils.round(1000000/colorTemp)
        device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
        device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
      end

      -------- turn on: timer dimming ON --------
      set_status_timer = device.thread:call_on_schedule(onTimer[device], 
      function ()
        if onStatus[device] =="running" then
          onStep[device] = onStep[device] + 1 
          onNewLevel[device] = onNewLevel[device] + onStepLevel[device]
          if device.preferences.logDebugPrint == true then
            print("onStep=",onStep[device])
          end
          if device.preferences.onLevelEnd >= device.preferences.onLevelStart then
            if onNewLevel[device] >= device.preferences.onLevelEnd or onStep[device] >= onTotalSteps[device] then 
              onNewLevel[device] = device.preferences.onLevelEnd
              onStatus[device] ="stopped"
              device:set_field("onStatus", onStatus[device], {persist = false})
              --cancel timer
              local timer = device:get_field("timer_progOn")
              if timer then
                if device.preferences.logDebugPrint == true then
                  print("<<< Cancel Prog On timer >>>")
                end
                device.thread:cancel_timer(timer)
                device:set_field("timer_progOn", nil)
              end             
            end
          else
            if onNewLevel[device] < device.preferences.onLevelEnd and onStep[device] >= onTotalSteps[device] then
              onNewLevel[device] = device.preferences.onLevelEnd
              onStatus[device] ="stopped"
              device:set_field("onStatus", onStatus[device], {persist = false})
              --cancel timer
              local timer = device:get_field("timer_progOn")
              if timer then
                if device.preferences.logDebugPrint == true then
                  print("<<< Cancel Prog On timer >>>")
                end
                device.thread:cancel_timer(timer)
                device:set_field("timer_progOn", nil)
              end         
            end
          end

          if device.preferences.logDebugPrint == true then
            print ("turnOn.onNewLevel=",onNewLevel[device])
            print("Last Level=", device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
          end

          -- detect if forced Level actived
          if device:get_field("forced_Level") > 0 then
            if onNewLevel[device] > device:get_field("forced_Level") then
              onNewLevel[device] = device:get_field("forced_Level")
              --stop dimming and cancel timer
              onStatus[device] ="stopped"
              device:set_field("onStatus", onStatus[device], {persist = false})
              local timer = device:get_field("timer_progOn")
              if timer then
                if device.preferences.logDebugPrint == true then
                  print("<<< Cancel Prog On timer >>>")
                end
                device.thread:cancel_timer(timer)
                device:set_field("timer_progOn", nil)
              end 
            end
          end

          command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF))

          ---- Change Temp Color if option activated -----
          if device.preferences.progLevelColor == "Yes" then
            local colorTemp =  math.floor((utils.round(onNewLevel[device])/100 * ((device.preferences.colorTempMaxim) - device.preferences.colorTempMinim)) + device.preferences.colorTempMinim)
            device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
            local colorTemp_Mireds = utils.round(1000000 / colorTemp)
            --print("Color Temp K;  colorTemp Mired", math.floor(colorTemp), colorTemp_Mireds)
            device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
            device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
          end
        end
       end)
       device:set_field("timer_progOn", set_status_timer)
     end
    end

    --- send status ON without dimming---
    if device.preferences.logDebugPrint == true then
      print("<<<<<<<<<< device", device)
      print("<<<<<<<<<< circadian[device]",circadian[device])
    end
    if device:get_field("colorChanging") == "Active" and device:get_field("colorChanging_timer") == "stopped" then

      if group == true then
        local child_device = device:get_child_by_parent_assigned_key("main")
        if child_device ~= nil then
          driver_handler.color_Changing_timer_on(driver, device, command, group)
        end
      else 
        driver_handler.color_Changing_timer_on(driver, device, command, group)
      end

    elseif progOn[device]  ==  "Inactive" and circadian[device] == "Inactive" and onStatus[device] =="stopped" then
      if device:get_field("last_Level") == nil or device:get_field("last_Level") < 1 then device:set_field("last_Level", device.preferences.onLevelEnd, {persist = false}) end
      local on_Level = device:get_field("last_Level")

      -- detect if forced Level actived
      if device:get_field("forced_Level") > 0 then
          on_Level = device:get_field("forced_Level")
          device:set_field("last_Level", on_Level, {persist = false})
      end
      print("Turn On >>>>>>>>>>>>>>>>")
      if device.preferences.onTransTime == 0 then
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), 0xFFFF))
      else
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), device.preferences.onTransTime * 10)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(on_Level/100.0 * 254), math.floor(device.preferences.onTransTime * 10)))
      end
      device:send(OnOff.server.commands.On(device))
      --device:emit_event(attr.on()) -- removed for no false  Online

      --if device:get_field("zll_xy") == "yes" then
        device.thread:call_with_delay(3 + device.preferences.onTransTime, function(d)
          --device:emit_event(attr.on()) -- removed for no false Online
          if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
            device:refresh()
          end
        end)
      --end
    elseif circadian[device] == "Active" then
        set_status_timer = device:get_field("timer_circadian")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancelando Circadian timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_circadian", nil)
          circadian_Running[device] = "stopped"
          device:set_field("circadian_Running[device]", "stopped", {persist = false})
        end
      driver_handler.circadian_handler(driver, device)
    end
  end
 
  -----------------------------------------
  ------------ TURN OFF handler -----------
  
function driver_handler.off_handler (driver, device, command)
  print("Turn Off handler >>>>>>>>>>>")
  -- set to no jump the dimming
  dimJump[device] = "no"
  -- save last level
  local last_Level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
  print("<<< last_Level:",last_Level)
  -- detect if forced Level actived
  if device:get_field("forced_Level") > 0 then
      last_Level = device:get_field("forced_Level")
  end
  device:set_field("last_Level", last_Level, {persist = false})
  
   ---deactivate color Continous Change
  if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
    device:set_field("colorChanging_timer", "stopped", {persist = false})
    local child_device = device:get_child_by_parent_assigned_key("main")
    if child_device ~= nil then
      child_device:set_field("colorChanging_timer", "stopped", {persist = false})
    end

    set_status_timer = device:get_field("timer_color")
    if set_status_timer then
      if device.preferences.logDebugPrint == true then
        print("<<<<< Cancel Color Changing timer >>>>>")
      end
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_color", nil)
    end
  end

  -- capability reference
  local attr = capabilities.switch.switch

      -- detect switch Pushsed when progressive On or Off running ---
  if onStatus[device] == "running" or offStatus[device] == "running" then

    ---- Cancel Timers
    local timer = device:get_field("timer_progOn")
    if timer then
      if device.preferences.logDebugPrint == true then
        print("<<< Cancel Prog On timer >>>")
      end
      device.thread:cancel_timer(timer)
      device:set_field("timer_progOn", nil)
    end
    timer = device:get_field("timer_progOff")
    if timer then
      if device.preferences.logDebugPrint == true then
        print("<<< Cancel Prog Off timer >>>")
      end
      device.thread:cancel_timer(timer)
      device:set_field("timer_progOff", nil)
    end 

     -- progressive Off is running
    if offStatus[device] == "running" then
      offStatus[device]="stopped"
      device:set_field("offStatus", offStatus[device], {persist = true})
      device:emit_event(attr.off())
      if (device.preferences.ifPushSwitch == "Change") then
        device:emit_event(attr.on())
        if progOn[device] == "Active" then
          device:emit_event(attr.on())
          onStartDim[device] = -1
          driver_handler.on_handler(driver,device, onStartDim[device])
          offJump[device]="yes"
        end
        dimJump[device] ="yes" 
      else
        dimJump[device] ="yes"
        offJump[device] = "yes"
        if (device.preferences.ifPushSwitch == "Off")  then device:send(OnOff.server.commands.Off(device))end
        if (device.preferences.ifPushSwitch == "End") then
          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor((device.preferences.offLevelEnd+0.1)/100.0 * 254), 0xFFFF)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor((device.preferences.offLevelEnd+0.1)/100.0 * 254), 0xFFFF))
          device:emit_event(attr.on())
          device:send(zcl_clusters.OnOff.attributes.OnOff:read(device))
        end
        if (device.preferences.ifPushSwitch == "Stop") then device:emit_event(attr.on()) end
      end
    else
      --- progressive On is running
      onStatus[device]="stopped"
      device:set_field("onStatus", onStatus[device], {persist = false})
      device:emit_event(attr.off())
      if (device.preferences.ifPushSwitch == "Change") then
       if progOff[device] == "Active" then
        device:emit_event(attr.on())
        offJump[device] = "yes"
        dimJump[device] = "no"
       else
        dimJump[device] = "yes"
       end
      else   
        dimJump[device] = "yes"
        if (device.preferences.ifPushSwitch == "End") then
          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(device.preferences.onLevelEnd /100.0 * 254), 0xFFFF)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device.preferences.onLevelEnd / 100.0 * 254), 0xFFFF))
          offJump[device] = "yes"
          device:emit_event(attr.on())
        else
          if device.preferences.ifPushSwitch == "Stop" then offJump[device] = "yes" end
          device:emit_event(attr.on())
        end 
      end 
    end
  end 
  
  ---- detect progressive turn OFF is activated -----
  if (onStatus[device] == "stopped" and offStatus[device] == "stopped" and circadian[device] == "Inactive") then
      ---- dimJump is "no" because need change direction of dimming
    if progOff[device]  ==  "Active" and dimJump[device]== "no" then 
      if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) <= device.preferences.offLevelEnd then     
        if offStatus[device] =="stopped" and onStatus[device] =="stopped" then offJump[device] = "no" end
      elseif offStatus[device] =="stopped" then

        -- OFF timer calculation
        offLevelStart[device] = math.floor(device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
        local diff_level = device.preferences.offLevelEnd - offLevelStart[device]
        if diff_level == 0 then 
            offTimer[device] = 1
        else
            offTimer[device] = math.abs(device.preferences.offTimeMax * 60 / diff_level)
            if offTimer[device] < 0.3 then offTimer[device] = 0.3 end
        end
        offTotalSteps[device] = math.floor(device.preferences.offTimeMax * 60 / offTimer[device])
        offStepLevel[device] = ((offLevelStart[device]+ 0.1) - device.preferences.offLevelEnd) / offTotalSteps[device]
        if device.preferences.logDebugPrint == true then
            print("<< offTimer =",offTimer[device])
            print("<< offLevelStart =",offLevelStart[device])
            print ("turnOff.offTotalSteps =", offTotalSteps[device])
            print ("turnOff.offStepLevel =", offStepLevel[device])
        end
        offStepLevel[device] = ((offLevelStart[device]+ 0.1)- device.preferences.offLevelEnd) / offTotalSteps[device]

        offStep[device] = 0
        offStatus[device] ="running"
        device:set_field("offStatus", offStatus[device], {persist = true})

        offNewLevel[device] =  offLevelStart[device]
        offStep[device] = offStep[device] + 1
        device:emit_event(attr.off())
        device:send(OnOff.server.commands.On(device))
        device:emit_event(attr.on())
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
        --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF))

      --- Start timer for dimming off ------
      set_status_timer = device.thread:call_on_schedule(offTimer[device], 
        function ()
          if offStatus[device] =="running" then
            offStep[device] = offStep[device] + 1 
            offNewLevel[device] = (offNewLevel[device] - offStepLevel[device])
            if device.preferences.logDebugPrint == true then
              print("offStep=", offStep[device])
            end
            if offNewLevel[device] <= device.preferences.offLevelEnd or offStep[device] >= offTotalSteps[device] then 
              offNewLevel[device] = device.preferences.offLevelEnd
              offStatus[device] ="stopped"
              device:set_field("offStatus", offStatus[device], {persist = true})

              -- Cancel timer
              local timer = device:get_field("timer_progOff")
              if timer then
                if device.preferences.logDebugPrint == true then
                  print("<<< Cancel Prog Off timer >>>")
                end
                device.thread:cancel_timer(timer)
                device:set_field("timer_progOff", nil)
              end
            end
            
            if device.preferences.logDebugPrint == true then
              print ("turnOff.offNewLevel=",offNewLevel[device])
            end
            command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF)
            if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
              command1.body.zcl_body.options_mask = nil
              command1.body.zcl_body.options_override = nil
            end
            device:send(command1)
            --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF))

            ---- Change Temp Color if option activated -----
            if device.preferences.progLevelColor == "Yes" then
              local colorTemp =  math.floor((utils.round(onNewLevel[device])/100 * ((device.preferences.colorTempMaxim) - device.preferences.colorTempMinim)) + device.preferences.colorTempMinim)
              device:set_field(LAST_KELVIN_SET .. "main", colorTemp)
              local colorTemp_Mireds = utils.round(1000000 / colorTemp)
              --print("Color Temp K;  colorTemp Mired", math.floor(colorTemp), colorTemp_Mireds)
              device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
              device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
            end
          end
        end)
        device:set_field("timer_progOff", set_status_timer)
      end
    end
  end
  
   -- send status Off if needed
    if offJump[device] == "no" and (offStatus[device] == "stopped" and onStatus[device] == "stopped") then
      if progOff[device]  ==  "Inactive" or device.preferences.ifPushSwitch == "Off" or offJump[device] == "no" then
        print("Turn OFF >>>>>>>>>>>>>>>>")
          -- send zigbee event
        if device.preferences.onTransTime == 0 or device:get_field("effects_set_command") ~= "Inactive" then
          device:send(OnOff.server.commands.Off(device))
          --device:emit_event(attr.off()) -- removed for no false Online
        else
          local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(0.1/100.0 * 254), device.preferences.onTransTime * 10)
          if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
            command1.body.zcl_body.options_mask = nil
            command1.body.zcl_body.options_override = nil
          end
          device:send(command1)
          --device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(0.1/100.0 * 254), math.floor(device.preferences.onTransTime * 10)))
        end

       ---- Cancel Timers
        set_status_timer = device:get_field("timer_color")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancel Color Changing timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_color", nil)
          device:set_field("colorChanging_timer", "stopped", {persist = false})
          local child_device = device:get_child_by_parent_assigned_key("main")
          if child_device ~= nil then
            child_device:set_field("colorChanging_timer", "stopped", {persist = false})
          end
        end
        set_status_timer = device:get_field("timer_progOn")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancelando ProgOn timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_progOn", nil)
          onStatus[device] ="stopped"
          device:set_field("onStatus", onStatus[device], {persist = false})
        end
        set_status_timer = device:get_field("timer_progOff")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancelando ProgOff timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_progOff", nil)
          offStatus[device] ="stopped"
          device:set_field("offStatus", offStatus[device], {persist = true})
        end
        set_status_timer = device:get_field("timer_circadian")
        if set_status_timer then
          if device.preferences.logDebugPrint == true then
            print("<<<<< Cancelando Circadian timer >>>>>")
          end
          device.thread:cancel_timer(set_status_timer)
          device:set_field("timer_circadian", nil)
          circadian_Running[device] = "stopped"
          device:set_field("circadian_Running[device]", "stopped", {persist = false})
        end
      end
      --if device:get_field("zll_xy") == "yes" then
        device.thread:call_with_delay(3 + device.preferences.onTransTime, function(d)
          if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "off" then
            device:refresh()
          end
        end)
      --end
    end

    offJump[device] = "no"
    dimJump[device]= "no"
  end

---- On-Off Emit event
function driver_handler.on_off_attr_handler(driver, device, value, zb_rx)
  if device.preferences.logDebugPrint == true then
    print("<<<<< Emit on_off >>>>>>")
  end
  --print("table zb_rx >>>>>>",utils.stringify_table(zb_rx))

  --print("LQI >>>>>",zb_rx.lqi.value)
  --print("RSSI >>>>>",zb_rx.rssi.value)
  --print (string.format("src_Address: 0x%04X", zb_rx.address_header.src_addr.value))

   ---deactivate color Continous Change  
  if value.value == false then
    if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:set_field("colorChanging_timer", "stopped", {persist = false})
      local child_device = device:get_child_by_parent_assigned_key("main")
      if child_device ~= nil then
        child_device:set_field("colorChanging_timer", "stopped", {persist = false})
      end

      set_status_timer = device:get_field("timer_color")
      if set_status_timer then
        --print("<<<<< Cancel Color Changing timer >>>>>")
        device.thread:cancel_timer(set_status_timer)
        device:set_field("timer_color", nil)
      end
    end
    set_status_timer = device:get_field("timer_progOn")
    if set_status_timer then
      print("<<<<< Cancelando ProgOn timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_progOn", nil)
      onStatus[device] ="stopped"
      device:set_field("onStatus", onStatus[device], {persist = false})
    end
    set_status_timer = device:get_field("timer_progOff")
    if set_status_timer then
      --print("<<<<< Cancelando ProgOff timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_progOff", nil)
      offStatus[device] ="stopped"
      device:set_field("offStatus", offStatus[device], {persist = true})
    end
    set_status_timer = device:get_field("timer_circadian")
    if set_status_timer then
      --print("<<<<< Cancelando Circadian timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_circadian", nil)
      circadian_Running[device] = "stopped"
      device:set_field("circadian_Running[device]", "stopped", {persist = false})
    end
    set_status_timer = device:get_field("timer_blink")
    if set_status_timer then
      --print("<<<<< Cancel Blink timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_blink", nil)
    end
  end

  local visible_satate = false
  if device.preferences.signalMetricsVisibles == "Yes" then
    visible_satate = true
  end
  
  if os.time() - last_signal_emit_time > 22 then
    local gmt = os.date("%Y/%m/%d Time: %H:%M",os.time() + device.preferences.localTimeOffset * 3600)
    --local dni = string.format("0x%04X", zb_rx.address_header.src_addr.value)
    --local metrics = "<em table style='font-size:75%';'font-weight: bold'</em>".. "<b>GMT: </b>".. gmt .."<BR>"
    --metrics = metrics .. "<b>DNI: </b>".. dni .. "  ".."<b> LQI: </b>" .. zb_rx.lqi.value .."  ".."<b>RSSI: </b>".. zb_rx.rssi.value .. "dbm".."</em>".."<BR>"
    local metrics = gmt .. ", LQI: ".. zb_rx.lqi.value .." ... rssi: ".. zb_rx.rssi.value
    last_signal_emit_time = os.time()
    device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))
  end

  local attr = capabilities.switch.switch
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, value.value and attr.on() or attr.off())

  --emit event in child device
  local child_device = device:get_child_by_parent_assigned_key("main")
  if child_device ~= nil and device:get_field("mirror_group_function") == "Active" and child_device:get_field("mirror_group_function") == "Active" then
    child_device:emit_event(value.value and attr.on() or attr.off())
  end
end
-----------------------------------------------
--------- effects_Set_Command_handler ---------

function driver_handler.effects_Set_handler(driver, device, command, group)

  local effects_set_command = "Inactive"
  if command == "Continue" then 
    effects_set_command = device:get_field("effects_set_command")
    --print("<<< command:", command)
  else
    effects_set_command = command.args.value
    --print("<<< command.args.value:", command.args.value)
  end

  ---- Blink Timers Cancel ------
  set_status_timer = device:get_field("timer_blink")
  if set_status_timer then
    --print("<<<<< Cancel Blink timer >>>>>")
    device.thread:cancel_timer(set_status_timer)
    device:set_field("timer_blink", nil)
  end

  device:emit_event(effects_Set_Command.effectsSetCommand(effects_set_command))
  device:set_field("effects_set_command", effects_set_command, {persist = false})

  local blink_time
  if effects_set_command ~= "Inactive" then

    if device:supports_capability_by_id(capabilities.colorControl.ID) and device:get_field("colorChanging") == "Active" then
      device:set_field("colorChanging_timer", "stopped", {persist = false})
      local child_device = device:get_child_by_parent_assigned_key("main")
      if child_device ~= nil then
        child_device:set_field("colorChanging_timer", "stopped", {persist = false})
      end

      set_status_timer = device:get_field("timer_color")
      if set_status_timer then
        --print("<<<<< Cancel Color Changing timer >>>>>")
        device.thread:cancel_timer(set_status_timer)
        device:set_field("timer_color", nil)
      end
    end

    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) ~= "on" then
      if device:get_field("last_Level") == nil or device:get_field("last_Level") < 1 then device:set_field("last_Level", device.preferences.onLevelEnd, {persist = false}) end
      local on_Level = device:get_field("last_Level")

      -- detect if forced Level actived
      if device:get_field("forced_Level") > 0 then
          on_Level = device:get_field("forced_Level")
          device:set_field("last_Level", on_Level, {persist = false})
      end
      print("Blink Turn On >>>>>>>>>>>>>>>>")
        local command1 = zcl_clusters.Level.commands.MoveToLevelWithOnOff(device,  math.floor(on_Level/100.0 * 254), 0xFFFF)
        if device:get_manufacturer() == "TCPi" or device:get_manufacturer() == "DURAGREEN" or device:get_model() == "Classic A60 W clear - LIGHTIFY" then
          command1.body.zcl_body.options_mask = nil
          command1.body.zcl_body.options_override = nil
        end
        device:send(command1)
      device:send(zcl_clusters.OnOff.server.commands.On(device))
    end

    -- initialize timer_blink function
    if device:get_manufacturer() == "OSRAM" then
      device:send(zcl_clusters.Identify.commands.Identify(device, 1)) -- command blink with time 1 sec
    else 
      device:send(zcl_clusters.Identify.commands.TriggerEffect(device, 0x00,0x00)) -- 0x00 start effect -- effect BREATHE = 0x01, BLINK = 0x00
    end

    if effects_set_command == "BlinkON" then -- is Blink Fast
      blink_time = 2

    elseif effects_set_command == "BlinkSlow" then
      blink_time = 5

    elseif effects_set_command == "BlinkCustom" then
      blink_time = device.preferences.blinkTimer
      if blink_time == nil then blink_time = 3 end
    end

  -- initialize timer_blink function
    --device:send(zcl_clusters.Identify.commands.TriggerEffect(device, 0x00,0x00))

    set_status_timer = device.thread:call_on_schedule(blink_time,
    function ()
      --device:send(zcl_clusters.Identify.commands.TriggerEffect(device, 0x00,0x00)) -- BREATHE = 0x01, BLINK = 0x00
      if device:get_manufacturer() == "OSRAM" then
        device:send(zcl_clusters.Identify.commands.Identify(device, 1)) -- command blink with time 1 sec
      else
        device:send(zcl_clusters.Identify.commands.TriggerEffect(device, 0x00,0x00)) -- start effect
      end
    end,
    "blink")
    device:set_field("timer_blink", set_status_timer)

  elseif effects_set_command == "Inactive" then

    if device:get_manufacturer() == "OSRAM" then
      device:send(zcl_clusters.Identify.commands.Identify(device, 0)) -- command blink with time 0 sec
    else 
      device:send(zcl_clusters.Identify.commands.TriggerEffect(device, 0xFF,0x00)) -- 0xFF stop effect
    end

    ---- Blink Timers Cancel ------
    set_status_timer = device:get_field("timer_blink")
    if set_status_timer then
      --print("<<<<< Cancel Blink timer >>>>>")
      device.thread:cancel_timer(set_status_timer)
      device:set_field("timer_blink", nil)
    end

    --- restart Circadian timer if activated
    if circadian_Running[device] == "running" and circadian[device] == "Active" then
      driver_handler.circadian_handler(driver, device)
    end

    --- restart prog-On if is running
    if device:get_field("onStatus") == "running" then
      onStartDim[device] = -1 -- this value will made continue the dimming On with last level
      onStatus[device] ="stopped"
      driver_handler.on_handler (driver, device, onStartDim[device])
    end

    --- restart prog-Off if is running
    if device:get_field("offStatus") == "running" then
      offStatus[device] ="stopped"
      driver_handler.off_handler (driver, device, "off")
    end
    
    --- ReStart Timer color chanaging function
    if device:supports_capability_by_id(capabilities.colorControl.ID) then
      if device:get_field("colorTimer") == nil then
        device:set_field("colorTimer", 2 , {persist = false})
        device:emit_event(color_Change_Timer.colorChangeTimer(2))
      end
  
      if device:get_field("colorChangeModeList") == nil then
        device:set_field("colorChangeModeList", "Random", {persist = false})
        device:emit_event(color_Change_Mode.colorChangeMode("Random"))
      end
  
      if device:get_field("colorChanging") == "Active" then
        device:set_field("colorChanging_timer", "stopped", {persist = false})
        if group == true then
          local child_device = device:get_child_by_parent_assigned_key("main")
          if child_device ~= nil then
            driver_handler.color_Changing_timer_on(driver, device, command, group)
          end
        else 
          driver_handler.color_Changing_timer_on(driver, device, command, group)
        end
        -- driver_handler.color_Changing_timer_on(driver, device, "Continue", group)
      else
        device:emit_event(color_Changing.colorChanging("Inactive"))
      end
    end
  
    --- restart random on-off if active
    if device.preferences.logDebugPrint == true then
      print("random_state >>>>>",device:get_field("random_state"))
    end
    if device:get_field("random_state") == "Active" then  
      driver_handler.random_on_off_handler(driver,device,"Active")
    end
  end
  --device:send(zcl_clusters.ColorControl.commands.ColorLoopSet(device, 0xFF,0x01,0x01,0xFFFF, 0x01, 0x00, 0x00)) -- command Colorloop
  --device:send(zcl_clusters.Identify.commands.Identify(device, 15)) -- command blink with time 15 sec
end

  return driver_handler