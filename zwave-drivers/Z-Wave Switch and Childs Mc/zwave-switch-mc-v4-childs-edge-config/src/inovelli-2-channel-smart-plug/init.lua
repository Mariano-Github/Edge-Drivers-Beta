-- Copyright 2022 SmartThings
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
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({ version = 1 })
--- @type st.zwave.CommandClass.SwitchAll
local SwitchAll = (require "st.zwave.CommandClass.SwitchAll")({ version = 1 })
--- @type st.zwave.CommandClass.SwitchBinary
local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({ version = 2 })
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version = 1 })

--local log = require "log"

local INOVELLI_2_CHANNEL_SMART_PLUG_FINGERPRINTS = {
  {mfr = 0x015D, prod = 0x0221, model = 0x251C}, -- Show Home Outlet
  {mfr = 0x0312, prod = 0x0221, model = 0x251C}, -- Inovelli Outlet
  {mfr = 0x0312, prod = 0xB221, model = 0x251C}, -- Inovelli Outlet
  {mfr = 0x0312, prod = 0x0221, model = 0x611C}, -- Inovelli Outlet
  {mfr = 0x015D, prod = 0x0221, model = 0x611C}, -- Inovelli Outlet
  {mfr = 0x015D, prod = 0x6100, model = 0x6100}, -- Inovelli Outlet
  {mfr = 0x0312, prod = 0x6100, model = 0x6100}, -- Inovelli Outlet
  {mfr = 0x015D, prod = 0x2500, model = 0x2500}, -- Inovelli Outlet
}

local function can_handle_inovelli_2_channel_smart_plug(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
    for _, fingerprint in ipairs(INOVELLI_2_CHANNEL_SMART_PLUG_FINGERPRINTS) do
      if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
        local subdriver = require("inovelli-2-channel-smart-plug")
        return true, subdriver
      end
    end
  return false
end

--- Map component to end_points(channels)
---
--- @param device st.zwave.Device
--- @param component_id string ID
--- @return table dst_channels destination channels e.g. {2} for Z-Wave channel 2 or {} for unencapsulated
local function component_to_endpoint(device, component_id)
  local ep_num = component_id:match("switch(%d)")
  return { ep_num and tonumber(ep_num) }
end

--- Map end_point(channel) to Z-Wave endpoint 9 channel)
---
--- @param device st.zwave.Device
--- @param ep number the endpoint(Z-Wave channel) ID to find the component for
--- @return string the component ID the endpoint matches to
local function endpoint_to_component(device, ep)
  local switch_comp = string.format("switch%d", ep)
  if device.profile.components[switch_comp] ~= nil then
    return switch_comp
  else
    return "main"
  end
end

--- Initialize device
---
--- @param self st.zwave.Driver
--- @param device st.zwave.Device
local device_init = function(self, device)
  --if device.manufacturer == nil then    ---- device.manufacturer == nil is NO Child device
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:set_component_to_endpoint_fn(component_to_endpoint)
    device:set_endpoint_to_component_fn(endpoint_to_component)
  end
end


local function handle_main_switch_event(device, value)
  if value == SwitchBinary.value.ON_ENABLE then
    device:emit_event(capabilities.switch.switch.on())
  else
    if device:get_latest_state("switch1", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" or
        device:get_latest_state("switch2", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
      device:emit_event(capabilities.switch.switch.on())
    else
      device:emit_event(capabilities.switch.switch.off())
    end
  end
end

local function query_switch_status(device)
  device:send_to_component(SwitchBinary:Get({}), "switch1")
  device:send_to_component(SwitchBinary:Get({}), "switch2")
end

local function basic_set_handler(driver, device, cmd)
  local value = cmd.args.target_value and cmd.args.target_value or cmd.args.value
  local event = value == SwitchBinary.value.OFF_DISABLE and capabilities.switch.switch.off() or capabilities.switch.switch.on()

  device:emit_event_for_endpoint(cmd.src_channel, event)

  query_switch_status(device)

  -- emit event for childs devices
  print("cmd.src_channel >>>>>>",cmd.src_channel)
  local component= endpoint_to_component(device, cmd.src_channel)
  local child_device = device:get_child_by_parent_assigned_key(component)
  if child_device ~= nil and component ~= "main" then
    child_device:emit_event(event)
  end
end

local function basic_and_switch_binary_report_handler(driver, device, cmd)
  local value = cmd.args.target_value and cmd.args.target_value or cmd.args.value
  local event = value == SwitchBinary.value.OFF_DISABLE and capabilities.switch.switch.off() or capabilities.switch.switch.on()


  device:emit_event_for_endpoint(cmd.src_channel, event)

  if cmd.src_channel == 0 then
    query_switch_status(device)
  else
    handle_main_switch_event(device, value)
  end

  -- emit event for childs devices
  print("cmd.src_channel >>>>>>",cmd.src_channel)
  local component= endpoint_to_component(device, cmd.src_channel)
  local child_device = device:get_child_by_parent_assigned_key(component)
  if child_device ~= nil and component ~= "main" then
    --  emit_event(capabilities.switch.switch.off() or on())
    child_device:emit_event(event)
  end
end

local function set_switch_value(driver, device, value, command)
  print("<<<< command.component >>>>>",command.component)
  if command.component == "main" then
    local event = value == SwitchBinary.value.ON_ENABLE and SwitchAll:On({}) or SwitchAll:Off({})
    device:send(event)
    query_switch_status(device)
  else
    device:send_to_component(Basic:Set({value = value}), command.component)
    device:send_to_component(SwitchBinary:Get({}), command.component)
  end
end

local function switch_set_helper_on(driver, device, command)
  print("<<<<< switch_set_helper_on in subdriver >>>>>>>")
  print("<<<< command.component >>>>>",command.component)
  --if device.manufacturer == nil then   -- is one parent device
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    if command.component ~= "main" then
      local child_device = device:get_child_by_parent_assigned_key(command.component)
      if child_device ~= nil then
        child_device:emit_event(capabilities.switch.switch.on())
      end
    end
    set_switch_value(driver, device, SwitchBinary.value.ON_ENABLE, command)

  else
    device:emit_event(capabilities.switch.switch.on())
    command.component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    set_switch_value(driver, parent_device, 255, command)
  end 
end

local function switch_set_helper_off(driver, device, command)
  print("<<<<< switch_set_helper_off in subdriver >>>>>>>")
  --print("<<<< command.component >>>>>",command.component)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    if command.component ~= "main" then
      local child_device = device:get_child_by_parent_assigned_key(command.component)
      if child_device ~= nil then
        child_device:emit_event(capabilities.switch.switch.off())
      end
    end 
    set_switch_value(driver, device, SwitchBinary.value.OFF_DISABLE, command)
  else
    device:emit_event(capabilities.switch.switch.on())
    command.component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()
    set_switch_value(driver, parent_device, 0, command)
  end 
end

local function do_configure(driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:send(Association:Set({grouping_identifier = 1, node_ids = {driver.environment_info.hub_zwave_id}}))
  end
end


local inovelli_2_channel_smart_plug = {
  NAME = "Inovelli 2 channel smart plug",
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.REPORT] = basic_and_switch_binary_report_handler,
      [Basic.SET] = basic_set_handler
    },
    [cc.SWITCH_BINARY] = {
      [SwitchBinary.REPORT] = basic_and_switch_binary_report_handler
    }
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = switch_set_helper_on,
      [capabilities.switch.commands.off.NAME] = switch_set_helper_off
    },
  },
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure
  },
  can_handle = can_handle_inovelli_2_channel_smart_plug,
}

return inovelli_2_channel_smart_plug