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
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version=2 })
local SceneControllerConf = (require "st.zwave.CommandClass.SceneControllerConf")({ version=1 })
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 4 })
local configsMap = require "configurations"

--local child_devices = require "child-devices"

--- Update preferences after infoChanged recived---
local function do_preferences (self, device, event, args)
  for id, value in pairs(device.preferences) do
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
      if id == "batteryType" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.type(newParameterValue))
      elseif id == "batteryQuantity" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.quantity(newParameterValue))
      end
    end
  end

  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

local function added_handler(self, device)
  device:refresh()
  local configs = configsMap.get_device_parameters(device)
  if configs then
    for _, comp in pairs(device.profile.components) do
      if device:supports_capability_by_id(capabilities.button.ID, comp.id) then
        local number_of_buttons = comp.id == "main" and configs.number_of_buttons or 1
        device:emit_component_event(comp, capabilities.button.numberOfButtons({ value=number_of_buttons }, { visibility = { displayed = false }}))
        device:emit_component_event(comp, capabilities.button.supportedButtonValues(configs.supported_button_values, { visibility = { displayed = false }}))
      end
    end
  end

  -- Association with hub node_id
  local _node_ids =  {self.environment_info.hub_zwave_id}
  print("table_node_ids >>>>>> {", _node_ids[1],"}")
  if _node_ids[1] == nil then _node_ids[1] = 1 end
  print("<<<< _node_ids",_node_ids[1])
  if device.zwave_manufacturer_id == 0x0438 then
    device:send(Association:Set({grouping_identifier = 1, node_ids = _node_ids}))
  elseif device.zwave_manufacturer_id == 0x0267 then
    device:send(Association:Set({grouping_identifier = 3, node_ids =_node_ids}))
  elseif device.zwave_manufacturer_id == 0x011A and device.zwave_product_type == 0x0801 and device.zwave_product_id == 0x0B03 then
    for i = 1, 7, 1 do
      device:send(Association:Set({grouping_identifier = i, node_ids = _node_ids}))
      device:send(SceneControllerConf:Set({group_id = i, scene_id = i}))
    end
  elseif device.zwave_manufacturer_id == 0x0178 and device.zwave_product_type == 0x5343 and device.zwave_product_id == 0x4735 then
    device:send(Association:Set({grouping_identifier = 1, node_ids = _node_ids}))
      for i = 1, 15, 1 do
        --device:send(Association:Set({grouping_identifier = i, node_ids = _node_ids}))
        device:send(SceneControllerConf:Set({group_id = i, scene_id = i}))
        device:send(Configuration:Set({ configuration_value = 0, parameter_number = i + 1, size = 1 }))
      end
    --device.thread:call_with_delay(3, function()
      --for i = 1, 7,1 do
        --device:send(Association:Get({grouping_identifier = i}))
        --device:send(SceneControllerConf:Get({group_id = i}))
      --end
    --end)
  elseif device.zwave_manufacturer_id == 0x0109 and device.zwave_product_type == 0x1002 and device.zwave_product_id == 0x0202 then
    for i = 1, 5, 1 do
      device:send(Association:Set({grouping_identifier = i, node_ids = _node_ids}))
    end
  end

  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

local driver_template = {
  supported_capabilities = {
    capabilities.button,
    capabilities.battery,
    --capabilities.refresh
  },
  lifecycle_handlers = {
    added = added_handler,
    infoChanged = do_preferences
    --driverSwitched = added_handler
  },
  sub_drivers = {
    require("zwave-multi-button"),

  }
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local button = ZwaveDriver("zwave_button", driver_template)
button:run()
