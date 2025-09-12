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
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })
--- @type st.zwave.CommandClass.Protection
--local Protection = (require "st.zwave.CommandClass.Protection")({ version=2 })
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })
local preferencesMap = require "preferences"
local child_devices = require "child-devices"

--- set DELAY dimmin fibaro rgbw
local function set_delay(driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    local delay = constants.DEFAULT_POST_DIMMING_DELAY
    if device.preferences.outputsStateMode == "0" then
      delay = delay + (device.preferences.stepValue * device.preferences.timeBetweenSteps / 1000)
    else
      if device.preferences.timeChangingStartEnd >= 0 and device.preferences.timeChangingStartEnd <= 63 then
        delay = delay + (device.preferences.timeChangingStartEnd * 20 / 1000)
      elseif device.preferences.timeChangingStartEnd > 63 and device.preferences.timeChangingStartEnd <= 127 then
        delay =delay + (device.preferences.timeChangingStartEnd - 64)
      elseif device.preferences.timeChangingStartEnd > 127 and device.preferences.timeChangingStartEnd <= 191 then
        delay = delay + (device.preferences.timeChangingStartEnd - 128 * 10)
      elseif device.preferences.timeChangingStartEnd > 193 and device.preferences.timeChangingStartEnd <= 255 then
        delay = delay + (device.preferences.timeChangingStartEnd - 192 * 60)
      end
    end
    print("<<<<<< calculated_delay", delay )
    device:set_field("Calculated_Delay", delay)
    if delay > 8 then delay = 8 end
    device:set_field("Minimum_Delay", delay)
  end
end

--- Handle preference changes
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param event table
--- @param args
local function info_changed(driver, device, event, args)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    local preferences = preferencesMap.get_device_parameters(device)
    for id, value in pairs(device.preferences) do
      if args.old_st_store.preferences[id] ~= value and preferences and preferences[id] then
        local new_parameter_value = preferencesMap.to_numeric_value(device.preferences[id])
        if id == "inputsOutputsConfig1" or id == "inputsOutputsConfig2" or id == "inputsOutputsConfig3" or id == "inputsOutputsConfig4" then
          new_parameter_value = (tonumber(device.preferences.inputsOutputsConfig1) * 16 * 16 * 16) + (tonumber(device.preferences.inputsOutputsConfig2) * 16 * 16) + (tonumber(device.preferences.inputsOutputsConfig3) * 16) + tonumber(device.preferences.inputsOutputsConfig4)
          print("Parameter 14 - 4 channel value >>>>>", new_parameter_value)
        elseif id == "outputsStateMode" or id == "stepValue" or  id == "timeBetweenSteps" or id == "timeChangingStartEnd" then
          set_delay(driver, device)
          print("<<<< Minimum_Delay",device:get_field("Minimum_Delay"))
        end
        print("Preference Changed >>>", id,"Old Value >>>>>>>>>",args.old_st_store.preferences[id], "New Value >>", value)
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
        --device:send(Protection:Set({local_protection_state = 0, rf_protection_state = 0}))
        --device:send(Protection:Get({}))
      end
      --change profile tile
      --local oldPreferenceValue = device:get_field(id)
      local oldPreferenceValue = args.old_st_store.preferences[id]
      local newParameterValue = device.preferences[id]
      if oldPreferenceValue ~= newParameterValue then
        --device:set_field(id, newParameterValue, {persist = true})
        if id == "changeProfile1"then
          if device.preferences.changeProfile1 == "Single" then
            device:try_update_metadata({profile = "fibaro-rgbw-controller"})
          else
            device:try_update_metadata({profile = "fibaro-rgbw-controller-multi"})
          end
        elseif id == "changeProfile2"then
            if device.preferences.changeProfile2 == "Single" then
              device:try_update_metadata({profile = "fibaro-rgbw-controller-2"})
            else
              device:try_update_metadata({profile = "fibaro-rgbw-controller-2-multi"})
            end
        elseif id == "changeProfileTKB"then
            if device.preferences.changeProfileTKB == "Single" then
              device:try_update_metadata({profile = "tkb-rgbw-controller"})
            else
              device:try_update_metadata({profile = "tkb-rgbw-controller-multi"})
            end
        elseif id == "readRGBWDelay" then
          local delay = device.preferences.readRGBWDelay
          if delay == nil then delay = 4 end
          device:set_field("Calculated_Delay", delay)
          device:set_field("Minimum_Delay", delay)
        elseif id == "whiteChild" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
            child_devices.create_new(driver, device, "white", "child-switch-level")
          end
        elseif id == "rgbChild" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
            child_devices.create_new(driver, device, "red", "child-switch-level")
            child_devices.create_new(driver, device, "green", "child-switch-level")
            child_devices.create_new(driver, device, "blue", "child-switch-level")
          end
        end
      end
    end
    -- This will print in the log the total memory in use by Lua in Kbytes
    print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
  end
end

local function device_added(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    if (device.zwave_manufacturer_id == 0x014F and device.zwave_product_type == 0x4754 and device.zwave_product_id == 0x3038) then 
      device:send(Association:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}}))
    end
      device:refresh()
  --else
    --child_devices.device_added(self, device)
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

--------------------------------------------------------------------------------------------
-- Register message handlers and run driver
--------------------------------------------------------------------------------------------

local driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.switchLevel,
    capabilities.colorControl,
    capabilities.colorTemperature,
    capabilities.powerMeter,
    capabilities.energyMeter,
    --capabilities.button
  },
  lifecycle_handlers = {
    infoChanged = info_changed,
    added = device_added
  },
  sub_drivers = { 
    lazy_load_if_possible("aeotec-led-bulb-6"),
    lazy_load_if_possible("aeon-multiwhite-bulb"),
    lazy_load_if_possible("fibaro-rgbw-controller"),
    --require("fibaro-rgbw-controller"),
    lazy_load_if_possible("fibaro-rgbw-controller-2"),
    --lazy_load_if_possible("tkb-rgbw-controller"),
   require("tkb-rgbw-controller") -- need changes same "fibaro-rgbw-controller"
  },
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities, {native_capability_cmds_enabled = true})
--- @type st.zwave.Driver
local bulb = ZwaveDriver("zwave_bulb", driver_template)
bulb:run()
