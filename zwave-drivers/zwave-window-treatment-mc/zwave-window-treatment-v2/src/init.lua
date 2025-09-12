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
--- @type st.zwave.CommandClass
local cc = (require "st.zwave.CommandClass")
--- @type st.zwave.constants
local constants = require "st.zwave.constants"
--- @type st.zwave.CommandClass.SwitchBinary
--local SwitchBinary = (require "st.zwave.CommandClass.SwitchBinary")({version=1})
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({ version = 1 })
local SwitchMultilevel = (require "st.zwave.CommandClass.SwitchMultilevel")({version=4})
--- @type st.zwave.CommandClass.Protection
local Protection = (require "st.zwave.CommandClass.Protection")({ version=2 })
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })
local preferencesMap = require "preferences"

local window_Shade_Preset_Value = capabilities ["legendabsolute60149.windowShadePresetValue"]
local PRESET_LEVEL = 50

local function added_handler(self, device)
  device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({"open", "close", "pause"}))
  
  if device.zwave_manufacturer_id ~= 0x026E and --Springs
    device.zwave_manufacturer_id ~= 0x0287 and -- iBlinds
    device.zwave_manufacturer_id ~= 0x0159 and -- Quibino
    device.zwave_manufacturer_id ~= 0x0086 and -- Aeotec
    device.zwave_manufacturer_id ~= 0x0371 then -- Aeotec
      if device:get_field("windowShadePreset_Value") == nil then 
        device:set_field("windowShadePreset_Value", "50%", {persist = true})
      end
      device:emit_event(window_Shade_Preset_Value.windowShadePresetValue(device:get_field("windowShadePreset_Value")))
  end
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

  -- update preferences without parameters
  for id, value in pairs(device.preferences) do
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]

    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      if id == "localProtection" or id == "rfProtection" then
        local lp = tonumber(device.preferences.localProtection)
        local rfp = tonumber(device.preferences.rfProtection)
        print("<<<< lp =", lp,"rfp =", rfp)
        device:send_to_component(Protection:Set({local_protection_state = lp, rf_protection_state = rfp}), "main")
        local query = function()
          device:send_to_component(Protection:Get({}), "main")
         end
         device.thread:call_with_delay(2, query)
      end
    elseif id == "batteryType" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.type(newParameterValue))
      elseif id == "batteryQuantity" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.quantity(newParameterValue))
    end
  end
   -- This will print in the log the total memory in use by Lua in Kbytes
   print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

local function preset_position_handler(driver, device, command)

  if device:get_field("windowShadePreset_Value") == "Random" then
    PRESET_LEVEL = math.random(device.preferences.randomPresetMin, device.preferences.randomPresetMax)
  end
  --print("<<<< device.preferences.randomPresetMin",device.preferences.randomPresetMin)
  --print("<<<< device.preferences.randomPresetMax",device.preferences.randomPresetMax)
  --print("<<<< device:get_field(windowShadePreset_Value)",device:get_field("windowShadePreset_Value"))
  --print("<<<< PRESET_LEVEL >>>>", PRESET_LEVEL)

  local set
  local get
  --local preset_level = PRESET_LEVEL
  local preset_level = device.preferences.reverse and 100 - PRESET_LEVEL or PRESET_LEVEL
  if device:is_cc_supported(cc.SWITCH_MULTILEVEL) then
    set = SwitchMultilevel:Set({
      value = preset_level,
      duration = constants.DEFAULT_DIMMING_DURATION
    })
    get = SwitchMultilevel:Get({})
  else
    set = Basic:Set({
      value = preset_level
    })
    get = Basic:Get({})
  end
  device:send_to_component(set, command.component)
  local query_device = function()
    device:send_to_component(get, command.component)
  end
  device.thread:call_with_delay(constants.MIN_DIMMING_GET_STATUS_DELAY, query_device)
end

----set_WindowShadePresetValue_handler
local function set_WindowShadePresetValue_handler(driver, device, command)
  print("windowShadePreset_Value=", command.args.value)
  local windowShadePreset_Value = command.args.value
  if windowShadePreset_Value == "0%" then
    PRESET_LEVEL = 0
  elseif windowShadePreset_Value == "25%" then
    PRESET_LEVEL = 25
  elseif windowShadePreset_Value == "50%" then
    PRESET_LEVEL = 50
  elseif windowShadePreset_Value == "75%" then
    PRESET_LEVEL = 75
  elseif windowShadePreset_Value == "100%" then
    PRESET_LEVEL = 100
  elseif windowShadePreset_Value == "Random" then
    PRESET_LEVEL = math.random(device.preferences.randomPresetMin, device.preferences.randomPresetMax)
  end
  device:set_field("windowShadePreset_Value", windowShadePreset_Value, {persist = true})
  device:emit_event(window_Shade_Preset_Value.windowShadePresetValue(windowShadePreset_Value))

end

local do_configure = function(self, device)
  if device.zwave_manufacturer_id == 0x0455 and device.zwave_product_type == 0x0004 and device.zwave_product_id == 0x0002 then
    --Parameter No. 38: SEND_MULTILEVEL_REPORT (1 byte), advanced. 
    --For backward compatibility the device can send the multilevel report together with the Switch Multilevel report in addition to the update with Windows Covering report.
    device:send(Configuration:Set({ configuration_value = 1, parameter_number = 38, size = 1 }))
    --Used to define the level report frequency when the motor is moving. Valid values are from 2 (report updated every 2 seconds) to 60 (report updated every 60 seconds).
    device:send(Configuration:Set({ configuration_value = 2, parameter_number = 37, size = 2 }))
    device:send(Association:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}}))
    device:refresh()
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
    capabilities.windowShade,
    capabilities.windowShadeLevel,
    capabilities.windowShadePreset,
    capabilities.statelessCurtainPowerButton,
    capabilities.powerMeter,
    capabilities.energyMeter,
    capabilities.battery,
    capabilities.refresh

  },
  capability_handlers = {
    [window_Shade_Preset_Value.ID] = {
      [window_Shade_Preset_Value.commands.setWindowShadePresetValue.NAME] = set_WindowShadePresetValue_handler,
    },
    [capabilities.windowShadePreset.ID] = {
      [capabilities.windowShadePreset.commands.presetPosition.NAME] = preset_position_handler
    }
  },
  lifecycle_handlers = {
    added = added_handler,
    infoChanged = info_changed,
    doConfigure = do_configure
  },
  sub_drivers = {
    lazy_load_if_possible("springs-window-fashion-shade"),
    lazy_load_if_possible("iblinds-window-treatment"),
    lazy_load_if_possible("window-treatment-venetian"),
    lazy_load_if_possible("aeotec-nano-shutter")
  }
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local window_treatment = ZwaveDriver("zwave_window_treatment", driver_template)
window_treatment:run()
