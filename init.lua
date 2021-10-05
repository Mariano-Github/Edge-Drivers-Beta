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

local ep_ini = 1

--- return endpoint from component_id
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
    end 
  end
end

---device init ----
local function device_init (self, device)
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)
  -- Refresh schedule
  --device.thread:call_on_schedule(
    --300,
    --function ()
      --local refresh = device:refresh ()
    --end,
    --'Refresh schedule') 
end

---- Driver configure ---------
local zigbee_outlet_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.refresh
  },
  lifecycle_handlers = {
    init = device_init,
  },
}

defaults.register_for_default_handlers(zigbee_outlet_driver_template, zigbee_outlet_driver_template.supported_capabilities)
local zigbee_outlet = ZigbeeDriver("Zigbee_Multi_Switch", zigbee_outlet_driver_template)
zigbee_outlet:run()