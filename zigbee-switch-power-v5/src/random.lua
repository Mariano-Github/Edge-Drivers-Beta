--- Smartthings library load ---
local capabilities = require "st.capabilities"
--local ZigbeeDriver = require "st.zigbee"
--local defaults = require "st.zigbee.defaults"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
--local zigbee_constants = require "st.zigbee.constants"
--local ElectricalMeasurement = zcl_clusters.ElectricalMeasurement
--local SimpleMetering = zcl_clusters.SimpleMetering
local Groups = zcl_clusters.Groups

local write = require "writeAttribute"


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
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]

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
  if device:get_field("random_state") ~= "Inactive" then  
    driver_handler.random_on_off_handler(self,device,"Active")
  end

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
      end
   
      if id == "groupRemove" then
        print("Remove Groups >>>>>>>>>>>>>>>>>")
        if device.preferences[id] > 0 then
         device:send(Groups.server.commands.RemoveGroup(device, device.preferences[id]))
        else
         device:send(Groups.server.commands.RemoveAllGroups(device, {}))
        end
        device:send(Groups.server.commands.GetGroupMembership(device, {}))
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
      -- Any Preference timer mode changed restart timer handler
      elseif id == "randomMin" or id == "randomMax" or id == "onTime" or id == "offTime" then
        if device:get_field("random_state") ~= "Inactive" then  
          driver_handler.random_on_off_handler(self,device,"Active")
        end
      end  

      --- Configure on-off cluster, attributte 0x8002 and 4003 to value restore state in preferences
      if id == "restoreState" then
        print("<<< Write restore state >>>")
        local value_send = tonumber(newParameterValue[device])
        local data_value = {value = value_send, ID = 0x30}
        local cluster_id = {value = 0x0006}
        --write atribute for zigbee standard devices
        local attr_id = 0x4003
        write.write_attribute_function(device, cluster_id, attr_id, data_value)

        --write atribute for Tuya devices (Restore previous state = 0x02)
        if newParameterValue[device] == "255" then data_value = {value = 0x02, ID = 0x30} end
        attr_id = 0x8002
        write.write_attribute_function(device, cluster_id, attr_id, data_value)
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
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
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
  local nextChange = "Inactive"
  if command == "Active" then
    --random_state = "Active"
    random_state = device:get_field("random_state")
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
 nextChange = "Inactive"
 device:emit_event(random_Next_Step.randomNext(nextChange))

 elseif random_state == "Random" or random_state == "Program" then
  device:emit_event(random_On_Off.randomOnOff(random_state))
  device:set_field("random_state", random_state, {persist = true})
 
  if random_state == "Random" then
   --Random timer calculation
   random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
   random_Step[device] = 0
   random_totalStep[device] = math.ceil(random_timer[device] / 30)
   nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
  else
    device:send(OnOff.server.commands.On(device))
    device:set_field("last_state", "on", {persist = false})
    --Program timer calculation
    random_timer[device] = device.preferences.onTime * 60
    random_Step[device] = 0
    random_totalStep[device] = math.ceil(random_timer[device] / 30)
    nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
   end
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
      random_timer[device] = device.preferences.onTime * 60
      device:send(OnOff.server.commands.Off(device))
    else
      random_timer[device] = device.preferences.offTime * 60
      device:send(OnOff.server.commands.On(device))
    end
    if random_state == "Random" then
      random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
      random_Step[device] = 0
      random_totalStep[device] = math.ceil(random_timer[device] / 30)
      nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
    else
      --Program timer calculation
      random_Step[device] = 0
      random_totalStep[device] = math.ceil(random_timer[device] / 30)
      nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
    end

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