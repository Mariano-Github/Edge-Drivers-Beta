-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local device_management = require "st.zigbee.device_management"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local data_types = require "st.zigbee.data_types"

local write_attribute = require "st.zigbee.zcl.global_commands.write_attribute"
local zcl_messages = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local zb_const = require "st.zigbee.constants"

-- Custom Capabilities Declaration
local switch_All_On_Off = capabilities["legendabsolute60149.switchAllOnOff1"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

------- Write attribute ----
local function write_attribute_function(device, cluster_id, attr_id, data_value)
  local write_body = write_attribute.WriteAttribute({
   write_attribute.WriteAttribute.AttributeRecord(attr_id, data_types.ZigbeeDataType(data_value.ID), data_value.value)})

   local zclh = zcl_messages.ZclHeader({
     cmd = data_types.ZCLCommandId(write_attribute.WriteAttribute.ID)
   })
   local addrh = messages.AddressHeader(
       zb_const.HUB.ADDR,
       zb_const.HUB.ENDPOINT,
       device:get_short_address(),
       device:get_endpoint(cluster_id.value),
       zb_const.HA_PROFILE_ID,
       cluster_id.value
   )
   local message_body = zcl_messages.ZclMessageBody({
     zcl_header = zclh,
     zcl_body = write_body
   })
   device:send(messages.ZigbeeMessageTx({
     address_header = addrh,
     body = message_body
   }))
  end

--- Update preferences after infoChanged recived ---
local function do_preferences (self, device)
  for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id])
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:",id,"oldPreferenceValue:",oldPreferenceValue, "newParameterValue: >>", newParameterValue)
 
      ------ Change profile & Icon
      if id == "changeProfileThreePlug" then
       if newParameterValue == "Single" then
        device:try_update_metadata({profile = "three-outlet"})
       else
        device:try_update_metadata({profile = "three-outlet-multi"})
       end
      elseif id == "changeProfileThreeSw" then
        if newParameterValue == "Single" then
         device:try_update_metadata({profile = "three-switch"})
        else
         device:try_update_metadata({profile = "three-switch-multi"})
        end
      elseif id == "changeProfileTwoPlug" then
        if newParameterValue == "Single" then
          device:try_update_metadata({profile = "two-outlet"})
        else
          device:try_update_metadata({profile = "two-outlet-multi"})
        end
      elseif id == "changeProfileTwoSw" then
        if newParameterValue == "Single" then
         device:try_update_metadata({profile = "two-switch"})
        else
         device:try_update_metadata({profile = "two-switch-multi"})
        end
      elseif id == "changeProfileFourSw" then
        if newParameterValue == "Single" then
         device:try_update_metadata({profile = "four-switch"})
        else
         device:try_update_metadata({profile = "four-switch-multi"})
        end
      elseif id == "changeProfileFourPlug" then
        if newParameterValue == "Single" then
          device:try_update_metadata({profile = "four-outlet"})
        else
          device:try_update_metadata({profile = "four-outlet-multi"})
        end
      end  
      --- Configure on-off cluster, attributte 0x8002 and 4003 to value restore state in preferences
      if id == "restoreState" then
        print("<<< Write restore state >>>")
        local value_send = tonumber(newParameterValue)
        local data_value = {value = value_send, ID = 0x30}
        local cluster_id = {value = 0x0006}
        --write atribute for Tuya devices
        local attr_id = 0x4003
        write_attribute_function(device, cluster_id, attr_id, data_value)

        --write atribute for Tuya devices (Restore previous state = 0x02)
        if newParameterValue == "255" then data_value = {value = 0x02, ID = 0x30} end
        attr_id = 0x8002
        write_attribute_function(device, cluster_id, attr_id, data_value)
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

--- set All switch status
local function all_switches_status(self,device)

  print("all_switches_status >>>>>")
   for id, value in pairs(device.preferences) do
     local total_on = 0
     local  total = 2
     local status_Text = ""
     if id == "changeProfileFourPlug" or id == "changeProfileFourSw" then
       total = 4
       if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
         total_on = total_on + 1
         status_Text = status_Text.."S1:On "
       end
       if device:get_latest_state("switch2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
         total_on = total_on + 1
         status_Text = status_Text.."S2:On "
       end
       if device:get_latest_state("switch3", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
         total_on = total_on + 1
         status_Text = status_Text.."S3:On "
       end
       if device:get_latest_state("switch4", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
         total_on = total_on + 1
         status_Text = status_Text.."S4:On "
       end
       --print("Total_on >>>>>>", total_on,"Total >>>",total)
   
       if total_on == total then
        device:emit_event(switch_All_On_Off.switchAllOnOff("All On"))
       elseif total_on == 0 then
        device:emit_event(switch_All_On_Off.switchAllOnOff("All Off"))
       elseif total_on > 0 and total_on < total then
        device:emit_event(switch_All_On_Off.switchAllOnOff(status_Text))
       end
 
    elseif id == "changeProfileThreePlug" or id == "changeProfileThreeSw" then
     total = 3
     if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
       total_on = total_on + 1
       status_Text = status_Text.."S1:On "
     end
     if device:get_latest_state("switch2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
       total_on = total_on + 1
       status_Text = status_Text.."S2:On "
     end
     if device:get_latest_state("switch3", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
       total_on = total_on + 1
       status_Text = status_Text.."S3:On "
     end
     --print("Total_on >>>>>>", total_on,"Total >>>",total)
   
     if total_on == total then
      device:emit_event(switch_All_On_Off.switchAllOnOff("All On"))
     elseif total_on == 0 then
      device:emit_event(switch_All_On_Off.switchAllOnOff("All Off"))
     elseif total_on > 0 and total_on < total then
      device:emit_event(switch_All_On_Off.switchAllOnOff(status_Text))
     end
 
    elseif id == "changeProfileTwoPlug" or id == "changeProfileTwoSw" then
     if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
       total_on = total_on + 1
       status_Text = status_Text.."S1:On "
     end
     if device:get_latest_state("switch2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
       total_on = total_on + 1
       status_Text = status_Text.."S2:On "
     end
     --print("Total_on >>>>>>", total_on,"Total >>>",total)
   
     if total_on == total then
      device:emit_event(switch_All_On_Off.switchAllOnOff("All On"))
     elseif total_on == 0 then
      device:emit_event(switch_All_On_Off.switchAllOnOff("All Off"))
     elseif total_on > 0 and total_on < total then
      device:emit_event(switch_All_On_Off.switchAllOnOff(status_Text))
     end
 
    end
   end
 end

 --- return endpoint from component_id
local ep_ini = 1

local function component_to_endpoint(device, component_id)
  if component_id == "main" then
    ep_ini = device.fingerprinted_endpoint_id
    return device.fingerprinted_endpoint_id
  else
    local ep_num = component_id:match("switch(%d)")
    if ep_num == "2" then
      return ep_ini + 1
     --return ep_num and tonumber(ep_num) or device.fingerprinted_endpoint_id
    elseif ep_num == "3" then
      return ep_ini + 2
    elseif ep_num == "4" then
      return ep_ini + 3
    end
  end
end

--- return Component_id from endpoint
local function endpoint_to_component(device, ep)
  if ep == device.fingerprinted_endpoint_id then
    ep_ini = ep
    return "main"
  else
    if ep == ep_ini + 1 then
      --return string.format("switch%d", ep)
      return "switch2"
    elseif ep == ep_ini + 2 then
      return "switch3"
    elseif ep == ep_ini + 3 then
      return "switch4"
    end 
  end
end

--do_configure
local function do_configure(self, device)
  if device:get_manufacturer() ~= "_TZ3000_fvh3pjaz" then
    device:configure()
  else
    --device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, self.environment_info.hub_zigbee_eui):to_endpoint (1))
    --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 120):to_endpoint (1))
    --device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, self.environment_info.hub_zigbee_eui):to_endpoint (2))
    --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 120):to_endpoint (2))
  end
end

---device init ----
local function device_init (self, device)
  --device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)
  device:set_component_to_endpoint_fn(component_to_endpoint)

      ------ Selected profile & Icon
      for id, value in pairs(device.preferences) do
        print("<< Preference name: >>", id, "Preference value:", device.preferences[id])
    if id == "changeProfileThreePlug" then
      if device.preferences[id] == "Single" then
       device:try_update_metadata({profile = "three-outlet"})
      else
       device:try_update_metadata({profile = "three-outlet-multi"})
      end
     elseif id == "changeProfileThreeSw" then
       if device.preferences[id] == "Single" then
        device:try_update_metadata({profile = "three-switch"})
       else
        device:try_update_metadata({profile = "three-switch-multi"})
       end
     elseif id == "changeProfileTwoPlug" then
       if device.preferences[id] == "Single" then
         device:try_update_metadata({profile = "two-outlet"})
       else
         device:try_update_metadata({profile = "two-outlet-multi"})
       end
     elseif id == "changeProfileTwoSw" then
       if device.preferences[id] == "Single" then
        device:try_update_metadata({profile = "two-switch"})
       else
        device:try_update_metadata({profile = "two-switch-multi"})
       end
     elseif id == "changeProfileFourSw" then
       if device.preferences[id] == "Single" then
        device:try_update_metadata({profile = "four-switch"})
       else
        device:try_update_metadata({profile = "four-switch-multi"})
       end
     elseif id == "changeProfileFourPlug" then
       if device.preferences[id] == "Single" then
         device:try_update_metadata({profile = "four-outlet"})
       else
         device:try_update_metadata({profile = "four-outlet-multi"})
       end
     end
  end

  --- special cofigure for this device, read attribute on-off every 120 sec and not configure reports
  if device:get_manufacturer() == "_TZ3000_fvh3pjaz" then
    --device:refresh()
    --- Configure on-off cluster, attributte 0x4001 to 0xFFFF
    --local data_value = {value = 0x0000, ID = 0x21}
    --local cluster_id = {value = 0x0006}
    --local attr_id = 0x4001
    --write_attribute_function(device, cluster_id, attr_id, data_value)

    --- Configure basic cluster, attributte 0x0099 to 0x1
    local data_value = {value = 0x01, ID = 0x20}
    local cluster_id = {value = 0x0000}
    local attr_id = 0x0099
    write_attribute_function(device, cluster_id, attr_id, data_value)

    --device:send(OnOff.server.commands.Off(device):to_endpoint(1))
    --device:send(OnOff.server.commands.Off(device):to_endpoint(2))
    print("<<<<<<<<<<< read attribute 0xFF, 1 & 2 >>>>>>>>>>>>>")
    device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (0xFF))
    device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (1))
    device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (2))

    ---- Timers Cancel ------
      for timer in pairs(device.thread.timers) do
        print("<<<<< Cancelando timer >>>>>")
        device.thread:cancel_timer(timer)
     end
    --- Refresh atributte read schedule
    --print("<<<<<<<<<<<<< Timer read attribute >>>>>>>>>>>>>>>>")
    device.thread:call_on_schedule(
    120,
    function ()
      if device:get_manufacturer() == "_TZ3000_fvh3pjaz" then
        print("<<< Timer read attribute >>>")
        device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (1))
        device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (2))
      end
      --local refresh = device:refresh ()
      --device.thread:call_with_delay(2, function(d)
        --device:refresh()
      --end)
    end,
    'Refresh schedule') 
  end
end

------ do_configure device
local function driver_Switched(self,device)
  device:refresh()
  if device:get_manufacturer() ~= "_TZ3000_fvh3pjaz" then
    device:configure()
  end
end 


--- Command on handler ----
local function on_handler(self, device, command)
  -- capability reference
  local attr = capabilities.switch.switch
  -- parse component to endpoint
  local endpoint = device:get_endpoint_for_component_id(command.component)
  -- send zigbee event
  device:send(OnOff.server.commands.On(device):to_endpoint(endpoint))
  -- send platform event
  device:emit_event_for_endpoint(endpoint, attr.on())
 
  --- Set all_switches_status capability status
  device.thread:call_with_delay(2, function(d)
    all_switches_status(self, device)
  end)
end

--- Command off handler ----
local function off_handler(self, device, command)
  -- capability reference
  local attr = capabilities.switch.switch
  -- parse component to endpoint
  local endpoint = device:get_endpoint_for_component_id(command.component)    
  -- send zigbee event
  device:send(OnOff.server.commands.Off(device):to_endpoint(endpoint))
  -- send platform event
  device:emit_event_for_endpoint(endpoint, attr.off())

  --- Set all_switches_status capability status
  device.thread:call_with_delay(2, function(d)
    all_switches_status(self, device)
  end)
end

--- read zigbee attribute OnOff messages ----
local function on_off_attr_handler(self, device, value, zb_rx)
  print ("function: on_off_attr_handler")
  --print("LQI >>>>>",zb_rx.lqi.value)
  --print("RSSI >>>>>",zb_rx.rssi.value)
  --print (string.format("src_Address: 0x%04X", zb_rx.address_header.src_addr.value))
  --local metrics = string.format("DNI: 0x%04X", zb_rx.address_header.src_addr.value)..",  LQI: "..zb_rx.lqi.value..",  RSSI: "..zb_rx.rssi.value.." dBm"
  local visible_satate = false
  if device.preferences.signalMetricsVisibles == "Yes" then
    visible_satate = true
  end
  local metrics = "LQI: "..zb_rx.lqi.value.." ... RSSI: "..zb_rx.rssi.value.." dBm"
  device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))

  local src_endpoint = zb_rx.address_header.src_endpoint.value
  local attr_value = value.value

  --- Emit event from zigbee message recived
  if attr_value == false then
    device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.off())
  else
    device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.on())
  end
  print ("src_endpoint =", zb_rx.address_header.src_endpoint.value , "value =", value.value)

  --- Set all_switches_status capability status
  device.thread:call_with_delay(2, function(d)
    all_switches_status(self, device)
  end)

end

---- switch_All_On_Off_handler
local function switch_All_On_Off_handler(self, device, command)
  print("command.args.value >>>>>", command.args.value)
  local state = command.args.value
  device:emit_event(switch_All_On_Off.switchAllOnOff(state))
  local attr = capabilities.switch.switch
  local ep_init = device:get_endpoint_for_component_id(command.component)

  for id, value in pairs(device.preferences) do
   --print("device. >>>>>",device:get_profileReference())
   if id == "changeProfileFourPlug" or id == "changeProfileFourSw" then
    if state == "All Off" then
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init))
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init + 1))
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init + 2))
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init + 3))
    else
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init))
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init + 1))
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init + 2))
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init + 3))
    end
  elseif id == "changeProfileThreePlug" or id == "changeProfileThreeSw" then
    if state == "All Off" then
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init))
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init + 1))
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init + 2))
    else
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init))
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init + 1))
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init + 2))
    end
  elseif id == "changeProfileTwoPlug" or id == "changeProfileTwoSw" then
    if state == "All Off" then
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init))
      device:send(OnOff.server.commands.Off(device):to_endpoint(ep_init + 1))
    else
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init))
      device:send(OnOff.server.commands.On(device):to_endpoint(ep_init + 1))
    end  
   end
  end
end

---- Driver configure ---------
local zigbee_outlet_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.refresh
  },
  lifecycle_handlers = {
    init = device_init,
    driverSwitched = driver_Switched,
    infoChanged = do_preferences,
    doConfigure = do_configure
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.OnOff.ID] = {
         [zcl_clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
     }
   }
},
capability_handlers = {
  [capabilities.switch.ID] = {
    [capabilities.switch.commands.on.NAME] = on_handler,
    [capabilities.switch.commands.off.NAME] = off_handler
  },
  [switch_All_On_Off.ID] = {
    [switch_All_On_Off.commands.setSwitchAllOnOff.NAME] = switch_All_On_Off_handler,
  },
},
}

defaults.register_for_default_handlers(zigbee_outlet_driver_template, zigbee_outlet_driver_template.supported_capabilities)
local zigbee_outlet = ZigbeeDriver("Zigbee_Multi_Switch", zigbee_outlet_driver_template)
zigbee_outlet:run()