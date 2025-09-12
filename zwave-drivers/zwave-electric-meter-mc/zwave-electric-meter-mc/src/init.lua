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
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=1 })
local preferencesMap = require "preferences"

local device_added = function (self, device)
  device:refresh()
end

local function info_changed(driver, device, event, args)
  local preferences = preferencesMap.get_device_parameters(device)

  if preferences then
    for id, value in pairs(device.preferences) do
      if args.old_st_store.preferences[id] ~= value and preferences[id] then
        print("Preference Changed >>>", id,"Old Value >>>>>>>>>",args.old_st_store.preferences[id], "New Value >>", value)
        local new_parameter_value = preferencesMap.to_numeric_value(device.preferences[id])
        --2's complement value if needed
        if preferences[id].size == 4 and new_parameter_value > 2147483647 then
          new_parameter_value = new_parameter_value - 4294967296
        elseif preferences[id].size == 2 and new_parameter_value > 32767 then
          new_parameter_value = new_parameter_value - 65536
        elseif preferences[id].size == 1 and new_parameter_value > 127 then
          new_parameter_value = new_parameter_value - 256
        end
        print("new_parameter_value Sent >>>>",new_parameter_value)
          device:send(Configuration:Set({parameter_number = preferences[id].parameter_number, size = preferences[id].size, configuration_value = new_parameter_value}))

          local delayed_command = function()
            device:send(Configuration:Get({parameter_number = preferences[id].parameter_number}))
          end
          device.thread:call_with_delay(1, delayed_command)
      end
    end
  end
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
local function lazy_load_if_possible(sub_driver_name)
  -- gets the current lua libs api version
  local version = require "version"

  --print("<<<<< Library Version:", version.api)
  -- version 9 will include the lazy loading functions
  if version.api >= 9 then
    return ZwaveDriver.lazy_load_sub_driver(require(sub_driver_name))
  else
    return require(sub_driver_name)
  end
end

local driver_template = {
  supported_capabilities = {
    capabilities.powerMeter,
    capabilities.energyMeter,
    capabilities.voltageMeasurement,
    capabilities.currentMeasurement,
    capabilities.refresh,

  },
  lifecycle_handlers = {
    added = device_added,
    infoChanged = info_changed
  },
  sub_drivers = {
    lazy_load_if_possible("qubino-meter"),
    lazy_load_if_possible("aeotec-gen5-meter"),
    lazy_load_if_possible("aeon-meter")
  }
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local electricMeter = ZwaveDriver("zwave_electric_meter", driver_template)
electricMeter:run()
