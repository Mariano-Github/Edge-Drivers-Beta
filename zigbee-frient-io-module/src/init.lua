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

------ Author Mariano Colmenarejo (Oct 2023) --------
------ Version 1 -----------------
-- link to manual: https://www.elektroimportoren.no/docs/lib/4514810-Brukerveiledning-5.pdf

local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local device_management = require "st.zigbee.device_management"
--local data_types = require "st.zigbee.data_types"
local zcl_global_commands = require "st.zigbee.zcl.global_commands"
local Status = require "st.zigbee.generated.types.ZclStatus"

--ZCL
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local BasicInput = zcl_clusters.BasicInput

--Capability
local capabilities = require "st.capabilities"

--local write = require "writeAttribute"
local child_devices = require "child-devices"
local signal = require "signal-metrics"

-- Custom Capabilities Declaration
local switch_All_On_Off = capabilities["legendabsolute60149.switchAllOnOff1"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

-- Emit event for all Switch On-Off and child device
local function emit_event_all_On_Off(driver, device, total_on, total, status_Text)
  if total_on == total then
    device:emit_event(switch_All_On_Off.switchAllOnOff("All On"))
  elseif total_on == 0 then
    device:emit_event(switch_All_On_Off.switchAllOnOff("All Off"))
  elseif total_on > 0 and total_on < total then
    device:emit_event(switch_All_On_Off.switchAllOnOff(status_Text))
  end
end

--- set All switch status
local function all_switches_status(driver,device)
  if device.preferences.logDebugPrint == true then
    print("all_switches_status >>>>>")
  end

  local total_on = 0
  local  total = 2
  local status_Text = ""
  if device:get_latest_state("switch1", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    total_on = total_on + 1
    status_Text = status_Text.."S1:On "
  end
  if device:get_latest_state("switch2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
    total_on = total_on + 1
    status_Text = status_Text.."S2:On "
  end
    --print("Total_on >>>>>>", total_on,"Total >>>",total)
    emit_event_all_On_Off(driver, device, total_on, total,status_Text)

end

 --- return endpoint from component_id
 local function component_to_endpoint(device, component_id)
  if device.preferences.logDebugPrint == true then
    print("<<<<< device.fingerprinted_endpoint_id >>>>>>",device.fingerprinted_endpoint_id)
  end

  if component_id == "main" then
    return 1
  elseif component_id == "switch1" then
    return 116
  elseif component_id == "switch2" then
    return 117
  elseif component_id == "in1" then
    return 112   
  elseif component_id == "in2" then
    return 113  
  elseif component_id == "in3" then
    return 114
  elseif component_id == "in4" then
    return 115
  end
end

--- return Component_id from endpoint
local function endpoint_to_component(device, ep)
  if device.preferences.logDebugPrint == true then
    print("<<<<< device.fingerprinted_endpoint_id >>>>>>",device.fingerprinted_endpoint_id)
  end

  if ep == 112 then
    return "in1"
  elseif ep == 113 then
    return "in2"
  elseif ep == 114 then
    return "in3"
  elseif ep == 115 then
    return "in4"
  elseif ep == 116 then
    return "switch1"
  elseif ep == 117 then
    return "switch2"
  end
end

--- Update preferences after infoChanged recived---
local function do_Preferences(driver, device, event, args)
  print("<< do_Prefrences >>")
  for id, value in pairs(device.preferences) do
    if device.preferences.logDebugPrint == true then
      print("device.preferences[infoChanged]=", device.preferences[id])
    end
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    -- temporal solution to delete old preferences variables
    if device:get_field(id) ~= nil then
      device:set_field(id, nil, {persist = false})
    end
    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:",id, "old value:",oldPreferenceValue, "new value:", newParameterValue)
      if id == "onOffReports" then
        -- Configure OnOff interval report
        local interval =  device.preferences.onOffReports
        if  device.preferences.onOffReports == nil then interval = 900 end
        local config ={
          cluster = zcl_clusters.OnOff.ID,
          attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
          minimum_interval = 0,
          maximum_interval = interval,
          data_type = zcl_clusters.OnOff.attributes.OnOff.base_type
        }
        device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, interval):to_endpoint (116))
        device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, interval):to_endpoint (117))
        --device:add_configured_attribute(config)
      
        --device:configure()
      elseif id == "switch1Child" then
        -- Call to Create child device
        if oldPreferenceValue ~= nil and newParameterValue == true then
          child_devices.create_new_device(driver, device, "switch1", "child-switch")
        end       
      elseif id == "switch2Child" then
        if oldPreferenceValue ~= nil and newParameterValue == true then
          child_devices.create_new_device(driver, device, "switch2", "child-switch")
        end
      elseif id == "childContact1" then
        if oldPreferenceValue ~= nil and newParameterValue == true then
          child_devices.create_new_device(driver, device, "in1", "child-contact")
        end
      elseif id == "childContact2" then
        if oldPreferenceValue ~= nil and newParameterValue == true then
          child_devices.create_new_device(driver, device, "in2", "child-contact")
        end
      elseif id == "childContact3" then
        if oldPreferenceValue ~= nil and newParameterValue == true then
          child_devices.create_new_device(driver, device, "in3", "child-contact")
        end
      elseif id == "childContact4" then
        if oldPreferenceValue ~= nil and newParameterValue == true then
          child_devices.create_new_device(driver, device, "in4", "child-contact")
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
  local firmware_full_version = device.data.firmwareFullVersion
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- do_init
local function do_init(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)

    device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)

    -- Configure OnOff interval report
    local interval =  device.preferences.onOffReports
    if  device.preferences.onOffReports == nil then interval = 900 end
    local config ={
      cluster = zcl_clusters.OnOff.ID,
      attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
      minimum_interval = 0,
      maximum_interval = interval,
      data_type = zcl_clusters.OnOff.attributes.OnOff.base_type
    }
    --device:add_configured_attribute(config)
  

    if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
      device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
    end

  end
end
-- do_Configure
local function do_configure(driver, device)
  print("<<<< do Configure >>>>")

  -- Configure OnOff interval report
  local interval =  device.preferences.onOffReports
  if  device.preferences.onOffReports == nil then interval = 900 end

  device:send(device_management.build_bind_request(device, BasicInput.ID, driver.environment_info.hub_zigbee_eui, 112):to_endpoint (112))
  device:send(BasicInput.attributes.PresentValue:configure_reporting(device, 0, 600):to_endpoint (112))
  device:send(device_management.build_bind_request(device, BasicInput.ID, driver.environment_info.hub_zigbee_eui, 113):to_endpoint (113))
  device:send(BasicInput.attributes.PresentValue:configure_reporting(device, 0, 600):to_endpoint (113))
  device:send(device_management.build_bind_request(device, BasicInput.ID, driver.environment_info.hub_zigbee_eui, 114):to_endpoint (114))
  device:send(BasicInput.attributes.PresentValue:configure_reporting(device, 0, 600):to_endpoint (114))
  device:send(device_management.build_bind_request(device, BasicInput.ID, driver.environment_info.hub_zigbee_eui, 115):to_endpoint (115))
  device:send(BasicInput.attributes.PresentValue:configure_reporting(device, 0, 600):to_endpoint (115))
  device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, driver.environment_info.hub_zigbee_eui, 116):to_endpoint (116))
  device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, interval):to_endpoint (116))
  device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, driver.environment_info.hub_zigbee_eui, 117):to_endpoint (117))
  device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, interval):to_endpoint (117))
end

---- switch_All_On_Off_handler
local function switch_All_On_Off_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("command >>>>>", command)
    print("command.args.value >>>>>", command.args.value)
  end
  local ep_init = 116
  local state = ""
  local attr = capabilities.switch.switch
  if command ~= "All On" and  command ~= "All Off" then    ---- commad with this values is from child device command
    state = command.args.value
    device:emit_event(switch_All_On_Off.switchAllOnOff(state))
    ep_init = device:get_endpoint_for_component_id(command.component)
  else
    state = command
  end

  if state == "All Off" then
    device:send(OnOff.server.commands.Off(device):to_endpoint(116))
    device:send(OnOff.server.commands.Off(device):to_endpoint(117))
  else
    device:send(OnOff.server.commands.On(device):to_endpoint(116))
    device:send(OnOff.server.commands.On(device):to_endpoint(117))
  end    
end

--- Command on handler ---- 
local function on_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<<< On command Handler >>>>")
  end
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:send_to_component(command.component, zcl_clusters.OnOff.server.commands.On(device))
  else
    local parent_device = device:get_parent_device()
    if parent_device.preferences.logDebugPrint == true then
      print("<<< parent_device_id >>>", parent_device)
    end
    device:emit_event(capabilities.switch.switch.on())

    local component = device.parent_assigned_child_key
    if component ~= "main" then
      -- send comamd On to parent device
      parent_device:send_to_component(component, OnOff.server.commands.On(parent_device))
    end
  end
end

--- Command off handler ----
local function off_handler(driver, device, command)
  if device.preferences.logDebugPrint == true then
    print("<<<< Off command Handler >>>>")
  end
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    
    device:send_to_component(command.component, zcl_clusters.OnOff.server.commands.Off(device))
    
  else
    local parent_device = device:get_parent_device()
    if parent_device.preferences.logDebugPrint == true then
      print("<<< parent_device_id >>>", parent_device)
    end
    device:emit_event(capabilities.switch.switch.off())

    local component = device.parent_assigned_child_key
    if component ~= "main" then
      -- send comamd Off to parent device
      parent_device:send_to_component(component, OnOff.server.commands.Off(parent_device))
    end
  end
end

--- read zigbee attribute OnOff messages ----
local function on_off_attr_handler(driver, device, value, zb_rx)
  if device.preferences.logDebugPrint == true then
    print ("function: on_off_attr_handler")
  end

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)

    -- emit signal metrics
    signal.metrics(device, zb_rx)

    local src_endpoint = zb_rx.address_header.src_endpoint.value
    local attr_value = value.value
    if device.preferences.logDebugPrint == true then
      print ("src_endpoint =", zb_rx.address_header.src_endpoint.value , "value =", value.value)
    end

    --- Emit event from zigbee message recived
    if attr_value == false or attr_value == 0 then
      device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.off())
    elseif attr_value == true or attr_value == 1 then
      device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.on())
    end

    -- emit event for child devices
    local component = device:get_component_id_for_endpoint(src_endpoint)
    local child_device = device:get_child_by_parent_assigned_key(component)
    if child_device ~= nil and component ~= "main" then
      if attr_value == false or attr_value == 0 then
        child_device:emit_event(capabilities.switch.switch.off())
      elseif attr_value == true or attr_value == 1 then
        child_device:emit_event(capabilities.switch.switch.on())
      end
    end

    --- Set all_switches_status capability status
    device.thread:call_with_delay(2, function(d)
      all_switches_status(driver, device)
    end)
  else

  end
end

--- default_response_handler
local function default_response_handler(driver, device, zb_rx)
  if device.preferences.logDebugPrint == true then
    print("<<<<<< default_response_handler >>>>>>")
  end 

  -- emit signal metrics
  signal.metrics(device, zb_rx)

  local status = zb_rx.body.zcl_body.status.value

  local attr_value = false
  if status == Status.SUCCESS then
    local cmd = zb_rx.body.zcl_body.cmd.value
    local event = nil

    if cmd == zcl_clusters.OnOff.server.commands.On.ID then
      event = capabilities.switch.switch.on()
      attr_value = true
    elseif cmd == zcl_clusters.OnOff.server.commands.Off.ID then
      event = capabilities.switch.switch.off()
    end

    if event ~= nil then
      device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, event)
    end
  end

  -- emit event for child devices
  local component = device:get_component_id_for_endpoint(zb_rx.address_header.src_endpoint.value)
  local child_device = device:get_child_by_parent_assigned_key(component)
  if child_device ~= nil and component ~= "main" then
    if attr_value == false then
      child_device:emit_event(capabilities.switch.switch.off())
    else
      child_device:emit_event(capabilities.switch.switch.on())
    end
  end

  --- Set all_switches_status capability status
  device.thread:call_with_delay(2, function(d)
    all_switches_status(driver, device)
  end)
end

---binary_Input_Handler
local function basic_Input_Handler(self, device, value, zb_rx)

  --print("zb_rx >>>>>>",utils.stringify_table(zb_rx))
  --print("<<<<<<<< ZCL Command Id:", zb_rx.body.zcl_header.cmd.value)
  -- ZCL Command Id: 0x01 == read attribute response
  -- ZCL Command Id: 0x0A == report attribute response
  -- ZCL Command Id: 0x07 == attribute config_rep_response
  -- this device only report the 4 inputs with correct scr_endpoints 0x70,0x71, 0x72, 0x73
  -- with command 0x01, read atribute. Then when a report attribute response command 0x0A received 
  -- a read attribute for endpoints 0x70,0x71, 0x72, 0x73 are made to emit correct status for 4 inputs
  -- A report attribute response does not emit events

    print(" Present Value >>>>>>>>>>>", value.value)

    local src_endpoint = zb_rx.address_header.src_endpoint.value
    local event
    if value.value == true or value.value == 1 then
      if src_endpoint == 112 and device.preferences.invertIN1 == true then
        event = capabilities.contactSensor.contact.open()
      elseif src_endpoint == 113 and device.preferences.invertIN2 == true then
        event = capabilities.contactSensor.contact.open()
      elseif src_endpoint == 114 and device.preferences.invertIN3 == true then
        event = capabilities.contactSensor.contact.open()
      elseif src_endpoint == 115 and device.preferences.invertIN4 == true then
        event = capabilities.contactSensor.contact.open()
      else
        event = capabilities.contactSensor.contact.closed()
      end
    elseif value.value == false or value.value == 0 then
      if src_endpoint == 112 and device.preferences.invertIN1 == true then
        event = capabilities.contactSensor.contact.closed()
      elseif src_endpoint == 113 and device.preferences.invertIN2 == true then
        event = capabilities.contactSensor.contact.closed()
      elseif src_endpoint == 114 and device.preferences.invertIN3 == true then
        event = capabilities.contactSensor.contact.closed()
      elseif src_endpoint == 115 and device.preferences.invertIN4 == true then
        event = capabilities.contactSensor.contact.closed()
      else
        event = capabilities.contactSensor.contact.open()
      end
    end
    if event ~= nil then
      device:emit_event_for_endpoint(src_endpoint, event)
    end

    -- emit event child device
    local component= endpoint_to_component(device, src_endpoint)
    local child_device = device:get_child_by_parent_assigned_key(component)
    if child_device ~= nil and child_device.preferences.profileType == "contact" then
      child_device:emit_event(event)
    end
end

-- refresh_handler
local function refresh_handler(driver, device)
  print("<<< Refresh Handler >>>")
  device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (116))
  device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (117))
  device:send(BasicInput.attributes.PresentValue:read(device):to_endpoint (112))
  device:send(BasicInput.attributes.PresentValue:read(device):to_endpoint (113))
  device:send(BasicInput.attributes.PresentValue:read(device):to_endpoint (114))
  device:send(BasicInput.attributes.PresentValue:read(device):to_endpoint (115))
end

--- do_added
local function do_added(driver, device)

  if device.network_type == "DEVICE_EDGE_CHILD" then  ---- device (is Child device)
    print("Adding EDGE:CHILD device...")

    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()

    if component ~= "main" then
      if parent_device:get_latest_state(component, capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
        device:emit_event(capabilities.switch.switch.on())
      else
        device:emit_event(capabilities.switch.switch.off())
      end
    end
  else
    refresh_handler(driver, device)
  end
end

local zigbee_frient_template = {
  supported_capabilities = {
    --capabilities.switch,
    --capabilities.contactSensor,
    capabilities.refresh
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = on_handler,
      [capabilities.switch.commands.off.NAME] = off_handler
    },
    [switch_All_On_Off.ID] = {
      [switch_All_On_Off.commands.setSwitchAllOnOff.NAME] = switch_All_On_Off_handler,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler,
    }
  },
  zigbee_handlers = {
    global = {
      [zcl_clusters.OnOff.ID] = {
         [zcl_global_commands.DEFAULT_RESPONSE_ID] = default_response_handler
       }
     },
    attr = {
      [zcl_clusters.OnOff.ID] = {
         [zcl_clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
      },
      [BasicInput.ID] = {
        [BasicInput.attributes.PresentValue.ID] = basic_Input_Handler
      },
   }
  },
  lifecycle_handlers = {
    init = do_init,
    doConfigure = do_configure,
    infoChanged = do_Preferences,
    added = do_added
  },
  sub_drivers = {

  },
  health_check = false,
  shared_device_thread_enabled = true,
}

defaults.register_for_default_handlers(zigbee_frient_template, zigbee_frient_template.supported_capabilities)
local zigbee_frient_io = ZigbeeDriver("zigbee-frient-io", zigbee_frient_template)
zigbee_frient_io:run()
