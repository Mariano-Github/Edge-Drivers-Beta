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

-- Custom Capability Randon On Off
local random_On_Off = capabilities["legendabsolute60149.randomOnOff1"]
local prog_On = capabilities["legendabsolute60149.progressiveOn1"]
local prog_Off = capabilities["legendabsolute60149.progressiveOff1"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep"]
local level_Steps = capabilities["legendabsolute60149.levelSteps"]
local color_Temperature_Steps = capabilities["legendabsolute60149.colorTemperatureSteps"]

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
  device_running[device]= device
  progOn[device] = "Inactive"
  onStatus[device] = "stopped"
  onTotalSteps[device] = 2
  onStep[device] = 0
  onNewLevel[device] = 1
  onStepLevel[device] = 1
  onTimer[device]= 2
  dimJump[device] = "yes"
  progOff[device] = "Inactive"
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
 
  --- ON dimming values calculation
    if device.preferences.onTimeMax > 0.7 then onTimer[device] = 2 else onTimer[device] = 0.5 end
     onTotalSteps[device] = math.floor(device.preferences.onTimeMax * 60 / onTimer[device])
     onStepLevel[device] = ((device.preferences.onLevelEnd - device.preferences.onLevelStart)+ 0.1) / onTotalSteps[device]
     print ("turnOn.onTotalSteps,turnOn.onStepLevel =", onTotalSteps[device], onStepLevel[device])

     -- OFF dimming values calculation
     if device.preferences.offTimeMax > 0.7 then offTimer[device] = 2 else offTimer[device] = 0.5 end
     offTotalSteps[device] = math.floor(device.preferences.offTimeMax * 60 / offTimer[device])
     if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) == nil then
      offLevelStart[device] = math.floor(device.preferences.onLevelEnd/0.393)
     else
      offLevelStart[device] = math.floor(device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
     end
     offStepLevel[device] = ((offLevelStart[device]+0.1)- device.preferences.offLevelEnd) / offTotalSteps[device]
     print ("turnOff.onTotalSteps,turnOff.onStepLevel =", offTotalSteps[device], offStepLevel[device])

  ----- print device init values for debug------
  for id, value in pairs(device_running) do
   print("device_running[id]=",device_running[id])
   print("device_running, progOn=",device_running[id],progOn[id])
   print("device_running[id], onStatus=",device_running[id],onStatus[id])
   print("device_running, onTotalSteps=", device_running[id],onTotalSteps[id])
   print("device_running,onStep=", device_running[id],onStep[id])
   print("device_running,onNewLevel=", device_running[id],onNewLevel[id])
   print("device_running,offStepLevel=", device_running[id],onStepLevel[id])
   print("device_running,dimJump=", device_running[id],dimJump[id])
   print("device_running, progOff=",device_running[id],progOff[id])
   print("device_running,offStatus=", device_running[id],offStatus[id])
   print("device_running,offTotalSteps=", device_running[id],offTotalSteps[id])
   print("device_running,offStep=", device_running[id],offStep[id])
   print("device_running,offNewLevel=", device_running[id],offNewLevel[id])
   print("device_running,offStepLevel=", device_running[id],offStepLevel[id])
   print("device_running,offLevelStart=", device_running[id],offLevelStart[id])
   print("device_running,offJump=", device_running[id],offJump[id])

   print("device_running, random_Step=",device_running[id],random_Step[id])
   print("device_running, random_totalStep=",device_running[id],random_totalStep[id])
   print("device_running, random_timer=",device_running[id],random_timer[id])
  end
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
   end
  end
  
  -----print tables of devices no removed from driver ------
  for id, value in pairs(device_running) do
    print("device_running[id]",device_running[id])
    print("device_running, progOn=",device_running[id],progOn[id])
    print("device_running, onStatus=",device_running[id],onStatus[id])
    print("device_running, onTotalSteps=", device_running[id],onTotalSteps[id])
    print("device_running,onStep=", device_running[id],onStep[id])
    print("device_running,onStartDim=", device_running[id],onStartDim[id])
    print("device_running,onTimer=", device_running[id],onTimer[id])
    print("device_running,onNewLevel=", device_running[id],onNewLevel[id])
    print("device_running,offStepLevel=", device_running[id],onStepLevel[id])
    print("device_running,dimJump=", device_running[id],dimJump[id])
    print("device_running, progOff=",device_running[id],progOff[id])
    print("device_running,offStatus=", device_running[id],offStatus[id])
    print("device_running,offTotalSteps=", device_running[id],offTotalSteps[id])
    print("device_running,offStep=", device_running[id],offStep[id])
    print("device_running,offNewLevel=", device_running[id],offNewLevel[id])
    print("device_running,offStepLevel=", device_running[id],offStepLevel[id])
    print("device_running,offLevelStart=", device_running[id],offLevelStart[id])
    print("device_running,offJump=", device_running[id],offJump[id])
    print("device_running,offTimer=", device_running[id],offTimer[id])

    print("device_running, random_Step=",device_running[id],random_Step[id])
    print("device_running, random_totalStep=",device_running[id],random_totalStep[id])
    print("device_running, random_timer=",device_running[id],random_timer[id])
 end
end

-----------------------------------------------
---------------- Timers Cancel ----------------
local function timers_Cancel(_,device)
  for timer in pairs(device.thread.timers) do
    print("<<<<< Cancel all timer >>>>>")
    device.thread:cancel_timer(timer)
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
      offLevelStart[device] = math.floor(device.preferences.onLevelEnd/0.393)
     else
      offLevelStart[device] = math.floor(device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
     end
     offStepLevel[device] = ((offLevelStart[device]+ 0.1) - device.preferences.offLevelEnd) / offTotalSteps[device]
     print ("turnOff.onTotalSteps,turnOff.onStepLevel =", offTotalSteps[device], offStepLevel[device])
    end  
  end
 end

 --------------------------------------------------------
 --------- Handler Random ON-OFF ------------------------

function driver_handler.random_on_off_handler(_,device,command)

      ---- Timers Cancel ------
      timers_Cancel(_,device)

  print("randomOnOff Value", command.args.value)
  if command.args.value == "Inactive" then

    -- send zigbee event
    device:send(OnOff.server.commands.Off(device))
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    --emit time for next change
    local nextChange = "Inactive"
    device:emit_event(random_Next_Step.randomNext(nextChange))

  elseif command.args.value == "Active" then
   device:emit_event(random_On_Off.randomOnOff("Active"))
   -----cancel progressive ON & OFF
   progOn[device] = "Inactive"
   device:emit_event(prog_On.progOn("Inactive"))
   progOff[device] = "Inactive"
   random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
   random_Step[device] = 0
   random_totalStep[device] = math.ceil(random_timer[device] / 30)
   local nextChange= string.format("%.1f",random_timer[device]/60)
   nextChange = nextChange.." min"
   --local nextChange= os.date("%H:%M:%S",os.time() + random_timer[device])

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
      local nextChange= string.format("%.1f",(random_totalStep[device]-random_Step[device]) * 30 /60)
      nextChange = nextChange.." min"
        --emit time for next change
      device:emit_event(random_Next_Step.randomNext(nextChange))

      if random_Step[device] >= random_totalStep[device] then
        local newState = math.random(0, 1)
        print("newState =", newState)
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
        local nextChange= string.format("%.1f",(random_totalStep[device]-random_Step[device]) * 30 /60)
        nextChange = nextChange.." min"
        --local nextChange= os.date("%H:%M:%S",os.time() + random_timer[device])

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
    device:emit_event(prog_On.progOn("Inactive"))
  elseif command.args.value == "Active" then
    progOn[device] = "Active"
    device:emit_event(prog_On.progOn("Active"))
    
    ---- Cancel Random On-OFF
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
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
    device:emit_event(prog_Off.progOff("Inactive"))
  elseif command.args.value == "Active" then
    progOff[device] = "Active"
    device:emit_event(prog_Off.progOff("Active"))

    ---- Cancel Random On-OFF
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))
  end
  print("progOff =", progOn[device])
end


-----------------------------------------------
--------- level_Steps_handler -----------------

function driver_handler.level_Steps_handler(_, device, command)

  ---- Timers Cancel ------
  timers_Cancel(_,device)

    ---- Cancel Random On-OFF
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))

  ---- next level calculation  
  print("Level Steps Value =", command.args.value)
  local level = command.args.value
  device:emit_event(level_Steps.levelSteps(level))
  --print("Last Level=", device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
  level = level + device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
  if level > 100 then 
    level = 100
  elseif level < 0 then
    level =0
  end
  device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.ceil((level)/0.393), 0xFFFF))
end

-----------------------------------------------
--------- color_Temperature_Steps_handler -----------------

function driver_handler.color_Temperature_Steps_handler(self, device, command)
  print("<<<<<< estoy en color_Temperature_Steps_handler >>>>>>>")
  print("Color Temperature Steps Value =", command.args.value)

    ---- Cancel Random On-OFF
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:emit_event(random_Next_Step.randomNext("Inactive"))

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
---------------- TURN ON handler --------------

function driver_handler.on_handler (_, device, command)

  print("Command Value =", command.args.value)

      -- capability reference
    local attr = capabilities.switch.switch
    
    -- set level of preferences if current leve < 1 ----
    if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) == nil then
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.ceil(device.preferences.onLevelStart/0.393), 0xFFFF)) 
    elseif (device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)) <= 1 then
      device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.ceil(device.preferences.onLevelStart/0.393), 0xFFFF))  
    end
   
   ----- detect progressive turn On activated--
    if progOn[device]  ==  "Active" then
      print ("turnOn.onStatus =", onStatus[device])
     if onStatus[device] =="stopped" then
      --new
      if device.preferences.ifPushSwitch == "Change" then
        print("<<<<<<<<< Estoy en change on start Dim")
        onStartDim[device] = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
      else
       onStartDim[device] = device.preferences.onLevelStart
      end
      onStep[device] = -1
      onStatus[device] ="running"
      print ("turnOn.onTotalSteps =", onTotalSteps[device])
      print ("turnOn.onStepLevel =", onStepLevel[device])
      
      -------- turn on: 2 or 1 sec timer dimming ON --------
      device.thread:call_on_schedule(onTimer[device], 
       function ()
        if onStatus[device] =="running" then
          if onStep[device] == -1 then
            onNewLevel[device] = onStartDim[device]
            onStep[device] = onStep[device] + 1
            device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.ceil(onNewLevel[device]/0.393), 0xFFFF))
          else
            onStep[device] = onStep[device] + 1 
            onNewLevel[device] = onNewLevel[device] + onStepLevel[device]
            print("onStep=",onStep[device])
            if device.preferences.onLevelEnd >= device.preferences.onLevelStart then
             if onNewLevel[device] >= device.preferences.onLevelEnd or onStep[device] >= onTotalSteps[device] then 
              onNewLevel[device] = device.preferences.onLevelEnd
              onStatus[device] ="stopped"
              for timer in pairs(device.thread.timers) do
               device.thread:cancel_timer(timer)
              end           
             end
            else
             if onNewLevel[device] < device.preferences.onLevelEnd and onStep[device] >= onTotalSteps[device] then
              onNewLevel[device] = device.preferences.onLevelEnd
              onStatus[device] ="stopped"
              for timer in pairs(device.thread.timers) do
                device.thread:cancel_timer(timer)
              end            
             end
            end
              print ("turnOn.onNewLevel=",onNewLevel[device])
              print("Last Level=", device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
              device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.ceil(onNewLevel[device]/0.393), 0xFFFF))
          end 
        end
       end)
     end
    end

    --- send status ON without dimming---
      if progOn[device]  ==  "Inactive" then
      -- send zigbee event
      device:send(OnOff.server.commands.On(device))
      -- send platform event
      device:emit_event_for_endpoint(1, attr.on())
     end
  end
 
  -----------------------------------------
  ------------ TURN OFF handler -----------
  
function driver_handler.off_handler (_, device, command)
    -- capability reference
    local attr = capabilities.switch.switch

      -- detect switch Pushsed when progressive On or Off running ---
   if onStatus[device] == "running" or offStatus[device] == "running" then

    ---- Cancel Timers
    timers_Cancel(_,device)

     -- progressive Off is running
    if offStatus[device] == "running" then
     offStatus[device]="stopped"
     if (device.preferences.ifPushSwitch == "Change") then
      if progOn[device] == "Active" then
        device:emit_event_for_endpoint(1, attr.on())
        driver_handler.on_handler(_,device, command)
        offJump[device]="yes"
      end
       dimJump[device] ="yes" 
      else
       dimJump[device] ="yes"
       offJump[device] = "yes"
       if (device.preferences.ifPushSwitch == "Off")  then device:send(OnOff.server.commands.Off(device))end
       if (device.preferences.ifPushSwitch == "End") then 
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.floor((device.preferences.offLevelEnd+0.1)/0.393), 0xFFFF))
        device:send(zcl_clusters.OnOff.attributes.OnOff:read(device))
       end
       if (device.preferences.ifPushSwitch == "Stop") then device:emit_event_for_endpoint(1, attr.on()) end
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
        device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.ceil(device.preferences.onLevelEnd / 0.393), 0xFFFF))
        offJump[device] = "yes"
        device:emit_event_for_endpoint(1, attr.on())
       else
        if device.preferences.ifPushSwitch == "Stop" then offJump[device] = "yes" end
        device:emit_event_for_endpoint(1, attr.on())
       end 
      end 
    end
   end 
  
   ---- detect progressive turn OFF is activated -----

    if (onStatus[device] == "stopped" and offStatus[device] == "stopped") then
      ---- dimJump is "no" because need change direction of dimming
     if progOff[device]  ==  "Active" and dimJump[device]== "no" then 
      if device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME) <= device.preferences.offLevelEnd then     
       if offStatus[device] =="stopped" and onStatus[device] =="stopped" then offJump[device] = "no" end
      elseif offStatus[device] =="stopped" then
       offLevelStart[device] = math.floor(device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
       offStepLevel[device] = ((offLevelStart[device]+ 0.1)- device.preferences.offLevelEnd) / offTotalSteps[device]
       offStep[device] = -1
       offStatus[device] ="running"
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
            device:emit_event_for_endpoint(1, attr.on())
            device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.ceil(offNewLevel[device]/0.395), 0xFFFF))
          else
            offStep[device] = offStep[device] + 1 
            offNewLevel[device] = (offNewLevel[device] - offStepLevel[device])
            print("offStep=", offStep[device])
            if offNewLevel[device] <= device.preferences.offLevelEnd or offStep[device] >= offTotalSteps[device] then 
             offNewLevel[device] = device.preferences.offLevelEnd
             offStatus[device] ="stopped"
             for timer in pairs(device.thread.timers) do
              device.thread:cancel_timer(timer)
             end
            end
              print ("turnOff.offNewLevel=",offNewLevel[device])
              print("Last Level=", device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME))
              device:send(zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, math.ceil(offNewLevel[device]/0.393), 0xFFFF))
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
      -- send platform event
       device:emit_event_for_endpoint(1, attr.off())
      end
    end
    offJump[device] = "no"
    dimJump[device]= "no"
  end

  return driver_handler