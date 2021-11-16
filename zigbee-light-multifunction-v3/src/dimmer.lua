--- Smartthings library load ---
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local colorcontrol_defaults = require "st.zigbee.defaults.colorTemperature_defaults"

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
local oldPreferenceValue ={}
local newParameterValue ={}

-- Random tables variables
local random_Step = {}
local random_totalStep = {}
local random_timer = {}

--- Circadian Rhythm table
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
 }
local circadian_Running = {}
local circadian = {}

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
local color_Change_Mode = capabilities["legendabsolute60149.colorChangeMode"]

 ----- do_init device tables create for dimming variables ----
 function driver_handler.do_init (self, device)
  local device_exist = "no"
  for id, value in pairs(device_running) do
   if device_running[id] == device then
    device_exist = "si"
   end
  end
 ---- If is new device initialize table values
 if device_exist == "no" then
  print("<<<<< Device No Exist >>>>>>")
  device_running[device]= device
  if device:get_field("progOn[device]") == nil then
   progOn[device] = "Inactive"
   device:emit_event(prog_On.progOn("Inactive"))
  else
   progOn[device] = device:get_field("progOn[device]")
  end
  onStatus[device] = "stopped"
  onTotalSteps[device] = 2
  onStep[device] = 0
  onNewLevel[device] = 1
  onStepLevel[device] = 1
  onTimer[device]= 2
  dimJump[device] = "yes"
  if device:get_field("progOff[device]") == nil then
   progOff[device] = "Inactive"
   device:emit_event(prog_Off.progOff("Inactive"))
  else
   progOff[device] = device:get_field("progOff[device]")
  end
  offStatus[device] = "stopped"
  offTotalSteps[device] = 2
  offStep[device] = 0
  offNewLevel[device] = 1
  offStepLevel[device] = 1
  offTimer[device]= 2
  offLevelStart[device] = 10
  offJump[device] = "no"
  oldPreferenceValue[device] = "-"
  newParameterValue[device] = "-"
  random_Step[device] = 1
  random_totalStep[device] =2
  random_timer[device] = math.random(10, 20)
  if device:get_field("circadian_Running[device]") == nil then
   circadian_Running[device] = "stopped"
   device:emit_event(circadian_Light.circadian("Inactive"))
  else
   circadian_Running[device] = device:get_field("circadian_Running[device]")
  end
  if device:get_field("circadian[device]") == nil then
   circadian[device] = "Inactive"
  else
   circadian[device] = device:get_field("circadian[device]")
  end

  device:emit_event(random_On_Off.randomOnOff("Inactive"))
  device:emit_event(random_Next_Step.randomNext("Inactive"))
 
  --- ON dimming values calculation
    if device.preferences.onTimeMax > 0.7 then onTimer[device] = 2 else onTimer[device] = 0.5 end
     onTotalSteps[device] = math.floor(device.preferences.onTimeMax * 60 / onTimer[device])
     onStepLevel[device] = ((device.preferences.onLevelEnd - device.preferences.onLevelStart)+ 0.1) / onTotalSteps[device]
     print ("turnOn.onTotalSteps,turnOn.onStepLevel =", onTotalSteps[device], onStepLevel[device])

     -- OFF dimming values calculation
     if device.preferences.offTimeMax > 0.7 then offTimer[device] = 2 else offTimer[device] = 0.5 end
     offTotalSteps[device] = math.floor(device.preferences.offTimeMax * 60 / offTimer[device])
     if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) == nil then
      offLevelStart[device] = math.floor(device.preferences.onLevelEnd/100.0 * 254)
     else
      offLevelStart[device] = math.floor(device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
     end
     offStepLevel[device] = ((offLevelStart[device]+0.1)- device.preferences.offLevelEnd) / offTotalSteps[device]
     print ("turnOff.onTotalSteps,turnOff.onStepLevel =", offTotalSteps[device], offStepLevel[device])

  ----- print device init values for debug------
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
   print("random_timer=",circadian_Running[id])
   print("random_timer=",circadian[id])
  end
 end
 
 --- ReStart Timer color chanaging function
 if device:get_field("colorChanging") == "Active" then 
   device:set_field("colorChanging", "Continue", {persist = true})
   driver_handler.color_Changing_handler(self,device,"Continue")
 else
  device:emit_event(color_Changing.colorChanging("Inactive"))
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
    oldPreferenceValue[device] = nil
    newParameterValue[device] = nil

    random_Step[device] = nil
    random_totalStep[device] = nil
    random_timer[device] = nil
    circadian_Running[device] = nil
    circadian[device] = nil
   end
  end
  
  -----print tables of devices no removed from driver ------
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
    print("random_timer=",circadian_Running[id])
    print("random_timer=",circadian[id])
 end
end

-----------------------------------------------
---------------- Timers Cancel ----------------
local function timers_Cancel(_,device)

 if circadian_Running[device] == "stopped" or circadian[device] == "Inactive" then
  for timer in pairs(device.thread.timers) do
    print("<<<<< Cancel all timer >>>>>")
    device.thread:cancel_timer(timer)
  end
 end
  return
end

--- Update preferences after infoChanged recived---
function driver_handler.do_Preferences (self, device)
  for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id])
    oldPreferenceValue[device] = device:get_field(id)
    --print("oldPreferenceValue ", oldPreferenceValue[device])
    newParameterValue[device] = device.preferences[id]
    --print("newParameterValue ", newParameterValue[device])
    if oldPreferenceValue[device] ~= newParameterValue[device] then
      device:set_field(id, newParameterValue[device], {persist = true})
      print("<< Preference changed: name, old, new >>", id, oldPreferenceValue[device], newParameterValue[device])

      ---- Timers Cancel ------
      timers_Cancel(self,device)
     --end

     print("---- new dimming values calculation --------")
     --- on dimming calculation values
    if device.preferences.onTimeMax > 0.7 then onTimer[device] = 2 else onTimer[device] = 0.5 end
     onTotalSteps[device] = math.floor(device.preferences.onTimeMax * 60 / onTimer[device])
     onStepLevel[device] = ((device.preferences.onLevelEnd - device.preferences.onLevelStart)+ 0.1) / onTotalSteps[device]
     print ("turnOn.onTotalSteps,turnOn.onStepLevel =", onTotalSteps[device], onStepLevel[device])

     --- off dimming calculation values
     if device.preferences.offTimeMax > 0.7 then offTimer[device] = 2 else offTimer[device] = 0.5 end
     offTotalSteps[device] = math.floor(device.preferences.offTimeMax * 60 / offTimer[device])
     if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) == nil then
      offLevelStart[device] = math.floor(device.preferences.onLevelEnd/100.0 * 254)
     else
      offLevelStart[device] = math.floor(device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
     end
     offStepLevel[device] = ((offLevelStart[device]+ 0.1) - device.preferences.offLevelEnd) / offTotalSteps[device]
     print ("turnOff.onTotalSteps,turnOff.onStepLevel =", offTotalSteps[device], offStepLevel[device])
 
   end
  end
 end

---------------------------------------------------------
------------- color_Changing_handler --------------------

function driver_handler.color_Changing_handler(_,device,command)
    ---- Timers Cancel ------
    timers_Cancel(_,device)

    -----cancel progressive ON & OFF and Circadian
   progOn[device] = "Inactive"
   device:set_field("progOn[device]", progOn[device], {persist = true})
   device:emit_event(prog_On.progOn("Inactive"))
   progOff[device] = "Inactive"
   device:set_field("progOff[device]", progOff[device], {persist = true})
   device:emit_event(prog_Off.progOff("Inactive"))
   device:emit_event(circadian_Light.circadian("Inactive"))
   circadian[device] = "Inactive"
   device:set_field("circadian[device]", circadian[device], {persist = true})
   circadian_Running[device] = "stopped"
   device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
   device:emit_event(random_On_Off.randomOnOff("Inactive"))

   local colorChanging = device:get_field("colorChanging")
   if colorChanging == "Continue" then
    colorChanging = "Active"
   else
    print("colorChanging Value", command.args.value)
    colorChanging = command.args.value
   end

  if colorChanging == "Inactive" then
    device:set_field("colorChanging", colorChanging, {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))

  else
    device:set_field("colorChanging", colorChanging, {persist = true})
    device:emit_event(color_Changing.colorChanging("Active"))
    
    --- Set ColorChangeMode
    local colorChangeMode = device:get_field("colorChangeMode")
    if colorChangeMode == nil then colorChangeMode = 1 end
    local colorTimer = device:get_field("colorTimer")
    if colorTimer == nil then colorTimer = 3 end
    -- Set steps numbers to 0
    local stepsNumber = device:get_field("stepsNumber")
    if stepsNumber == nil then stepsNumber = 0 end
    local stepsNumberMax = device:get_field("stepsNumberMax")
    if stepsNumberMax == nil then stepsNumberMax = 100 end

    local colorChangeModeList = device:get_field("colorChangeModeList")
    if colorChangeModeList == "Continuous" then
      colorChangeMode = 1
    elseif colorChangeModeList == "Random" then
      colorChangeMode = 2
    elseif colorChangeModeList == "AllModes" then
      colorChangeMode = math.random(1, 2)
      colorTimer = math.random(1, 3)
      stepsNumberMax = math.random(50, 100)
      device:set_field("colorTimer", colorTimer, {persist = true})
      device:emit_event(color_Change_Timer.colorChangeTimer(colorTimer))
    end

    device:set_field("colorChangeMode", colorChangeMode, {persist = true})
    device:set_field("colorTimer",  colorTimer, {persist = true})
    device:set_field("stepsNumber",  stepsNumber, {persist = true})
    device:set_field("stepsNumberMax",  stepsNumberMax, {persist = true})

    local newSaturation = math.random(1, 254)
    print("<<<<< newSaturation >>>>>",newSaturation )
    local saturationStep = 2
    device:set_field("newSaturation",  newSaturation, {persist = true})
    local newHue = math.random(1, 254)
    print("<<<<< newHue >>>>>",newHue)
    local hueStep = -2
    device:set_field("newHue", newHue, {persist = true})


    ------ Timer Color Changing activation
   device.thread:call_on_schedule(
    colorTimer,
     function ()
      
      -- Incremet steps for AllModesRamdom Mode
      if colorChangeModeList == "AllModes" then
       stepsNumber = device:get_field("stepsNumber")
       stepsNumber = stepsNumber + 1
       if stepsNumber >= device:get_field("stepsNumberMax") and colorChangeModeList == "AllModes" then
        device:set_field("colorChanging", "Continue", {persist = true})
        driver_handler.color_Changing_handler(_,device,"Continue")
        stepsNumber = 0
       end
       device:set_field("stepsNumber",  stepsNumber, {persist = true})
       print("<< stepsNumber, stepsNumberMax >>", stepsNumber, stepsNumberMax)

       colorChangeMode = device:get_field("colorChangeMode")
       if colorChangeMode == nil then colorChangeMode = 2 end
      end
    print("<<<<<<<< Color Changing Mode >>>>>>>", colorChangeMode)
    print("*** color Timer ***", colorTimer)
     if colorChangeMode == 1 then
      newSaturation = newSaturation + saturationStep
      if newSaturation > 254 then 
        saturationStep = saturationStep * -1
        newSaturation = 254
      elseif newSaturation < 1 then
        saturationStep = saturationStep * -1
        newSaturation = 1       
      end
      newHue = newHue + hueStep
      if newHue > 254 then 
        hueStep = saturationStep * -1
        newHue = 254
      elseif newHue < 1 then
        hueStep = hueStep * -1
        newHue = 1       
      end
   
    elseif colorChangeMode == 2 then
      newSaturation = math.random(1, 254)
      print("<<<<< newSaturation >>>>>",newSaturation )
      newHue = math.random(1, 254)
      print("<<<<< newHue >>>>>",newHue)
    end
    
    -- Enmit command and color event
     
    --local hue = math.floor((command.args.color.hue * 0xFE) / 100.0 + 0.5)
     --local sat = math.floor((command.args.color.saturation * 0xFE) / 100.0 + 0.5)
     device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToHueAndSaturation(device, newHue, newSaturation, 0x0000))
     device:emit_event_for_endpoint("main",capabilities.colorControl.hue(math.floor(newHue / 0xFE * 100)))
     device:emit_event_for_endpoint("main",capabilities.colorControl.saturation(math.floor(newSaturation / 0xFE * 100)))    
    
    end
     ,'ColorChanging')   
  end
 
  --last state for capability
  --print("color_Changing.colorChanging >>>>>>>>", device:get_latest_state("main", color_Changing.ID, color_Changing.colorChanging.NAME))

end

---------------------------------------------------------
--------------- color_Change_Timer_handler --------------

function driver_handler.color_Change_Timer_handler(_, device, command)

  print("colorChangeTimer Value", command.args.value)
  local colorTimer = command.args.value
  device:set_field("colorTimer", colorTimer, {persist = true})
  device:emit_event(color_Change_Timer.colorChangeTimer(colorTimer))

  --- goto color chanaging function
  if device:get_field("colorChanging") == "Active" then 
    device:set_field("colorChanging", "Continue", {persist = true})
    driver_handler.color_Changing_handler(_,device,"Continue")
  end

end

--------------------------------------------------------
------------- color_Change_Mode_handler ----------------

function driver_handler.color_Change_Mode_handler(_,device,command)

  print("colorChangeMode Value", command.args.value)
  local colorChangeModeList = command.args.value
  device:set_field("colorChangeModeList", colorChangeModeList, {persist = true})
  device:emit_event(color_Change_Mode.colorChangeMode(colorChangeModeList))

  --- goto color chanaging function
  if device:get_field("colorChanging") == "Active" then 
    device:set_field("colorChanging", "Continue", {persist = true})
    driver_handler.color_Changing_handler(_,device,"Continue")
  end

end

 --------------------------------------------------------
 --------- Handler Random ON-OFF ------------------------

function driver_handler.random_on_off_handler(_,device,command)

      ---- Timers Cancel ------
      timers_Cancel(_,device)

  print("randomOnOff Value", command.args.value)
  if command.args.value == "Inactive" then

  device:emit_event(random_On_Off.randomOnOff("Inactive"))
    -- send zigbee event
    device:send(OnOff.server.commands.Off(device))
    circadian_Running[device]= "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    ---- Timers Cancel ------
    timers_Cancel(_,device)
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    --emit time for next change
    local nextChange = "Inactive"
    device:emit_event(random_Next_Step.randomNext(nextChange))

  elseif command.args.value == "Active" then
   device:emit_event(random_On_Off.randomOnOff("Active"))
   -----cancel progressive ON & OFF, Circadian and Color Changing
   progOn[device] = "Inactive"
   device:set_field("progOn[device]", progOn[device], {persist = true})
   device:emit_event(prog_On.progOn("Inactive"))
   progOff[device] = "Inactive"
   device:set_field("progOff[device]", progOff[device], {persist = true})
   device:emit_event(prog_Off.progOff("Inactive"))
   device:emit_event(circadian_Light.circadian("Inactive"))
   circadian[device] = "Inactive"
   device:set_field("circadian[device]", circadian[device], {persist = true})
   circadian_Running[device] = "stopped"
   device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
   device:emit_event(color_Changing.colorChanging("Inactive"))
   device:set_field("colorChanging", "Inactive", {persist = true})

   random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
   random_Step[device] = 0
   random_totalStep[device] = math.ceil(random_timer[device] / 30)
   --local nextChange= string.format("%.1f",random_timer[device]/60)
   --nextChange = nextChange.." min"
   local nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)

   --emit time for next change
   device:emit_event(random_Next_Step.randomNext(nextChange))
   print("random_totalStep=",random_totalStep[device])
   print("NextChange=",nextChange)

   ------ Timer activation
   device.thread:call_on_schedule(
     30,
     function ()
      random_Step[device] = random_Step[device] + 1
      print("random_step, random_totalStep=",random_Step[device],random_totalStep[device])
      --local nextChange= string.format("%.1f",(random_totalStep[device]-random_Step[device]) * 30 /60)
      --nextChange = nextChange.." min"
        --emit time for next change
      --device:emit_event(random_Next_Step.randomNext(nextChange))

      if random_Step[device] >= random_totalStep[device] then
        local newState = math.random(0, 1)
        print("newState =", newState)
        local attr = capabilities.switch.switch
        if newState == 0 then 
         -- send zigbee event
         device:send(OnOff.server.commands.Off(device))    
        else
          -- send zigbee event
          device:send(OnOff.server.commands.On(device))
        end
        random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
        random_Step[device] = 0
        random_totalStep[device] = math.ceil(random_timer[device] / 30)
        --local nextChange= string.format("%.1f",(random_totalStep[device]-random_Step[device]) * 30 /60)
        --nextChange = nextChange.." min"
        local nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)

        --emit time for next change
        device:emit_event(random_Next_Step.randomNext(nextChange))
        print("NEW-random_totalStep=",random_totalStep[device])
        print("NextChange=",nextChange)
      end
     end
     ,'Random-ON-OFF')   
  end
end

----------------------------------------------------------------
-------- Progressive ON activation & deativation ---------------

function driver_handler.prog_On_handler(_, device, command)

  ---- Timers Cancel ------
  timers_Cancel(_,device)

  print("ProgOn Value", command.args.value)
  if command.args.value == "Inactive" then
    progOn[device] = "Inactive"
    device:set_field("progOn[device]", progOn[device], {persist = true})
    device:emit_event(prog_On.progOn("Inactive"))
  elseif command.args.value == "Active" then
    progOn[device] = "Active"
    device:set_field("progOn[device]", progOn[device], {persist = true})
    device:emit_event(prog_On.progOn("Active"))
    
    ---- Cancel Random On-OFF color Changing and Circadian
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    device:emit_event(circadian_Light.circadian("Inactive"))
    circadian[device] = "Inactive"
    device:set_field("circadian[device]", circadian[device], {persist = true})
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})
  end
  print("progOn =", progOn[device])
end

-----------------------------------------------------------------
-------- Progressive OFF activation & deativation ---------------

function driver_handler.prog_Off_handler(_, device, command)

  ---- Timers Cancel ------
  timers_Cancel(_,device)  

    print("ProgOff Value", command.args.value)
  if command.args.value == "Inactive" then
    progOff[device] = "Inactive"
    device:set_field("progOff[device]", progOff[device], {persist = true})
    device:emit_event(prog_Off.progOff("Inactive"))
  elseif command.args.value == "Active" then
    progOff[device] = "Active"
    device:set_field("progOff[device]", progOff[device], {persist = true})
    device:emit_event(prog_Off.progOff("Active"))

    ---- Cancel Random On-OFF Color Changing and Circadian
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    device:emit_event(circadian_Light.circadian("Inactive"))
    circadian[device] = "Inactive"
    device:set_field("circadian[device]", circadian[device], {persist = true})
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})
  end
  print("progOff =", progOn[device])
end


-----------------------------------------------
--------- level_Steps_handler -----------------

function driver_handler.level_Steps_handler(_, device, command)

  ---- Timers Cancel ------
  timers_Cancel(_,device)

    ---- Cancel Random On-OFF color Changing and Circadian stopped
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})


  ---- next level calculation  
  print("Level Steps Value =", command.args.value)
  local level = command.args.value
  device:emit_event(level_Steps.levelSteps(level))
  level = level + device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
  if level > 100 then 
    level = 100
  elseif level < 0 then
    level =0
  end
  device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor((level)/100.0 * 254), 0xFFFF))
end

-----------------------------------------------
--------- color_Temperature_Steps_handler -----------------

function driver_handler.color_Temperature_Steps_handler(self, device, command)
  print("<<<<<< estoy en color_Temperature_Steps_handler >>>>>>>")
  print("Color Temperature Steps Value =", command.args.value)

    ---- Cancel Random On-OFF color Changing and Circadian stopped
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})

    ---Next Color Temperature calculation
    local colorTemp = command.args.value
    device:emit_event(color_Temperature_Steps.colorTempSteps(colorTemp))
    print("Last Color Temperature =", device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME))
    colorTemp = colorTemp + device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME)
    if colorTemp > 6000 then
      colorTemp = 6000
    elseif colorTemp < 2700 then
      colorTemp = 2700
    end
    print("colorTemp", colorTemp)
    local colorTemp_Mireds= math.ceil(1000000/colorTemp)
    print("colorTemp Mired", colorTemp_Mireds)
    device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
    device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))  
end

-----------------------------------------------
----------- circadian_Light_handler -----------

function driver_handler.circadian_Light_handler(_, device, command)
  print("Circadian Value", command.args.value)

  ---- Timers Cancel ------
  timers_Cancel(_,device)

  if command.args.value == "Inactive" then
    device:emit_event(circadian_Light.circadian("Inactive"))
    circadian[device] = "Inactive"
    device:set_field("circadian[device]", circadian[device], {persist = true})
    
    ---- Timers Cancel ------
    --timers_Cancel(_,device)
    circadian_Running[device] = "stopped"
    device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})

  else
    device:emit_event(circadian_Light.circadian("Active"))
    circadian[device] = "Active"
    device:set_field("circadian[device]", circadian[device], {persist = true})
    -----cancel progressive ON & OFF color Changing and Random On-Off
    progOn[device] = "Inactive"
    device:set_field("progOn[device]", progOn[device], {persist = true})
    device:emit_event(prog_On.progOn("Inactive"))
    progOff[device] = "Inactive"
    device:set_field("progOff[device]", progOff[device], {persist = true})
    device:emit_event(prog_Off.progOff("Inactive"))
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
    device:emit_event(color_Changing.colorChanging("Inactive"))
    device:set_field("colorChanging", "Inactive", {persist = true})
  end    
end

-----------------------------------------------
---------- Circadian rhythm Timer run-------------------
local function circadian_handler(_, device)
  print("<<<<<<<<<<<<<<< In Circadian timer On >>>>>>>>>>>>>>>>")
  local colorTemp = 2700
  local colorTempHour = 2700
  local colorTempNextHour = 2700
  --local newLevel = (device.preferences.onLevelStart + device.preferences.onLevelEnd) / 2
  local newLevel = (device.preferences.circadLevelMin + device.preferences.circadLevelMax) / 2
  local localHour= os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600))
  local localNextHour= os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600) + 3600)
  local localMinutes= os.date("%M",os.time() + device.preferences.localTimeOffset)
  print("localHour, localMinutes =", localHour, localMinutes)
if tonumber(localHour) > 5 and tonumber(localHour) < 18 then 
   circadian_Running[device] = "running"
   device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
   print("circadian_Running=", circadian_Running[device])
  
   -- set initial color temperature 
   colorTempHour = 2700 + ((device.preferences.colorTempMax * 10 - 2700) * math.sin(math.rad(circadian_Time_Angle[localHour])))
   colorTempNextHour = 2700 + ((device.preferences.colorTempMax * 10 - 2700) * math.sin(math.rad(circadian_Time_Angle[localNextHour])))
   print("TempHour, TempNextHour",colorTempHour,colorTempNextHour)
   colorTemp = math.floor(colorTempHour + (colorTempNextHour - colorTempHour) * tonumber(localMinutes) /60)
   --- new level calculation
   --newLevel = device.preferences.onLevelStart + (((colorTemp - 2700) / (device.preferences.colorTempMax * 10 - 2700)) * (device.preferences.onLevelEnd - device.preferences.onLevelStart))
   newLevel = device.preferences.circadLevelMin + (((colorTemp - 2700) / (device.preferences.colorTempMax * 10 - 2700)) * (device.preferences.circadLevelMax - device.preferences.circadLevelMin))
   print("New Level=", newLevel)
  --send initial values
  device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0xFFFF))
   print("colorTemp =", colorTemp)
   local colorTemp_Mireds= math.floor(1000000/colorTemp)
   print("colorTemp Mired", colorTemp_Mireds)
   device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
   device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))

  ---- timer for circadian cycle
  device.thread:call_on_schedule(600, 
   function ()
    localHour= os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600))
    localNextHour= os.date("%H",os.time() + (device.preferences.localTimeOffset * 3600) + 3600)
    localMinutes= os.date("%M",os.time() + device.preferences.localTimeOffset)
    print("localHour, localMinutes =", localHour, localMinutes)
    
    if tonumber(localHour) > 5 and tonumber(localHour) < 18 then

      --- New colorTemperature Calculation
      colorTempHour = 2700 + ((device.preferences.colorTempMax * 10 - 2700) * math.sin(math.rad(circadian_Time_Angle[localHour])))
      colorTempNextHour = 2700 + ((device.preferences.colorTempMax * 10 - 2700) * math.sin(math.rad(circadian_Time_Angle[localNextHour])))
      print("TempHour, TempNextHour",colorTempHour,colorTempNextHour)
      colorTemp = math.floor(colorTempHour + (colorTempNextHour - colorTempHour) * tonumber(localMinutes) /60)
      --- new level calculation
      --newLevel = device.preferences.onLevelStart + (((colorTemp - 2700) / (device.preferences.colorTempMax * 10 - 2700)) * (device.preferences.onLevelEnd - device.preferences.onLevelStart))
      newLevel = device.preferences.circadLevelMin + (((colorTemp - 2700) / (device.preferences.colorTempMax * 10 - 2700)) * (device.preferences.circadLevelMax - device.preferences.circadLevelMin))
      print("New Level=", newLevel)
    --end
      --send values
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(newLevel/100.0 * 254), 0xFFFF))
      print("colorTemp =", colorTemp)
      local colorTemp_Mireds= math.floor(1000000/colorTemp)
      print("colorTemp Mired", colorTemp_Mireds)
      device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
      device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
    end
  end,
  "Circadian_timer")
end
    return
end
-----------------------------------------------
---------------- TURN ON handler --------------

function driver_handler.on_handler (_, device, command)
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device.id)
  print("Manufacturer, Model",manufacturer,model)
  print("Manufacturer_Len, Model_len",manufacturer_len,model_len)

      -- capability reference
    local attr = capabilities.switch.switch
    
    -- set level of preferences if current leve < 1 ----
    if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) == nil then 
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device.preferences.onLevelStart/100.0 * 254), 0xFFFF))
    elseif (device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)) <= 1 then
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device.preferences.onLevelStart/100.0 * 254), 0xFFFF))
    end
   
   ----- detect progressive turn On activated--
    if progOn[device]  ==  "Active" and circadian[device] == "Inactive" then
      print ("turnOn.onStatus =", onStatus[device])
     if onStatus[device] =="stopped" then

      if device.preferences.ifPushSwitch == "Change" then
        print("<<<<<<<<< Estoy en change on start Dim")
        onStartDim[device] = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
      else
       onStartDim[device] = device.preferences.onLevelStart
      end
      onStep[device] = -1
      onStatus[device] ="running"
      --device:set_field("onStatus[device]", onStatus[device], {persist = true})
      print ("turnOn.onTotalSteps =", onTotalSteps[device])
      print ("turnOn.onStepLevel =", onStepLevel[device])
      
      -------- turn on: 2 or 1 sec timer dimming ON --------
      device.thread:call_on_schedule(onTimer[device], 
       function ()
        if onStatus[device] =="running" then
          if onStep[device] == -1 then
            onNewLevel[device] = onStartDim[device]
            onStep[device] = onStep[device] + 1
            device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF))
            device:emit_event(attr.on())
          else
            onStep[device] = onStep[device] + 1 
            onNewLevel[device] = onNewLevel[device] + onStepLevel[device]
            print("onStep=",onStep[device])
            if device.preferences.onLevelEnd >= device.preferences.onLevelStart then
             if onNewLevel[device] >= device.preferences.onLevelEnd or onStep[device] >= onTotalSteps[device] then 
              onNewLevel[device] = device.preferences.onLevelEnd
              onStatus[device] ="stopped"
              --device:set_field("onStatus[device]", onStatus[device], {persist = true})
              for timer in pairs(device.thread.timers) do
               device.thread:cancel_timer(timer)
              end           
             end
            else
             if onNewLevel[device] < device.preferences.onLevelEnd and onStep[device] >= onTotalSteps[device] then
              onNewLevel[device] = device.preferences.onLevelEnd
              onStatus[device] ="stopped"
              --device:set_field("onStatus[device]", onStatus[device], {persist = true})
              for timer in pairs(device.thread.timers) do
                device.thread:cancel_timer(timer)
              end            
             end
            end
              print ("turnOn.onNewLevel=",onNewLevel[device])
              print("Last Level=", device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
              device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(onNewLevel[device]/100.0 * 254), 0xFFFF))

              ---- Change Temp Color if option activated -----
              if device.preferences.progLevelColor == "Yes" then
               local colorTemp = (onNewLevel[device]/100 * ((device.preferences.colorTempMax * 10) - 2700)) + 2700
               local colorTemp_Mireds= math.floor(1000000/colorTemp)
               print("Colr Tem K;  colorTemp Mired", math.floor(colorTemp), colorTemp_Mireds)
               device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
               device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
              end
          end 
        end
       end)
     end
    end

    --- send status ON without dimming---
      if progOn[device]  ==  "Inactive" then
      -- send zigbee event
      device:send(OnOff.server.commands.On(device))
     end
     print("circadian_Running ; circadian[device]", circadian_Running, circadian[device])
     if circadian_Running[device] == "stopped" and circadian[device] == "Active" then
      circadian_handler(_, device)
     end
  end
 
  -----------------------------------------
  ------------ TURN OFF handler -----------
  
function driver_handler.off_handler (_, device, command)
  
  ---deactivate color Continous Change
  device:emit_event(color_Changing.colorChanging("Inactive"))
  device:set_field("colorChanging", "Inactive", {persist = true})

    -- capability reference
    local attr = capabilities.switch.switch

      -- detect switch Pushsed when progressive On or Off running ---
   if onStatus[device] == "running" or offStatus[device] == "running" then

    ---- Cancel Timers
    timers_Cancel(_,device)

     -- progressive Off is running
    if offStatus[device] == "running" then
     offStatus[device]="stopped"
     --device:set_field("offStatus[device]", offStatus[device], {persist = true})
     if (device.preferences.ifPushSwitch == "Change") then
      if progOn[device] == "Active" then
        device:emit_event(attr.on())
        driver_handler.on_handler(_,device, command)
        offJump[device]="yes"
      end
       dimJump[device] ="yes" 
      else
       dimJump[device] ="yes"
       offJump[device] = "yes"
       if (device.preferences.ifPushSwitch == "Off")  then device:send(OnOff.server.commands.Off(device))end
       if (device.preferences.ifPushSwitch == "End") then 
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor((device.preferences.offLevelEnd+0.1)/100.0 * 254), 0xFFFF))
        device:send(zcl_clusters.OnOff.attributes.OnOff:read(device))
       end
       if (device.preferences.ifPushSwitch == "Stop") then device:emit_event(attr.on()) end
      end
    else
      --- progressive On is running
      onStatus[device]="stopped"
      if (device.preferences.ifPushSwitch == "Change") then
       if progOff[device] == "Active" then
        offJump[device] = "yes"
        dimJump[device] = "no"
       else
        dimJump[device] = "yes"
       end
      else   
      dimJump[device] = "yes"
       if (device.preferences.ifPushSwitch == "End") then
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(device.preferences.onLevelEnd / 100.0 * 254), 0xFFFF))
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
       offLevelStart[device] = math.floor(device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
       offStepLevel[device] = ((offLevelStart[device]+ 0.1)- device.preferences.offLevelEnd) / offTotalSteps[device]
       offStep[device] = -1
       offStatus[device] ="running"
       --device:set_field("offStatus[device]", offStatus[device], {persist = true})
       print ("turnOff.offTotalSteps =", offTotalSteps[device])
       print ("turnOff.offStepLevel =", offStepLevel[device])
      
       --- turn on 2 or 1 sec timer for dimming off ------

       device.thread:call_on_schedule(offTimer[device], 
       function ()
        if offStatus[device] =="running" then
          if offStep[device] == -1 then
            offNewLevel[device] =  offLevelStart[device]
            offStep[device] = offStep[device] + 1
            device:send(OnOff.server.commands.On(device))
            device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF))
          else
            offStep[device] = offStep[device] + 1 
            offNewLevel[device] = (offNewLevel[device] - offStepLevel[device])
            print("offStep=", offStep[device])
            if offNewLevel[device] <= device.preferences.offLevelEnd or offStep[device] >= offTotalSteps[device] then 
             offNewLevel[device] = device.preferences.offLevelEnd
             offStatus[device] ="stopped"
             --device:set_field("offStatus[device]", offStatus[device], {persist = true})
             for timer in pairs(device.thread.timers) do
              device.thread:cancel_timer(timer)
             end
            end
              print ("turnOff.offNewLevel=",offNewLevel[device])
              print("Last Level=", device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
              device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor(offNewLevel[device]/100.0 * 254), 0xFFFF))

              ---- Change Temp Color if option activated -----
              if device.preferences.progLevelColor == "Yes" then
               local colorTemp = (offNewLevel[device]/100 * ((device.preferences.colorTempMax * 10)-2700)) + 2700
               local colorTemp_Mireds= math.floor(1000000/colorTemp)
               print("Colr Tem K;  colorTemp Mired", math.floor(colorTemp), colorTemp_Mireds)
               device:send_to_component("main", zcl_clusters.ColorControl.server.commands.MoveToColorTemperature(device, colorTemp_Mireds, 0x0000))
               device:emit_event_for_endpoint("main", capabilities.colorTemperature.colorTemperature(math.floor(colorTemp)))
              end
          end 
        end
       end)
     end
    end
   end
  
   -- send status Off if needed
     if offJump[device] == "no" and (offStatus[device] == "stopped" and onStatus[device] == "stopped") then
      if progOff[device]  ==  "Inactive" or device.preferences.ifPushSwitch == "Off" or offJump[device] == "no" then
       -- send zigbee event
       device:send(OnOff.server.commands.Off(device))

      ---- Cancel Timers
       circadian_Running[device] = "stopped"
       device:set_field("circadian_Running[device]", circadian_Running[device], {persist = true})
       timers_Cancel(_,device)
      end
    end
    offJump[device] = "no"
    dimJump[device]= "no"
  end

  return driver_handler