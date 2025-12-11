--- M. Colmenarejo 2024
--- Smartthings library load ---
local capabilities = require "st.capabilities"
local log = require "log"
local utils = require "st.utils"

--local command_handlers = require "command_handlers"
local random = require "virtual-mirror-switch.random"

-- Custom Capability Randon On Off
local mirror_In = capabilities["legendabsolute60149.mirrorIn"]
local mirror_Out = capabilities["legendabsolute60149.mirrorOut"]
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]


-- refresh handler
local function device_refresh(driver, device, command)
  if device.preferences.changeProfile ~= "Switch" then
   device:emit_event(mirror_Out.mirrorOut({value = device:get_latest_state("main", mirror_Out.ID, mirror_Out.mirrorOut.NAME)}, {visibility = {displayed = false }}))
    device:emit_event(mirror_In.mirrorIn({value = device:get_latest_state("main", mirror_In.ID, mirror_In.mirrorIn.NAME)}, {visibility = {displayed = false }}))
  end
  device:emit_event(capabilities.switch.switch({value = device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME)}, {visibility = {displayed = false }}))
end

local function device_init(driver, device) 
  log.info("[" .. device.id .. "] Initializing Virtual Device")

  -- mark device as online so it can be controlled from the app
  device:online()

  -- provisioning_state = "PROVISIONED"
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })

  if device.model ~= "Virtual Switch Mirror" then
    device:try_update_metadata({ model = "Virtual Switch Mirror" })
    device.thread:call_with_delay(5, function() 
      print("<<<<< model= ", device.model)
    end)
  end

  -- initialize selected profile
  --if device.preferences.mirrorMain == "Yes" then
    --print("<<< main-virtual-device >>>")
    --device:try_update_metadata({profile = "main-virtual-device"})
  --end
  if device.preferences.changeProfile == "Mirror" then
    print("<<< Profile virtual-only-mirror >>>")
    --device:try_update_metadata({profile = "virtual-only-mirror"})
  elseif device.preferences.changeProfile == "MirrorSwitch" then
    print("<<< Profile virtual-switch-mirror >>>")
    --device:try_update_metadata({profile = "virtual-switch-mirror"})
  elseif device.preferences.changeProfile == "Switch" then
    print("<<< Profile virtual-only-switch >>>")
    --device:try_update_metadata({profile = "virtual-only-switch"})
  end

  -- initialize random on-off
  local cap_status = device:get_latest_state("main", random_On_Off.ID, random_On_Off.randomOnOff.NAME)
  if cap_status == nil then
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    device:set_field("random_state", "Inactive", {persist = false})
  else
    device:set_field("random_state", cap_status, {persist = false})
    cap_status = device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
      if cap_status == nil then
        device:emit_event(random_Next_Step.randomNext("Inactive"))
      end
      if cap_status ~= "Inactive" then
        -- convert string next change to seconds of date type
        local date = device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
        local hour = tonumber(string.sub (date, 1 , 2))
        local min = tonumber(string.sub (date, 4 , 5))
        local sec = tonumber(string.sub (date, 7 , 8))
        local year = tonumber(os.date("%Y", os.time() + device.preferences.localTimeOffset * 3600))
        local month = tonumber(os.date("%m", os.time() + device.preferences.localTimeOffset * 3600))
        local day = tonumber(os.date("%d", os.time() + device.preferences.localTimeOffset * 3600))
        local time = os.time({ day = day, month = month, year = year, hour = hour, min = min, sec = sec})
        if device.preferences.logDebugPrint == true then
          print("<<< date:", date)
          print("<<< date:", year, month, day, hour, min, sec)
          print("<<< date formated >>>", os.date("%Y/%m/%d %H:%M:%S",time))
        end
        device:set_field("time_nextChange", time, {persist = false})
      end
    end

    --restart random on-off if active
    print("random_state >>>>>",device:get_field("random_state"))
    if device:get_field("random_state") ~= "Inactive" then
      random.random_on_off_handler(driver, device,"Active")
    end

  device.thread:call_with_delay(2, function() device_refresh(driver, device) end)
end

-- addded new device
local function device_added(driver, device,command)
  log.info("[" .. device.id .. "] Adding new Virtual Device")

  device:emit_event(capabilities.switch.switch.off())
  if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
    device:emit_event(mirror_Out.mirrorOut({value ="Off"}, {visibility = {displayed = false }}))
    device:emit_event(mirror_In.mirrorIn({value ="Off"}, {visibility = {displayed = false }}))
  end
end

local virtual_mirror_switch = {
	NAME = "virtual mirror switch",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_refresh,
    },
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
  },

  can_handle = require("virtual-mirror-switch.can_handle")
}
return virtual_mirror_switch