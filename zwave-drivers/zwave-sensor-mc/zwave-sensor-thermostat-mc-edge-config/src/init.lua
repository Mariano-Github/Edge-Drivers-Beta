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
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.CommandClass.Configuration
--local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })
--- @type st.zwave.CommandClass.Association
--local Association = (require "st.zwave.CommandClass.Association")({ version=2 })
--- @type st.zwave.CommandClass.Notification
--local Notification = (require "st.zwave.CommandClass.Notification")({ version=3 })
--- @type st.zwave.CommandClass.WakeUp
--local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 2 })
local Version = (require "st.zwave.CommandClass.Version")({ version = 2 })
local preferences = require "preferences"
local configurations = require "configurations"

local child_devices = require "child-devices"

--- ******** Handle preference changes is in subdriver "device-config" *********
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param event table
--- @param args
local function info_changed(self, device, event, args)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    if not device:is_cc_supported(cc.WAKE_UP) then
      preferences.update_preferences(self, device, args)
    else
      if device.preferences.parameterSendDelay == "NoDelay" or device.preferences.parameterSendDelay == nil then
        preferences.update_preferences(self, device, args)
      end
    end

    --create child devices
    for id, value in pairs(device.preferences) do
      local oldPreferenceValue = device:get_field(id)
      local newParameterValue = device.preferences[id]

      if oldPreferenceValue ~= newParameterValue then
        print("<<< Preference Changed:", id, "Old preference value:", oldPreferenceValue, "New preference vaule:", newParameterValue)
        device:set_field(id, newParameterValue, {persist = true})
        if id == "childThermostat" and newParameterValue == true then
          child_devices.create_new(self, device, "main", "child-thermostat")
        elseif id == "childThermostat1" and newParameterValue == true then
          print("<< Create child thermostat-1")
          child_devices.create_new(self, device, "externalTemp1", "child-thermostat")
        elseif id == "childThermostat2" and newParameterValue == true then
          child_devices.create_new(self, device, "externalTemp2", "child-thermostat")
        elseif id == "childThermostat3" and newParameterValue == true then
          child_devices.create_new(self, device, "externalTemp3", "child-thermostat")
        elseif id == "childThermostat4" and newParameterValue == true then
          child_devices.create_new(self, device, "externalTemp4", "child-thermostat")
        elseif id == "configChild" and newParameterValue == true then
          child_devices.create_new(self, device, "config", "zwave-device-info")
        elseif id == "changeProfileExtTemp" and newParameterValue == "0" then
          device:try_update_metadata({profile = "secure-humidity-temperature-battery"})
        elseif id == "changeProfileExtTemp" and newParameterValue == "1" then
          device:try_update_metadata({profile = "secure-humidity-temperature-battery-1"})
        elseif id == "changeProfileExtTemp" and newParameterValue == "2" then
          device:try_update_metadata({profile = "secure-humidity-temperature-battery-2"})
        elseif id == "changeProfileExtTemp" and newParameterValue == "3" then
          device:try_update_metadata({profile = "secure-humidity-temperature-battery-3"})
        elseif id == "changeProfileExtTemp" and newParameterValue == "4" then
          device:try_update_metadata({profile = "secure-humidity-temperature-battery-4"})
        end
      end
    end
  end
end

-- assign component_to_endpoint
local function component_to_endpoint(device, component_id)
  if component_id == "main" then
    return {1}
  elseif component_id == "externalTemp1" then
    return {2}
  elseif component_id == "externalTemp2" then
    return {3}
  elseif component_id == "externalTemp3" then
    return {4}
  elseif component_id == "externalTemp4" then
    return {5}
  end
end

-- assign endpoint_to_component
local function endpoint_to_component(device, ep)
  if ep == 1 then
      return "main"
  elseif ep == 2 then
    return "externalTemp1"
  elseif ep == 3 then
    return "externalTemp2"
  elseif ep == 4 then
    return "externalTemp3"
  elseif ep == 5 then
    return "externalTemp4"
  end
end

local function device_init(self, device)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    print("<<< Device Init in main")
    device:set_update_preferences_fn(preferences.update_preferences)

    if device.zwave_manufacturer_id == 0x0059 and device.zwave_product_type == 0x000D and device.zwave_product_id == 0x0003 then
      print("<<< device.preferences.changeProfileExtTemp:", device.preferences.changeProfileExtTemp)
      if device.preferences.changeProfileExtTemp == "1" or device.preferences.changeProfileExtTemp == nil then
        device:try_update_metadata({profile = "secure-humidity-temperature-battery-1"})
      elseif device.preferences.changeProfileExtTemp == "0" then
        device:try_update_metadata({profile = "secure-humidity-temperature-battery"})
      elseif device.preferences.changeProfileExtTemp == "2" then
        device:try_update_metadata({profile = "secure-humidity-temperature-battery-2"})
      elseif device.preferences.changeProfileExtTemp == "3" then
        device:try_update_metadata({profile = "secure-humidity-temperature-battery-3"})
      elseif device.preferences.changeProfileExtTemp == "4" then
        device:try_update_metadata({profile = "secure-humidity-temperature-battery-4"})
      end
      device:set_component_to_endpoint_fn(component_to_endpoint)
      device:set_endpoint_to_component_fn(endpoint_to_component)
    end
  else
    print("<<< Device Init child in main")
    if device.parent_assigned_child_key == "config" then -- is child device config
      local parent_device = device:get_parent_device()
      if device.preferences.changeConfigProfile == "Info" then
        device:try_update_metadata({profile = "zwave-device-info"})
      elseif device.preferences.changeConfigProfile == "Config" then
        device:try_update_metadata({profile = "zwave-config"})
      elseif device.preferences.changeConfigProfile == "WakeUp" then
        device:try_update_metadata({profile = "zwave-device-wakeup"})
      elseif device.preferences.changeConfigProfile == "Param" then
        device:try_update_metadata({profile = "zwave-parameter-info"})
      elseif device.preferences.changeConfigProfile == "GroupScan" then
        device:try_update_metadata({profile = "zwave-device-groups-scan"})
      elseif device.preferences.changeConfigProfile == "Group" then
        device:try_update_metadata({profile = "zwave-device-groups"})
      else
        device:try_update_metadata({profile = "zwave-device-info"})
        parent_device:send(Version:Get({}))
      end
      device:refresh()
    end
  end
end

local function do_configure(driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    configurations.initial_configuration(driver, device)

    if not device:is_cc_supported(cc.WAKE_UP) then
      preferences.update_preferences(driver, device)
    end
  end
end

local initial_events_map = {
  [capabilities.tamperAlert.ID] = capabilities.tamperAlert.tamper.clear(),
  [capabilities.waterSensor.ID] = capabilities.waterSensor.water.dry(),
  [capabilities.moldHealthConcern.ID] = capabilities.moldHealthConcern.moldHealthConcern.good(),
  [capabilities.contactSensor.ID] = capabilities.contactSensor.contact.closed(),
  [capabilities.smokeDetector.ID] = capabilities.smokeDetector.smoke.clear(),
  [capabilities.motionSensor.ID] = capabilities.motionSensor.motion.inactive(),
  [capabilities.powerSource.ID] = capabilities.powerSource.powerSource.dc()
}

local function added_handler(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    for id, event in pairs(initial_events_map) do
      if device:supports_capability_by_id(id) then
        device:emit_event(event)
      end
    end
    device:refresh()
  end
  --device:refresh()
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
    capabilities.waterSensor,
    capabilities.colorControl,
    capabilities.contactSensor,
    capabilities.motionSensor,
    capabilities.relativeHumidityMeasurement,
    capabilities.illuminanceMeasurement,
    capabilities.battery,
    capabilities.tamperAlert,
    capabilities.temperatureAlarm,
    capabilities.temperatureMeasurement,
    capabilities.switch,
    capabilities.moldHealthConcern,
    capabilities.dewPoint,
    capabilities.ultravioletIndex,
    capabilities.accelerationSensor,
    capabilities.atmosphericPressureMeasurement,
    capabilities.threeAxis,
    capabilities.bodyWeightMeasurement,
    capabilities.voltageMeasurement,
    capabilities.energyMeter,
    capabilities.powerMeter,
    capabilities.smokeDetector,
    capabilities.powerSource
  },
  sub_drivers = {
    lazy_load_if_possible("zooz-4-in-1-sensor"),
    lazy_load_if_possible("vision-motion-detector"),
    lazy_load_if_possible("fibaro-flood-sensor"),
    lazy_load_if_possible("zwave-water-temp-humidity-sensor"),
    lazy_load_if_possible("glentronics-water-leak-sensor"),
    lazy_load_if_possible("homeseer-multi-sensor"),
    lazy_load_if_possible("fibaro-door-window-sensor"),
    lazy_load_if_possible("sensative-strip"),
    lazy_load_if_possible("enerwave-motion-sensor"),
    lazy_load_if_possible("aeotec-multisensor"),
    lazy_load_if_possible("zwave-water-leak-sensor"),
    lazy_load_if_possible("everspring-motion-light-sensor"),
    lazy_load_if_possible("ezmultipli-multipurpose-sensor"),
    lazy_load_if_possible("fibaro-motion-sensor"),
    lazy_load_if_possible("thermostat"),
    require("temperature"),
    lazy_load_if_possible("nortek-contact-sensor"),
    require("device-config"),
    lazy_load_if_possible("sensor-binary-disable"),
    lazy_load_if_possible("dlink-detector")
  },
  lifecycle_handlers = {
    added = added_handler,
    init = device_init,
    --infoChanged = info_changed,
    doConfigure = do_configure
  },
  capability_handlers = {

  },
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local sensor = ZwaveDriver("zwave_sensor", driver_template)
sensor:run()
