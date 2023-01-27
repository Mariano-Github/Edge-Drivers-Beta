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
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })
local preferencesMap = require "preferences"

local function added_handler(self, device)
  device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({"open", "close", "pause"}))
end

--- Handle preference changes
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param event table
--- @param args
local function info_changed(driver, device, event, args)
  local preferences = preferencesMap.get_device_parameters(device)
  if preferences then
    for id, value in pairs(device.preferences) do
      if preferences[id] and args.old_st_store.preferences[id] ~= value then
        print("Preference Changed >>>", id,"Old Value >>>>>>>>>",args.old_st_store.preferences[id], "New Value >>", value)
        local new_parameter_value = preferencesMap.to_numeric_value(device.preferences[id])
        print(">>>>> parameter_number:",preferences[id].parameter_number,"size:",preferences[id].size,"configuration_value:",new_parameter_value)
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
      end
    end
  end
   -- This will print in the log the total memory in use by Lua in Kbytes
   print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

--------------------------------------------------------------------------------------------
-- Register message handlers and run driver
--------------------------------------------------------------------------------------------

local driver_template = {
  supported_capabilities = {
    capabilities.windowShade,
    capabilities.windowShadeLevel,
    capabilities.windowShadePreset,
    capabilities.statelessCurtainPowerButton,
    capabilities.powerMeter,
    capabilities.energyMeter,
    capabilities.battery
  },
  lifecycle_handlers = {
    added = added_handler,
    infoChanged = info_changed
  },
  sub_drivers = {
    require("springs-window-fashion-shade"),
    require("iblinds-window-treatment"),
    require("window-treatment-venetian"),
    require("aeotec-nano-shutter")
  }
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local window_treatment = ZwaveDriver("zwave_window_treatment", driver_template)
window_treatment:run()
