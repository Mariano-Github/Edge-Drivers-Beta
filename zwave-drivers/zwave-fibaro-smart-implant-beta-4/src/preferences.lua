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

--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=1 })
--- @type st.zwave.CommandClass.Protection
local Protection = (require "st.zwave.CommandClass.Protection")({ version=2 })
local child_devices = require "child-devices"

local devices = {
  FIBARO_SMART_IMPLANT = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0502,
      product_ids = {0x1000, 0x2000, 0x3000}
    },
    PARAMETERS = {
      operatingIn1 = {parameter_number = 20, size = 1}, 
      operatingIn2 = {parameter_number = 21, size = 1},
      inputOrientation = {parameter_number = 24, size = 1},
      outOrientation = {parameter_number = 25, size = 1},
      input1SentScenes = {parameter_number = 40, size = 1},
      input2SentScenes = {parameter_number = 41, size = 1},
      input1Sensitivity = {parameter_number = 150, size = 1},
      input2Sensitivity = {parameter_number = 151, size = 1},
      input1DelayAlarm = {parameter_number = 152, size = 2},
      input2DelayAlarm = {parameter_number = 153, size = 2},
      out1Logic = {parameter_number = 154, size = 1},
      out2Logic = {parameter_number = 155, size = 1},
      out1AutoOff = {parameter_number = 156, size = 2},
      out2AutoOff = {parameter_number = 157, size = 2},
      analogInputsReport = {parameter_number = 63, size = 2},
      analogInpIntervalReport = {parameter_number = 64, size = 2},
      intTempReportsThreshold = {parameter_number = 65, size = 2},
      intTempInterval = {parameter_number = 66, size = 2},
      extTempReportsThreshold = {parameter_number = 67, size = 2},
      extTempInterval = {parameter_number = 68, size = 2}
    }
  }
}
local preferences = {}

preferences.update_preferences = function(driver, device, args)
  local prefs = preferences.get_device_parameters(device)

    for id, value in pairs(device.preferences) do

      --local oldPreferenceValue = device:get_field(id)
      --local newParameterValue = device.preferences[id]

      if prefs ~= nil then
        if not (args and args.old_st_store) or (args.old_st_store.preferences[id] ~= value and prefs and prefs[id]) then
          local new_parameter_value = preferences.to_numeric_value(device.preferences[id])
          print("<<<< parameter_number =",prefs[id].parameter_number)
          print("<<<< size =",prefs[id].size)
          print("<<<< configuration_value =",new_parameter_value)
          device:send(Configuration:Set({parameter_number = prefs[id].parameter_number, size = prefs[id].size, configuration_value = new_parameter_value}))
        end
      end
    end
    device:refresh()
end

-- do_Preferences
preferences.do_preferences = function(driver, device, args)
  local prefs = preferences.get_device_parameters(device)

    for id, value in pairs(device.preferences) do

      local oldPreferenceValue = device:get_field(id)
      local newParameterValue = device.preferences[id]

      if prefs ~= nil then
        if not (args and args.old_st_store) or (args.old_st_store.preferences[id] ~= value and prefs and prefs[id]) then
          local new_parameter_value = preferences.to_numeric_value(device.preferences[id])
          print("<<<< parameter_number =",prefs[id].parameter_number)
          print("<<<< size =",prefs[id].size)
          print("<<<< configuration_value =",new_parameter_value)
          device:send(Configuration:Set({parameter_number = prefs[id].parameter_number, size = prefs[id].size, configuration_value = new_parameter_value}))
        end
      end

     --Create virtual Child Thermostat and change profile
      if oldPreferenceValue ~= newParameterValue then
        device:set_field(id, newParameterValue, {persist = true})
        if id == "childThermostat" and device.preferences.childThermostat == true then
          child_devices.create_new(driver, device, "externalTemp1", "child-thermostat-05")
        elseif id == "childThermostat2" and device.preferences.childThermostat2 == true then
          child_devices.create_new(driver, device, "externalTemp2", "child-thermostat-05")
        elseif id == "childThermostat3" and device.preferences.childThermostat2 == true then
          child_devices.create_new(driver, device, "externalTemp3", "child-thermostat-05")
        elseif id == "childThermostat4" and device.preferences.childThermostat2 == true then
          child_devices.create_new(driver, device, "externalTemp4", "child-thermostat-05")
        elseif id == "childThermostat5" and device.preferences.childThermostat2 == true then
          child_devices.create_new(driver, device, "externalTemp5", "child-thermostat-05")
        elseif id == "childThermostat6" and device.preferences.childThermostat2 == true then
          child_devices.create_new(driver, device, "externalTemp6", "child-thermostat-05")
        elseif id == "changeProfileExtTemp" then
          if newParameterValue == "1" then
            device:try_update_metadata({profile = "fibaro-smart-implant-temp"})
          elseif newParameterValue == "2" then
              device:try_update_metadata({profile = "fibaro-smart-implant-temp-2"})
          elseif newParameterValue == "3" then
            device:try_update_metadata({profile = "fibaro-smart-implant-temp-3"})
          elseif newParameterValue == "4" then
            device:try_update_metadata({profile = "fibaro-smart-implant-temp-4"})
          elseif newParameterValue == "5" then
              device:try_update_metadata({profile = "fibaro-smart-implant-temp-5"})
          elseif newParameterValue == "6" then
            device:try_update_metadata({profile = "fibaro-smart-implant-temp-6"})
          elseif newParameterValue == "0" then
            if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
              device:try_update_metadata({profile = "smart-implant-two-switch"})
            elseif device.preferences.deviceTile == true then
              device:try_update_metadata({profile = "smart-implant-two-switch-multi"})
            end
          elseif newParameterValue == "7" then
            if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
              device:try_update_metadata({profile = "smart-implant-two-contact-switch"})
            elseif device.preferences.deviceTile == true then
              device:try_update_metadata({profile = "smart-implant-two-contact-switch-multi"})
            end
          elseif newParameterValue == "8" then
            if device.preferences.deviceTile == false or device.preferences.deviceTile == nil then
              device:try_update_metadata({profile = "smart-implant-two-motion-switch"})
            elseif device.preferences.deviceTile == true then
              device:try_update_metadata({profile = "smart-implant-two-motion-switch-multi"})
            end
          end
        elseif id == "deviceTile" then
          if newParameterValue == false then
            if device.preferences.changeProfileExtTemp == "0" then
              device:try_update_metadata({profile = "smart-implant-two-switch"})
            elseif device.preferences.changeProfileExtTemp == "7" then
              device:try_update_metadata({profile = "smart-implant-two-contact-switch"})
            elseif device.preferences.changeProfileExtTemp == "8" then
              device:try_update_metadata({profile = "smart-implant-two-motion-switch"})
            end
          elseif newParameterValue == true then
            if device.preferences.changeProfileExtTemp == "0" then
              device:try_update_metadata({profile = "smart-implant-two-switch-multi"})
            elseif device.preferences.changeProfileExtTemp == "7" then
              device:try_update_metadata({profile = "smart-implant-two-contact-switch-multi"})
            elseif device.preferences.changeProfileExtTemp == "8" then
              device:try_update_metadata({profile = "smart-implant-two-motion-switch-multi"})
            end
          end
        elseif id == "out1LocalProtection" or id == "out1RfProtection" then
            local lp = tonumber(device.preferences.out1LocalProtection)
            local rfp = tonumber(device.preferences.out1RfProtection)
            print("<<<< lp,rfp",lp,rfp)
            device:send_to_component(Protection:Set({local_protection_state = lp, rf_protection_state = rfp}), "out1")
            local query = function()
              device:send_to_component(Protection:Get({}), "out1")
             end
             device.thread:call_with_delay(2, query)
        elseif id == "out2LocalProtection" or id == "out2RfProtection" then
            local lp = tonumber(device.preferences.out2LocalProtection)
            local rfp = tonumber(device.preferences.out2RfProtection)
            print("<<<< lp,rfp",lp,rfp)
            device:send_to_component(Protection:Set({local_protection_state = lp, rf_protection_state = rfp}), "out2")
            local query = function()
             device:send_to_component(Protection:Get({}), "out2")
            end
            device.thread:call_with_delay(2, query)
        end
        --end
      end
    end
    local query = function()
      device:refresh()
    end
    device.thread:call_with_delay(2, query)

end

preferences.get_device_parameters = function(zw_device)
  for _, device in pairs(devices) do
    if zw_device:id_match(
      device.MATCHING_MATRIX.mfrs,
      device.MATCHING_MATRIX.product_types,
      device.MATCHING_MATRIX.product_ids) then
      return device.PARAMETERS
    end
  end
  return nil
end

preferences.to_numeric_value = function(new_value)
  local numeric = tonumber(new_value)
  if numeric == nil then -- in case the value is boolean
    numeric = new_value and 1 or 0
  end
  return numeric
end

return preferences
