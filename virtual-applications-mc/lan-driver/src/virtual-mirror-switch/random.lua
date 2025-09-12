--- Smartthings library load ---
local capabilities = require "st.capabilities"

local random = {}

-- Random tables variables
local random_timer = {}

-- Custom Capability Randon On Off
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
--local mirror_In = capabilities["legendabsolute60149.mirrorIn"]
local mirror_Out = capabilities["legendabsolute60149.mirrorOut"]

 --------------------------------------------------------
 --------- Handler Random ON-OFF ------------------------

function random.random_on_off_handler(_,device,command)

  local delay= {} -- variable to timer or random on or off period
  ---- Timers Cancel ------
  for timer in pairs(device.thread.timers) do
    print("<<<<< Cancel all timer >>>>>")
    device.thread:cancel_timer(timer)
  end
  
  local random_state = device:get_field("random_state")
  local nextChange = device:get_latest_state("main", random_Next_Step.ID, random_Next_Step.randomNext.NAME)
  if command == "Active" then
    random_state = device:get_field("random_state")
  else
    random_state = command.args.value
  end
 
  if device.preferences.logDebugPrint == true then
    print("randomOnOff Value", random_state)
    print("device:get_field(random_state)",device:get_field("random_state"))
  end
 if random_state == "Inactive" then
    device:set_field("time_nextChange", nil, {persist = false})
    -- send zigbee event
    device:emit_event(capabilities.switch.switch.off())
    if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
      device:emit_event(mirror_Out.mirrorOut("Off"))
    end

    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:set_field("random_state", "Inactive", {persist = false})
    --emit time for next change
    nextChange = "Inactive"
    device:emit_event(random_Next_Step.randomNext(nextChange))

 elseif random_state == "Random" or random_state == "Program" then
  device:emit_event(random_On_Off.randomOnOff(random_state))
  if random_state ~= device:get_field("random_state") then
    device:set_field("time_nextChange", nil, {persist = false})
  end
  device:set_field("random_state", random_state, {persist = false})
 
  if random_state == "Random" then
   --Random timer calculation
   random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
  else
    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      device:emit_event(capabilities.switch.switch.on())
      if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
        device:emit_event(mirror_Out.mirrorOut("On"))
      end
      --Program timer calculation
      random_timer[device] = device.preferences.onTime * 60
    else
      device:emit_event(capabilities.switch.switch.off())
      if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
        device:emit_event(mirror_Out.mirrorOut("Off"))
      end
      device:set_field("last_state", "off", {persist = false})  
      --Program timer calculation
      random_timer[device] = device.preferences.offTime * 60
    end
   end

  -- calculate next time to change and timer delay
  if device:get_field("time_nextChange") == nil then
    nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
    local time_nextChange = os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600
    device:set_field("time_nextChange", time_nextChange, {persist = false})
    delay[device] = (os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600) - (os.time() + device.preferences.localTimeOffset * 3600)
  else
    delay[device] = device:get_field("time_nextChange") - (os.time() + device.preferences.localTimeOffset * 3600)
  end
  if delay[device] < 0.5 then delay[device] = 0.5 end

  --emit time for next change
  device:emit_event(random_Next_Step.randomNext(nextChange))
  if device.preferences.logDebugPrint == true then
    print("<<< delay[device]=",delay[device])
    print("NextChange=",nextChange)
  end

------ Timer activation
  device.thread:call_with_delay(
  delay[device],
  function ()

    if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      device:emit_event(capabilities.switch.switch.off())
      if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
        device:emit_event(mirror_Out.mirrorOut("Off"))
      end
    else
      device:emit_event(capabilities.switch.switch.on())
      if device.preferences.switchNumber == 1 and device.preferences.changeProfile ~= "Switch" then
        device:emit_event(mirror_Out.mirrorOut("On"))
      end
    end

    device:set_field("time_nextChange", nil, {persist = false})
    random.random_on_off_handler(_, device, "Active")
  end
  ,'Random-ON-OFF')   
 end
end

return random