--- M. Colmenarejo 2024
--- Smartthings library load ---
local capabilities = require "st.capabilities"
local log = require "log"

--local timer_days = {}

-- Custom Capability Randon On Off
local timer_For_Number_Of_Days = capabilities["legendabsolute60149.timerForNumberOfDays"]
local timer_Next_Change = capabilities["legendabsolute60149.timerNextChange"]
local local_Hour_Offset = capabilities["legendabsolute60149.localHourOffset"]


--- Timer for days timer
local function timer_days_calculation(driver, device)

  ---- Timers Cancel ------
  local days_timer = device:get_field("days_timer")
  if days_timer ~= nil then
    print("<<<<< Cancel days_timer >>>>>")
    driver:cancel_timer(days_timer)
    device:set_field("days_timer", nil)
  end

  print("<< Timer activation >>")

 -- calculate timer value
  local timer_value
  local set_next_timer_change = device:get_field("set_next_timer_change")
  if set_next_timer_change == 0 then
    local next_change_event = os.date("%Y/%m/%d", os.time() + (device:get_field("setLocalHourOffset") * 3600) + (device:get_field("set_timer_days") * 24 * 3600))
    next_change_event = next_change_event .. " -> 00:00"
    device:emit_event(timer_Next_Change.timerNextChange(next_change_event))

    local hour = 0
    local min = 0
    local sec = 0
    local year = tonumber(string.sub (next_change_event, 1 , 4))
    local month = tonumber(string.sub (next_change_event, 6 , 7))
    local day = tonumber(string.sub (next_change_event, 9 , 10))
    local time = os.time({ day = day, month = month, year = year, hour = hour, min = min, sec = sec})
    
    device:set_field("set_next_timer_change", time, {persist = false})
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "off" then
      device:set_field("set_switch_off_time", time + (24 * 3600), {persist = false})
    end
    set_next_timer_change = device:get_field("set_next_timer_change")

    timer_value = set_next_timer_change - (os.time() + (device:get_field("setLocalHourOffset") * 3600))

    if device.preferences.logDebugPrint == true then
      print("<<< date:", next_change_event)
      print("<<< date:", year, month, day, hour, min, sec)
      print("<<< date formated >>>", os.date("%Y/%m/%d %H:%M:%S",time))
      print("<<< timer_value:", timer_value)
      print("<<< set_switch_off_time >>>", os.date("%Y/%m/%d %H:%M", device:get_field("set_switch_off_time")))
    end

  else -- this case timer was stopped due to driver init or hub reboot
    set_next_timer_change = device:get_field("set_next_timer_change")
    timer_value = set_next_timer_change - (os.time() + (device:get_field("setLocalHourOffset") * 3600))
    if timer_value <= 0 then timer_value = 0.5 end

    if device.preferences.logDebugPrint == true then
      print("<<< timer_value:", timer_value)
      print("<<< set_switch_off_time >>>", os.date("%Y/%m/%d %H:%M", device:get_field("set_switch_off_time")))
    end
  end
  
  ------ Days Timer activation
  days_timer = device.thread:call_with_delay(
    timer_value,
  function ()
    print("<<< Timer Day Check >>>")

    local local_time = os.time() + (device:get_field("setLocalHourOffset") * 3600)
    local timer_to_off = (24 * 3600)
    if device:get_field("set_timer_days") == 1 then
      device:set_field("set_switch_off_time", set_next_timer_change + (24 * 3600), {persist = false})
      device:emit_event(capabilities.switch.switch.on())
      device.thread:call_with_delay(1, function(d) device:emit_event(capabilities.switch.switch.off()) end)
      device.thread:call_with_delay(2, function(d) device:emit_event(capabilities.switch.switch.on()) end)
    else
      if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
        if local_time < device:get_field("set_switch_off_time") then
          timer_to_off = device:get_field("set_switch_off_time") - local_time
        else
          timer_to_off = 0
          device:emit_event(capabilities.switch.switch.off())
        end 
      else
        device:emit_event(capabilities.switch.switch.on())
        device:set_field("set_switch_off_time", set_next_timer_change + (24 * 3600), {persist = false})
      end

      if device.preferences.logDebugPrint == true then
        print("<<< set_switch_off_time >>>", os.date("%Y/%m/%d %H:%M", device:get_field("set_switch_off_time")))
      end

    -- turn off switch after 24 hours on
      ---- Timer Cancel ------
      local off_timer = device:get_field("off_timer")
      if off_timer ~= nil then
        print("<<<<< Cancel off_timer >>>>>")
        driver:cancel_timer(off_timer)
        device:set_field("off_timer", nil)
      end
      off_timer = device.thread:call_with_delay(
        timer_to_off,
      function ()
        if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
          device:emit_event(capabilities.switch.switch.off())
        end
        device:set_field("off_timer", nil)
      end)
      device:set_field("off_timer", off_timer)
    end
    -- set next timer day change
    device:set_field("set_next_timer_change", 0, {persist = false})
    device:set_field("days_timer", nil)
    timer_days_calculation(driver, device)

  end
  ,'days_timer')
  device:set_field("days_timer", days_timer)

end

-- added and refresh device
local function device_added(driver, device)
  print("<<< Virtual timer_days: device_added >>>")

  if device:get_field("setLocalHourOffset") == nil then
    device:set_field("setLocalHourOffset", 0, {persist = false})
  end
  device:emit_event(local_Hour_Offset.localHourOffset({value = device:get_field("setLocalHourOffset"),  unit = "hr"}))

  if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    device:emit_event(capabilities.switch.switch.on())
  else
    device:emit_event(capabilities.switch.switch.off())
  end

  local set_timer_days = device:get_latest_state("main", timer_For_Number_Of_Days.ID, timer_For_Number_Of_Days.timerForNumberOfDays.NAME)
  if set_timer_days == nil then
    set_timer_days = 0
    device:emit_event(capabilities.switch.switch.off())
  end

  local next_change_event = device:get_latest_state("main", timer_Next_Change.ID, timer_Next_Change.timerNextChange.NAME)
  if next_change_event == nil then
    next_change_event = "Inactive"
  end

  local set_next_timer_change = device:get_field("set_next_timer_change")
  if set_next_timer_change == nil then
    set_next_timer_change = 0
  end

  device:set_field("set_timer_days", set_timer_days, {persist = false})
  device:set_field("set_next_timer_change", set_next_timer_change, {persist = false})


  device:emit_event(timer_For_Number_Of_Days.timerForNumberOfDays(set_timer_days))
  device:emit_event(timer_Next_Change.timerNextChange(next_change_event))

  -- init timer if days > 0
  if device:get_field("set_timer_days") > 0 then
    timer_days_calculation(driver, device)
  else
    ---- Timers Cancel ------
    for timer in pairs(device.thread.timers) do
      print("<<<<< Cancel all timer >>>>>")
      device.thread:cancel_timer(timer)
    end
  end

end
--------------------------------------------------------
 --------- Handler timer_For_Number_Of_Days ------------------------

local function setTimerForNumberOfDays_handler(driver, device, command)
  print("<<< command.args.value >>>",command.args.value)

  local set_timer_days = command.args.value
  device:emit_event(capabilities.switch.switch.off())
  if set_timer_days == 0 then
    local next_change_event = "Inactive"
    --device:emit_event(capabilities.switch.switch.off())
    device:emit_event(timer_Next_Change.timerNextChange(next_change_event))
  end

  device:set_field("set_timer_days", set_timer_days, {persist = false})
  device:set_field("set_next_timer_change", 0, {persist = false})

  device:emit_event(timer_For_Number_Of_Days.timerForNumberOfDays(set_timer_days))

-- init timer if days > 0
  if device:get_field("set_timer_days") > 0 then 
    timer_days_calculation(driver, device)
  else
    ---- Timers Cancel ------
    for timer in pairs(device.thread.timers) do
      print("<<<<< Cancel all timer >>>>>")
      device.thread:cancel_timer(timer)
    end
  end

end

--local_Hour_Offset_handler
local function local_hour_offset_handler(driver, device, command)
  --print("<<<<<<< local hour days >>>>>>>>")
  device:set_field("setLocalHourOffset", command.args.value, {persist = false})
  device:emit_event(local_Hour_Offset.localHourOffset({value = command.args.value,  unit = "hr"}))

  local query = function()
    device_added(driver, device)
  end
  device.thread:call_with_delay(2, query)
end

local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing Virtual Device")

  -- mark device as online so it can be controlled from the app
  device:online()

  -- provisioning_state = "PROVISIONED"
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
  if device.model ~= "Virtual Timer Days" then
    device:try_update_metadata({ model = "Virtual Timer Days" })
    device.thread:call_with_delay(5, function() 
      print("<<<<< model= ", device.model)
    end)
  end

  --initialize local hour
  local cap_status = device:get_latest_state("main", local_Hour_Offset.ID, local_Hour_Offset.localHourOffset.NAME)
  if cap_status == nil then 
    cap_status = 0 
    device:emit_event(local_Hour_Offset.localHourOffset({value = cap_status,  unit = "hr"}))
  end
  device:set_field("setLocalHourOffset",cap_status, {persist = false})

  -- timer for Days re-start timer if was stopped by a reboot
  cap_status = device:get_latest_state("main", timer_Next_Change.ID, timer_Next_Change.timerNextChange.NAME)
  --"2024/04/11 -> 15:39:14"
  if cap_status == nil or cap_status == "Inactive" then
    device:set_field("set_next_timer_change", 0, {persist = false})
    if cap_status == nil then cap_status = "Inactive" end
  elseif cap_status ~= "Inactive" then
    -- convert string next change to seconds of date type
    local hour = tonumber(string.sub (cap_status, 15 , 16))
    local min = tonumber(string.sub (cap_status, 18 , 19))
    --local sec = tonumber(string.sub (cap_status, 21 , 22))
    local sec = 0
    local year = tonumber(string.sub (cap_status, 1 , 4))
    local month = tonumber(string.sub (cap_status, 6 , 7))
    local day = tonumber(string.sub (cap_status, 9 , 10))
    local time = os.time({ day = day, month = month, year = year, hour = hour, min = min, sec = sec})
    
    device:set_field("set_next_timer_change", time, {persist = false})
    device:set_field("set_switch_off_time", time + (24 * 3600), {persist = false})
    if device.preferences.logDebugPrint == true then
      print("<<< date:", cap_status)
      print("<<< date:", year, month, day, hour, min, sec)
      print("<<< date formated >>>", os.date("%Y/%m/%d %H:%M:%S",time))
      print("<<< set_switch_off_time >>>", os.date("%Y/%m/%d %H:%M", device:get_field("set_switch_off_time")))
    end
  end
  device:emit_event(timer_Next_Change.timerNextChange(cap_status))

  local local_time = os.time() + (device:get_field("setLocalHourOffset") * 3600)
  local timer_to_off = (24 * 3600)
  local set_timer_days = device:get_latest_state("main", timer_For_Number_Of_Days.ID, timer_For_Number_Of_Days.timerForNumberOfDays.NAME)
  if set_timer_days == nil then
    set_timer_days = 0
  end
  if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      if set_timer_days > 1 then
        local set_switch_off_time = device:get_field("set_next_timer_change") - ((set_timer_days -1) * 24 * 3600)
        device:set_field("set_switch_off_time", set_switch_off_time, {persist = false})
      end
      if local_time < device:get_field("set_switch_off_time") then
        timer_to_off = device:get_field("set_switch_off_time") - local_time
      else
        timer_to_off = 0
        device:emit_event(capabilities.switch.switch.off())
      end
      if device.preferences.logDebugPrint == true then
        print("<<< timer_to_off:", timer_to_off)
        print("<<< set_switch_off_time >>>", os.date("%Y/%m/%d %H:%M", device:get_field("set_switch_off_time")))
      end

      -- turn off switch after 24 hours on
      ---- Timer Cancel ------
      local off_timer = device:get_field("off_timer")
      if off_timer ~= nil then
        print("<<<<< Cancel off_timer >>>>>")
        driver:cancel_timer(off_timer)
        device:set_field("off_timer", nil)
      end
      off_timer = device.thread:call_with_delay(
        timer_to_off,
      function ()
        if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
          device:emit_event(capabilities.switch.switch.off())
        end
        device:set_field("off_timer", nil)
      end)
      device:set_field("off_timer", off_timer)
    --end
  end

  device_added(driver, device)
end


local virtual_timer_days = {
	NAME = "virtual timer days",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_added,
    },
    [local_Hour_Offset.ID] = {
      [local_Hour_Offset.commands.setLocalHourOffset.NAME] = local_hour_offset_handler,
    },
    [timer_For_Number_Of_Days.ID] = {
      [timer_For_Number_Of_Days.commands.setTimerForNumberOfDays.NAME] = setTimerForNumberOfDays_handler,
    },
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
  },

  can_handle = require("virtual-timer-days.can_handle")
}
return virtual_timer_days