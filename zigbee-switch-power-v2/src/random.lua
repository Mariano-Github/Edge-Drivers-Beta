--- Smartthings library load ---
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local zigbee_constants = require "st.zigbee.constants"

---- Load handlers written in dimmer.lua
local driver_handler = {}

--- Device running and update preferences variables
local device_running = {}
local oldPreferenceValue ={}
local newParameterValue ={}

-- Random tables variables
local random_Step = {}
local random_totalStep = {}
local random_timer = {}

-- Custom Capability Randon On Off
local random_On_Off = capabilities["legendabsolute60149.randomOnOff1"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep"]

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
  oldPreferenceValue[device] = "-"
  newParameterValue[device] = "-"
  random_Step[device] = 1
  random_totalStep[device] =2
  random_timer[device] = math.random(10, 20)

  -- send zigbee event if random on-off Inactive or nil
  print("<<<< random_state >>>>",device:get_field("random_state"))
  if device:get_field("random_state") == "Inactive"  or device:get_field("random_state") == nil then
   device:emit_event(random_On_Off.randomOnOff("Inactive"))
   device:emit_event(random_Next_Step.randomNext("Inactive"))
   device:set_field("random_state", "Inactive", {persist = true})
  end

  ----- print device init values for debug------
  for id, value in pairs(device_running) do
   print("device_running[id]=",device_running[id])
   print("device_running, random_Step=",device_running[id],random_Step[id])
   print("device_running, random_totalStep=",device_running[id],random_totalStep[id])
   print("device_running, random_timer=",device_running[id],random_timer[id])
  end
 end
  --restart random on-off if active
  print("random_state >>>>>",device:get_field("random_state"))
  if device:get_field("random_state") == "Active" then  
    driver_handler.random_on_off_handler(self,device,"Active")
  end
--- save device divisor
 local power_divisor = 100
 local energy_divisor = 1
 if device:get_manufacturer() == "sengled" then
  power_divisor = 10
  energy_divisor = 10000
 end
  device:set_field(zigbee_constants.SIMPLE_METERING_DIVISOR_KEY, power_divisor, {persist = true})
  device:set_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, energy_divisor, {persist = true})

end

---- do_removed device procedure: delete all device data
function driver_handler.do_removed(self,device)
  for id, value in pairs(device_running) do
    if device_running[id] == device then
    device_running[device] =nil
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
    print("device_running, random_Step=",device_running[id],random_Step[id])
    print("device_running, random_totalStep=",device_running[id],random_totalStep[id])
    print("device_running, random_timer=",device_running[id],random_timer[id])
  end
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
      for timer in pairs(device.thread.timers) do
       print("<<<<< Cancelando timer >>>>>")
       device.thread:cancel_timer(timer)
      end 
      ------ Change profile & Icon
      if id == "changeProfile" then
       if newParameterValue[device] == "Switch" then
        device:try_update_metadata({profile = "switch-power"})
       elseif newParameterValue[device] == "Plug" then
        device:try_update_metadata({profile = "switch-power-plug"})
       elseif newParameterValue[device] == "Light" then
        device:try_update_metadata({profile = "switch-power-light"})
       end
      elseif id == "changeProfileEner" then
        if newParameterValue[device] == "Switch" then
         device:try_update_metadata({profile = "switch-power-energy"})
        elseif newParameterValue[device] == "Plug" then
         device:try_update_metadata({profile = "switch-power-energy-plug"})
        elseif newParameterValue[device] == "Light" then
         device:try_update_metadata({profile = "switch-power-energy-light"})
        end
      end  
    end
  end
  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len)
end

 --------------------------------------------------------
 --------- Handler Random ON-OFF ------------------------

function driver_handler.random_on_off_handler(_,device,command)

  ---- Timers Cancel ------
  for timer in pairs(device.thread.timers) do
    print("<<<<< Cancel all timer >>>>>")
    device.thread:cancel_timer(timer)
  end
  
  local random_state = "-"
  if command == "Active" then
    random_state = "Active"
  else
    random_state = command.args.value
  end
 
  print("randomOnOff Value", random_state)
 if random_state == "Inactive" then

 -- send zigbee event
 device:send(OnOff.server.commands.Off(device))
 device:emit_event(random_On_Off.randomOnOff("Inactive"))
 device:set_field("random_state", "Inactive", {persist = true})
 --emit time for next change
 local nextChange = "Inactive"
 device:emit_event(random_Next_Step.randomNext(nextChange))

 elseif random_state == "Active" then
  device:emit_event(random_On_Off.randomOnOff("Active"))
  device:set_field("random_state", "Active", {persist = true})

  --Random timer calculation
  random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
  random_Step[device] = 0
  random_totalStep[device] = math.ceil(random_timer[device] / 30)
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

   if random_Step[device] >= random_totalStep[device] then

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
    print("NEW-random_totalStep=",random_totalStep[device])
    print("NextChange=",nextChange)
   end
  end
  ,'Random-ON-OFF')   
 end
end

  return driver_handler