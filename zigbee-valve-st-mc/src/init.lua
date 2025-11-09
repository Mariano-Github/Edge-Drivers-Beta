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

local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"

--ZCL
local zcl_clusters = require "st.zigbee.zcl.clusters"
local Basic = zcl_clusters.Basic

--Capability
local capabilities = require "st.capabilities"
local battery = capabilities.battery
local valve = capabilities.valve
local powerSource = capabilities.powerSource
local refresh = capabilities.refresh

local write = require "writeAttribute"

local function device_added(self, device)
  device:refresh()
end

--- Update preferences after infoChanged recived---
local function do_Preferences(self, device, event, args)
  print("<< do_Prefrences >>")
  for id, value in pairs(device.preferences) do
    --if device.preferences.logDebugPrint == true then
      --print("device.preferences[infoChanged]=", device.preferences[id])
    --end
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if device:get_field(id) ~= nil then
      device:set_field(id, nil, {persist = false})
    end
    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:",id, "old value:",oldPreferenceValue, "new value:", newParameterValue)
 
        --- Configure on-off cluster, attributte 0x8002 and 4003 to value restore state in preferences
        if id == "restoreState" then
          print("<<< Write restore state >>>")
          local value_send = tonumber(newParameterValue)
          local data_value = {value = value_send, ID = 0x30}
          local cluster_id = {value = 0x0006}
          --write atribute for zigbee standard devices
          local attr_id = 0x4003
          write.write_attribute_function(device, cluster_id, attr_id, data_value)

          --write atribute for Tuya devices (Restore previous state = 0x02)
          if newParameterValue == "255" then data_value = {value = 0x02, ID = 0x30} end
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
  local firmware_full_version = device.data.firmwareFullVersion
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- do_init
--local function do_init(self, device)
  --device.thread:call_with_delay(4, function() do_Preferences(self,device) end)
--end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
  local version = require "version"

local lazy_handler
if version.api >= 15 then
  lazy_handler = require "st.utils.lazy_handler"
else
  lazy_handler = require
end
  local function lazy_load_if_possible(sub_driver_name)
    -- gets the current lua libs api version
    local version = require "version"
  
    --print("<<<<< Library Version:", version.api)
    -- version 9 will include the lazy loading functions
    if version.api >= 9 then
      return ZigbeeDriver.lazy_load_sub_driver(require(sub_driver_name))
    else
      return require(sub_driver_name)
    end
  end

local zigbee_valve_driver_template = {
  supported_capabilities = {
    valve,
    battery,
    powerSource,
    refresh
  },
  cluster_configurations = {
    [powerSource.ID] = {
      {
        cluster = Basic.ID,
        attribute = Basic.attributes.PowerSource.ID,
        minimum_interval = 5,
        maximum_interval = 600,
        data_type = Basic.attributes.PowerSource.base_type,
        configurable = true
      }
    }
  },
  lifecycle_handlers = {
    --init = do_init,
    added = device_added,
    infoChanged = do_Preferences
  },
  sub_drivers = {
     lazy_load_if_possible("sinope"),
     lazy_load_if_possible("ezex"),
     lazy_load_if_possible("default_response")
  },
   health_check = false,
}

defaults.register_for_default_handlers(zigbee_valve_driver_template, zigbee_valve_driver_template.supported_capabilities)
local zigbee_valve = ZigbeeDriver("zigbee-valve", zigbee_valve_driver_template)
zigbee_valve:run()
