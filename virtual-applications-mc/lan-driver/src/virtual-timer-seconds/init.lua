--- Smartthings library load ---
local capabilities = require "st.capabilities"
local log = require "log"
local utils = require "st.utils"

--local timer_for_seconds = {}

-- Custom Capability Randon On Off
local timer_Next_Change = capabilities["legendabsolute60149.timerNextChange"]
local local_Hour_Offset = capabilities["legendabsolute60149.localHourOffset"]
local timer_Seconds = capabilities["legendabsolute60149.timerSeconds"]
local timer_Type = capabilities["legendabsolute60149.timerType"]
local random_Minimum_Timer = capabilities["legendabsolute60149.randomMinimumTimer"]
local random_Maximum_Timer = capabilities["legendabsolute60149.randomMaximumTimer"]
local loops_Number = capabilities["legendabsolute60149.loopsNumber"]
local current_Loop = capabilities["legendabsolute60149.currentLoop"]
local reset_button = capabilities["legendabsolute60149.resetbutton"]

local can_handle = function(opts, driver, device)
  if device.preferences.switchNumber == 10 then
    local subdriver = require("virtual-timer-seconds")
    return true, subdriver
  else
    return false
  end  
end

local function timer_cancel(driver, device)
  print("<<< timer_cancel function >>>")

  device:emit_event(capabilities.switch.switch.off())
  device:emit_event(timer_Next_Change.timerNextChange("Inactive"))
  device:set_field("set_next_timer_change", 0, {persist = false})

  device:set_field("set_current_Loop", 0, {persist = false})
  device:emit_event(current_Loop.currentLoop(0))

  ---- Timers Cancel ------
  local seconds_timer = device:get_field("seconds_timer")
  if seconds_timer ~= nil then
    print("<<<<< Cancel seconds_timer >>>>>")
    driver:cancel_timer(seconds_timer)
    device:set_field("seconds_timer", nil)
  end
end

--- Timer for seconds calculate and start
local function timer_seconds_calculation(driver, device)

  ---- Timers Cancel ------
  local seconds_timer = device:get_field("seconds_timer")
  if seconds_timer ~= nil then
    print("<<<<< Cancel seconds_timer >>>>>")
    driver:cancel_timer(seconds_timer)
    device:set_field("seconds_timer", nil)
  end

  print("<< Timer calculation and activation >>")

  seconds_timer = device:get_field("seconds_timer")
  if seconds_timer == nil then -- timer is stopped

    -- calculate timer value
    local timer_value = device:get_field("set_timer_seconds")
    if device:get_field("set_timer_type") == "Random" then
      if device.preferences.logDebugPrint == true then
        print("set_min_random_timer:",device:get_field("set_min_random_timer"))
        print("set_max_random_timer:",device:get_field("set_max_random_timer"))
      end
      timer_value = math.random(device:get_field("set_min_random_timer"), device:get_field("set_max_random_timer"))
      device:set_field("set_timer_seconds", timer_value, {persist = false})
    end
    device:emit_event(timer_Seconds.timerSeconds(device:get_field("set_timer_seconds")))

    -- determine if "set_next_timer_change" was set and timer was stopped by hub reboot or driver initialized 
    local new_timer_value
    if device:get_field("set_next_timer_change") ~= 0 then -- driver was initialized with timer running
      new_timer_value = math.ceil(device:get_field("set_next_timer_change") - (os.time() + (device:get_field("setLocalHourOffset") * 3600)))
      if device.preferences.logDebugPrint == true then
       print("<<< new_timer_value re-start",new_timer_value)
      end
      if new_timer_value < 0 then
        new_timer_value = 0.5
      end
    else
      new_timer_value = timer_value
      local set_next_timer_change = os.time() + (device:get_field("setLocalHourOffset") * 3600) + new_timer_value
      device:set_field("set_next_timer_change", set_next_timer_change, {persist = false})
    end

    if device.preferences.logDebugPrint == true then
      print("<<< timer_value:",timer_value)
      print("<<< new_timer_value:",new_timer_value)
      print("<<< set_next_timer_change >>>", os.date("%Y/%m/%d %H:%M:%S",device:get_field("set_next_timer_change")))
    end
    local next_change_event = os.date("%Y/%m/%d -> %H:%M:%S",device:get_field("set_next_timer_change"))
    device:emit_event(timer_Next_Change.timerNextChange(next_change_event))
    local delay = 1
    if new_timer_value < 3 then delay = 0.5 end
    device.thread:call_with_delay(delay, function(d) device:emit_event(capabilities.switch.switch.on()) end )

    ------  Timer activation
    seconds_timer = device.thread:call_with_delay(new_timer_value, function(d)

      local set_current_Loop = device:get_field("set_current_Loop") + 1
      device:set_field("set_current_Loop", set_current_Loop, {persist = false})
      device:emit_event(current_Loop.currentLoop(set_current_Loop))
      

      if device.preferences.logDebugPrint == true then
        local local_time = os.time() + (device:get_field("setLocalHourOffset") * 3600)
        print("<<< Local Time >>>", os.date("%Y/%m/%d %H:%M:%S", local_time))
        print("<<< set_next_timer_change, Reached >>>", os.date("%Y/%m/%d %H:%M:%S",device:get_field("set_next_timer_change")))
        print("<<< set_current_Loop >>>", set_current_Loop)
        print("<<< set_Total_loops_Number >>>", device:get_field("set_loops_Number"))
      end

      device:emit_event(capabilities.switch.switch.off())
      if device:get_field("set_loops_Number") > 0 and device:get_field("set_current_Loop") >= device:get_field("set_loops_Number") then
        device:emit_event(timer_Next_Change.timerNextChange("Inactive"))
      end
      device:set_field("seconds_timer", nil)
      device:set_field("set_next_timer_change", 0, {persist = false})

      -- determine if loops number are end
      if device:get_field("set_loops_Number") == 0 or (device:get_field("set_current_Loop") < device:get_field("set_loops_Number")) then
        timer_seconds_calculation(driver, device)
      end
    end
    )
    device:set_field("seconds_timer", seconds_timer)
  end
end


local function device_added(driver, device)
  print("<<< Virtual timer_Seconds: device_added >>>")

  local cap_status = device:get_latest_state("main", local_Hour_Offset.ID, local_Hour_Offset.localHourOffset.NAME)
  if device:get_field("setLocalHourOffset") == nil or cap_status == nil then
    device:set_field("setLocalHourOffset", 0, {persist = false})
  end
  device:emit_event(local_Hour_Offset.localHourOffset({value = device:get_field("setLocalHourOffset"),  unit = "hr"}))

  if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    device:emit_event(capabilities.switch.switch.on())
  else
    device:emit_event(capabilities.switch.switch.off())
  end

  local set_timer_seconds = device:get_latest_state("main", timer_Seconds.ID, timer_Seconds.timerSeconds.NAME)
  if set_timer_seconds == nil then
    set_timer_seconds = 0
    device:emit_event(capabilities.switch.switch.off())
  end

  local next_change_event = device:get_latest_state("main", timer_Next_Change.ID, timer_Next_Change.timerNextChange.NAME)
  print("<<< next_change_event",next_change_event)
  if next_change_event == nil then
    next_change_event = "Inactive"
  end

  local set_next_timer_change = device:get_field("set_next_timer_change")
  if set_next_timer_change == nil then
    set_next_timer_change = 0
  end

  device:set_field("set_timer_seconds", set_timer_seconds, {persist = false})
  device:set_field("set_next_timer_change", set_next_timer_change, {persist = false})

  device:emit_event(timer_Seconds.timerSeconds(set_timer_seconds))
  device:emit_event(timer_Next_Change.timerNextChange(next_change_event))

  -- initialize timer_Type
  cap_status = device:get_latest_state("main", timer_Type.ID, timer_Type.timerType.NAME)
  if cap_status == nil then 
    cap_status = "Fixed"
  end
  device:set_field("set_timer_type", cap_status, {persist = false})
  device:emit_event(timer_Type.timerType(cap_status))

  --initialize random_Minimum_Timer
  cap_status = device:get_latest_state("main", random_Minimum_Timer.ID, random_Minimum_Timer.randomMinimumTimer.NAME)
  if cap_status == nil then 
    cap_status = 1
  end
  device:set_field("set_min_random_timer", cap_status, {persist = false})
  device:emit_event(random_Minimum_Timer.randomMinimumTimer(cap_status))

  -- initialize random_Maximum_Timer
  cap_status = device:get_latest_state("main", random_Maximum_Timer.ID, random_Maximum_Timer.randomMaximumTimer.NAME)
  if cap_status == nil then 
    cap_status = 60
  end
  device:set_field("set_max_random_timer", cap_status, {persist = false})
  device:emit_event(random_Maximum_Timer.randomMaximumTimer(cap_status))

  -- initialize set_Loops_Number
  cap_status = device:get_latest_state("main", loops_Number.ID, loops_Number.loopsNumber.NAME)
  if cap_status == nil then 
    cap_status = 1
  end
  device:set_field("set_loops_Number", cap_status, {persist = false})
  device:emit_event(loops_Number.loopsNumber(cap_status))

  -- initialize set_Loops_Number
  local set_current_Loop = device:get_latest_state("main", current_Loop.ID, current_Loop.currentLoop.NAME)
  if set_current_Loop == nil then 
    set_current_Loop = 0
  end
  device:set_field("set_current_Loop", set_current_Loop, {persist = false})
  device:emit_event(current_Loop.currentLoop(device:get_field("set_current_Loop")))

  -- cancel timer if set_timer_seconds = 0
  if device:get_field("set_timer_seconds") <= 0 then

    ---- Timers Cancel ------
    local seconds_timer = device:get_field("seconds_timer")
    if seconds_timer ~= nil then
      print("<<<<< Cancel seconds_timer >>>>>")
      driver:cancel_timer(seconds_timer)
      device:set_field("seconds_timer", nil)
    end 
  end
end
--------------------------------------------------------
 --------- Handler timer_For_Seconds ------------------------

local function setTimerSeconds_handler(driver, device, command)
  print("<<< command.args.value >>>",command.args.value)

  ---- Timers Cancel ------
  local seconds_timer = device:get_field("seconds_timer")
  if seconds_timer ~= nil then
    print("<<<<< Cancel seconds_timer >>>>>")
    driver:cancel_timer(seconds_timer)
    device:set_field("seconds_timer", nil)
  end

  local set_timer_seconds = command.args.value
  local set_next_timer_change = 0
  device:set_field("set_timer_seconds", set_timer_seconds, {persist = false})
  device:set_field("set_next_timer_change", set_next_timer_change, {persist = false}) 

  device:emit_event(capabilities.switch.switch.off())

  device:emit_event(timer_Seconds.timerSeconds(set_timer_seconds))
  device:emit_event(timer_Next_Change.timerNextChange("Inactive"))
end

-- start timer 
local function start_timer(driver, device, command)
  print("<<< start_timer >>>")

  device:set_field("set_next_timer_change", 0, {persist = false})
  device:set_field("set_current_Loop", 0, {persist = false})
  device:emit_event(current_Loop.currentLoop(0))
  timer_seconds_calculation(driver, device)
end

-- stop timer
local function stop_timer(driver, device, command)
  print("<<< stop_timer >>>")

  timer_cancel(driver, device)
end

-- set minimum random timer
local function setRandomMinimumTimer_handler(driver, device, command)
  print("<<< setRandomMinimumTimer_handler")
  local set_min_random_timer = command.args.value
  device:set_field("set_min_random_timer", set_min_random_timer, {persist = false})
  device:emit_event(random_Minimum_Timer.randomMinimumTimer(set_min_random_timer))

  timer_cancel(driver, device)
end

-- set maximum random timer
local function setRandomMaximumTimer_handler(driver, device, command)
  print("<<< setRandomMaximumTimer_handler")
  local set_max_random_timer = command.args.value
  device:set_field("set_max_random_timer", set_max_random_timer, {persist = false})
  device:emit_event(random_Maximum_Timer.randomMaximumTimer(set_max_random_timer))

  timer_cancel(driver, device)
end

-- re-start timer
local function reset_Timer_handler(driver, device, command)
  print("<<< reset_Timer_handler >>>")
  --print("<<< Reset_button:", command.args.value)

  timer_cancel(driver, device)
  timer_seconds_calculation(driver, device)
end

-- set type of timer
local function setTimerType_handler(driver, device, command)
  print("<<< setTimerType_handler >>>")
  local set_timer_type = command.args.value
  device:set_field("set_timer_type", set_timer_type, {persist = false})
  device:emit_event(timer_Type.timerType(set_timer_type))

  timer_cancel(driver, device)
end

local function setLoopsNumber_handler(driver, device, command)
  print("<<< setLoops_Number_handler >>>")
  --print("<<< Loops_Number:", command.args.value)
  local set_loops_Number = command.args.value
  device:set_field("set_loops_Number", set_loops_Number, {persist = false})
  device:emit_event(loops_Number.loopsNumber(set_loops_Number))

  timer_cancel(driver, device)
end

--local_Hour_Offset_handler
local function local_hour_offset_handler(driver, device, command)
  print("<<<<<<< local hour days >>>>>>>>")
  device:set_field("setLocalHourOffset", command.args.value, {persist = false})
  device:emit_event(local_Hour_Offset.localHourOffset({value = command.args.value,  unit = "hr"}))

  device:emit_event(capabilities.switch.switch.off())
  stop_timer(driver, device, command)
end

local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing Virtual Device")

  -- mark device as online so it can be controlled from the app
  device:online()

  -- provisioning_state = "PROVISIONED"
  print("doConfigure performed, transitioning device to PROVISIONED")
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
  --print("device:", utils.stringify_table(device))
  if device.model ~= "Virtual Timer Seconds" then
    device:try_update_metadata({ model = "Virtual Timer Seconds" })
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

  -- timer for Seconds re-start timer if was stopped by a reboot
  cap_status = device:get_latest_state("main", timer_Next_Change.ID, timer_Next_Change.timerNextChange.NAME)
  --device:emit_event(timer_Next_Change.timerNextChange("Inactive"))
  --"2024/04/11 -> 15:39:14"
   if cap_status == nil or cap_status == "Inactive" then
     device:set_field("set_next_timer_change", 0, {persist = false})
     if cap_status == nil then cap_status = "Inactive" end
   elseif cap_status ~= "Inactive" then
     -- convert string next change to seconds of date type
     --local date = device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
     local hour = tonumber(string.sub (cap_status, 15 , 16))
     local min = tonumber(string.sub (cap_status, 18 , 19))
     local sec = tonumber(string.sub (cap_status, 21 , 22))
     local year = tonumber(string.sub (cap_status, 1 , 4))
     local month = tonumber(string.sub (cap_status, 6 , 7))
     local day = tonumber(string.sub (cap_status, 9 , 10))
     local time = os.time({ day = day, month = month, year = year, hour = hour, min = min, sec = sec})
     if device.preferences.logDebugPrint == true then
       print("<<< date:", cap_status)
       print("<<< date:", year, month, day, hour, min, sec)
       print("<<< date formated >>>", os.date("%Y/%m/%d %H:%M:%S",time))
     end
     device:set_field("set_next_timer_change", time, {persist = false})
   end
   device:emit_event(timer_Next_Change.timerNextChange(cap_status))

   -- initialize timer_ seconds value
   local set_timer_seconds = device:get_latest_state("main", timer_Seconds.ID, timer_Seconds.timerSeconds.NAME)
   if set_timer_seconds == nil then
     set_timer_seconds = 0
     device:emit_event(capabilities.switch.switch.off())
   end
   device:set_field("set_timer_seconds", set_timer_seconds, {persist = false})
   device:emit_event(timer_Seconds.timerSeconds(set_timer_seconds))

   -- initialize current_Loops
   cap_status = device:get_latest_state("main", current_Loop.ID, current_Loop.currentLoop.NAME)
   if cap_status == nil then 
     cap_status = 0
   end
   device:set_field("set_current_Loop", cap_status, {persist = false})
   device:emit_event(current_Loop.currentLoop(device:get_field("set_current_Loop")))

   -- initialize set_Loops_Number
   cap_status = device:get_latest_state("main", loops_Number.ID, loops_Number.loopsNumber.NAME)
   if cap_status == nil then 
     cap_status = 1
   end
   device:set_field("set_loops_Number", cap_status, {persist = false})
   device:emit_event(loops_Number.loopsNumber(device:get_field("set_loops_Number")))

   -- initialize timer_Type
   cap_status = device:get_latest_state("main", timer_Type.ID, timer_Type.timerType.NAME)
   if cap_status == nil then 
     cap_status = "Fixed"
   end
   device:set_field("set_timer_type", cap_status, {persist = false})
   device:emit_event(timer_Type.timerType(cap_status))

   --initialize random_Minimum_Timer
   cap_status = device:get_latest_state("main", random_Minimum_Timer.ID, random_Minimum_Timer.randomMinimumTimer.NAME)
   if cap_status == nil then 
     cap_status = 1
   end
   device:set_field("set_min_random_timer", cap_status, {persist = false})
   device:emit_event(random_Minimum_Timer.randomMinimumTimer(cap_status))

   -- initialize random_Maximum_Timer
   cap_status = device:get_latest_state("main", random_Maximum_Timer.ID, random_Maximum_Timer.randomMaximumTimer.NAME)
   if cap_status == nil then 
     cap_status = 60
   end
   device:set_field("set_max_random_timer", cap_status, {persist = false})
   device:emit_event(random_Maximum_Timer.randomMaximumTimer(cap_status))

   cap_status = device:get_latest_state("main", local_Hour_Offset.ID, local_Hour_Offset.localHourOffset.NAME)
   if device:get_field("setLocalHourOffset") == nil or cap_status == nil then
     device:set_field("setLocalHourOffset", 0, {persist = false})
   end
   if device.preferences.logDebugPrint == true then
     print("device:get_field(set_next_timer_change)",device:get_field("set_next_timer_change"))
     print("device:get_field(set_timer_seconds)",device:get_field("set_timer_seconds"))
   end
   device:emit_event(local_Hour_Offset.localHourOffset({value = device:get_field("setLocalHourOffset"),  unit = "hr"}))
   -- timer did not completed fine, need restart timer
   if device:get_field("set_next_timer_change") ~= 0 then
     timer_seconds_calculation(driver, device)
   end
end

-- callback to handle an on-off capability command
local function switch_on_off_handler(driver, device, command)
  print("<<<<<<<<<<<<<<<<<<<<<< On - Off Handler >>>>>>>>>>>>>>>>>>>>>>>")
  --print("<<< command.args.value:", command.command)
  local own_state = command.command
  if own_state == "on" then
    device:emit_event(capabilities.switch.switch.on())
      start_timer(driver, device, command)
  elseif own_state == "off" then
    device:emit_event(capabilities.switch.switch.off())
    stop_timer(driver, device, command)
  end
end

local virtual_timer_seconds = {
	NAME = "virtual timer seconds",
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = switch_on_off_handler,
      [capabilities.switch.commands.off.NAME] = switch_on_off_handler,
    },
    [local_Hour_Offset.ID] = {
      [local_Hour_Offset.commands.setLocalHourOffset.NAME] = local_hour_offset_handler,
    },
    [timer_Seconds.ID] = {
      [timer_Seconds.commands.setTimerSeconds.NAME] = setTimerSeconds_handler,
    },
    [random_Minimum_Timer.ID] = {
      [random_Minimum_Timer.commands.setRandomMinimumTimer.NAME] = setRandomMinimumTimer_handler,
    },
    [random_Maximum_Timer.ID] = {
      [random_Maximum_Timer.commands.setRandomMaximumTimer.NAME] = setRandomMaximumTimer_handler,
    },
    [reset_button.ID] = {
      [reset_button.commands.push.NAME] = reset_Timer_handler,
    },
    [timer_Type.ID] = {
      [timer_Type.commands.setTimerType.NAME] = setTimerType_handler,
    },
    [loops_Number.ID] = {
      [loops_Number.commands.setLoopsNumber.NAME] = setLoopsNumber_handler,
    },
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
  },

  can_handle = can_handle
}
return virtual_timer_seconds