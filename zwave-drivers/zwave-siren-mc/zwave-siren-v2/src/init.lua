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
local cap_defaults = require "st.capabilities.defaults"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
local configurationsMap = require "configurations"
local preferencesMap = require "preferences"
local Configuration = (require "st.zwave.CommandClass.Configuration")({version=1})
local Basic = (require "st.zwave.CommandClass.Basic")({version=1})
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 2 })

--- Handle preference changes
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param event table
--- @param args
local function info_changed(driver, device, event, args)
  local preferences = preferencesMap.get_device_parameters(device)

  if preferences then
    local did_configuration_change = false
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
      end
    end

    if did_configuration_change then
      local delayed_command = function()
        device:send(Basic:Set({value=0x00}))
      end
      device.thread:call_with_delay(1, delayed_command)
    end
  end
  
  --change wakeUp interval for Ecolink Firefighter
    for id, value in pairs(device.preferences) do
      local oldPreferenceValue = args.old_st_store.preferences[id]
      local newParameterValue = device.preferences[id]
      if oldPreferenceValue ~= newParameterValue then       
        print("Preference Changed >>>", id,"Old Value >>>>>>>>>",oldPreferenceValue, "New Value >>", newParameterValue)
        if id == "wakeUpInterval" and device.preferences.wakeUpInterval ~= nil then
          local _node_id = driver.environment_info.hub_zwave_id
          device:send(WakeUp:IntervalSet({seconds = newParameterValue * 3600, node_id = _node_id}))
        -- change battery profile Neo coolcam
        elseif id == "changeProfileBatt" then
          if device.preferences.changeProfileBatt == "NoBatt" then
            device:try_update_metadata({profile = "coolcam-alarm"})
          else
            device:try_update_metadata({profile = "coolcam-alarm-battery"})
          end
        elseif id == "batteryType" and newParameterValue ~= nil then
          device:emit_event(capabilities.battery.type(newParameterValue))
        elseif id == "batteryQuantity" and newParameterValue ~= nil then
          device:emit_event(capabilities.battery.quantity(newParameterValue))
        end
      end 
    end

  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

--- Configure device
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
local function do_configure(driver, device)
  local configuration = configurationsMap.get_device_configuration(device)
  if configuration ~= nil then
    for _, value in ipairs(configuration) do
      device:send(Configuration:Set({parameter_number = value.parameter_number, size = value.size, configuration_value = value.configuration_value}))
    end

    local delayed_command = function()
      device:send(Basic:Set({value=0x00}))
    end
    device.thread:call_with_delay(1, delayed_command)
  end
end

--- Handle device added
---
--- @param self st.zwave.Driver
--- @param device st.zwave.Device
local function added_handler(self, device)
  cap_defaults.emit_default_events(device, self.supported_capabilities)
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
    capabilities.alarm,
    capabilities.battery,
    capabilities.soundSensor,
    capabilities.switch,
    capabilities.tamperAlert,
    capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.chime
  },
  sub_drivers = {
    lazy_load_if_possible("multifunctional-siren"),
    lazy_load_if_possible("zwave-sound-sensor"),
    lazy_load_if_possible("ecolink-wireless-siren"),
    lazy_load_if_possible("philio-sound-siren"),
    lazy_load_if_possible("philio-sound-siren-pse04"),
    lazy_load_if_possible("aeotec-doorbell-siren"),
    lazy_load_if_possible("aeon-siren"),
    lazy_load_if_possible("yale-siren"),
    lazy_load_if_possible("zipato-siren"),
    lazy_load_if_possible("utilitech-siren"),
    lazy_load_if_possible("fortrezz"),
    lazy_load_if_possible("coolcam-siren")
  },
  lifecycle_handlers = {
    infoChanged = info_changed,
    doConfigure = do_configure,
    added = added_handler
  }
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local siren = ZwaveDriver("zwave_siren", driver_template)
siren:run()
