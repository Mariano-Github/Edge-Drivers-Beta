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

local function component_to_endpoint(device, component_id)
  if component_id == "main" then
    return device.fingerprinted_endpoint_id
  else
    local ep_num = component_id:match("switch(%d)")
    return ep_num and tonumber(ep_num) or device.fingerprinted_endpoint_id
  end
end

local function endpoint_to_component(device, ep)
  if ep == device.fingerprinted_endpoint_id then
    return "main"
  else
    return string.format("switch%d", ep)
  end
end

---device init ----
local function device_init (self, device)
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)
  -- Refresh schedule
  device.thread:call_on_schedule(
    180,
    function ()
      local refresh = device:refresh ()
      --return refresh
    end,
    'Refresh schedule') 
end

--- Command on handler ----
local function on_handler(_, device, command)
  -- capability reference
  local attr = capabilities.switch.switch
  -- parse component to endpoint
  local endpoint = device:get_endpoint_for_component_id(command.component)
  -- send zigbee event
  device:send(OnOff.server.commands.On(device):to_endpoint(endpoint))
  -- send platform event
  device:emit_event_for_endpoint(endpoint, attr.on())
end

--- Command off handler ----
local function off_handler(_, device, command)
  -- capability reference
  local attr = capabilities.switch.switch
  -- parse component to endpoint
  local endpoint = device:get_endpoint_for_component_id(command.component)    
  -- send zigbee event
  device:send(OnOff.server.commands.Off(device):to_endpoint(endpoint))
  -- send platform event
  device:emit_event_for_endpoint(endpoint, attr.off())
end

--- read zigbee attribute OnOff messages and detect ON pushbutton pressed in device ----
local function on_off_attr_handler(self, device, value, zb_rx)
  print ("function: on_off_attr_handler")
  local src_endpoint = zb_rx.address_header.src_endpoint.value
  local attr_value = value.value
  if src_endpoint == 1 then
    device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (2))
    device:send(zcl_clusters.OnOff.attributes.OnOff:read(device):to_endpoint (3))
    if attr_value == false then
      device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.off())
    else
      device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.on())
    end
  end
  if src_endpoint == 2 then
    if attr_value == false then
      device:send(OnOff.server.commands.Off(device):to_endpoint(src_endpoint))
      device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.off())
    else
      device:send(OnOff.server.commands.On(device):to_endpoint(src_endpoint))
      device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.on())
    end
  end
  if src_endpoint == 3 then
    if attr_value == false then
      device:send(OnOff.server.commands.Off(device):to_endpoint(src_endpoint))
      device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.off())
    else
      device:send(OnOff.server.commands.On(device):to_endpoint(src_endpoint))
      device:emit_event_for_endpoint(src_endpoint, capabilities.switch.switch.on())
    end
  end
  print ("src_endpoint , value:", zb_rx.address_header.src_endpoint.value, value.value)
end

----- Configur device -------
--local function do_Configure (self, device)
  --device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, self.environment_info.hub_zigbee_eui):to_endpoint (1))
  --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 300):to_endpoint (1))
  --device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, self.environment_info.hub_zigbee_eui):to_endpoint (2))
  --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 300):to_endpoint (2))
  --device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, self.environment_info.hub_zigbee_eui):to_endpoint (3))
  --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 300):to_endpoint (3))
  --device:configure()
  --device:emit_event_for_endpoint(1, capabilities.switch.switch.off())
  --device:emit_event_for_endpoint(2, capabilities.switch.switch.off())
  --device:emit_event_for_endpoint(3, capabilities.switch.switch.off())
--end

---- Driver configure ---------
local zigbee_outlet_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.refresh
  },
  lifecycle_handlers = {
    init = device_init,
    --doConfigure = do_Configure,
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
  },
  sub_drivers = { require("lidl") }
}

defaults.register_for_default_handlers(zigbee_outlet_driver_template, zigbee_outlet_driver_template.supported_capabilities)
local zigbee_outlet = ZigbeeDriver("Zigbee_Multi_Switch", zigbee_outlet_driver_template)
zigbee_outlet:run()