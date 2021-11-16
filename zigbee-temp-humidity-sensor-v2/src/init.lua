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

------ Author Mariano Colmenarejo (nov 2021) --------

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local xiaomi_utils = require "xiaomi_utils"

--- Temperature Mesurement config
local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"

-- Custom Capability AtmPressure declaration
local atmos_Pressure = capabilities ["legendabsolute60149.atmosPressure"]

--- do configure for temperature capability
local function do_configure(self,device)
  local maxTime = device.preferences.maxTime * 60
  local changeRep = device.preferences.changeRep
  print ("maxTime y changeRep: ",maxTime, changeRep )
  device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
  device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
  device:configure()
end

--- temperature handler
local function temp_attr_handler(self, device, tempvalue, zb_rx)
    tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)
end

-- preferences update
local function do_preferences(self, device)
  for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id])
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
     if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
      local maxTime = device.preferences.maxTime * 60
      local changeRep = device.preferences.changeRep
      print ("maxTime y changeRep: ", maxTime, changeRep)
      device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
      device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
      device:configure()
     end
  end
end

-- attributte handler Atmospheric pressure
local pressure_value_attr_handler = function (driver, device, value, zb_rx)
  local kPa = math.floor (value.value / 10)
  device: emit_event (capabilities.atmosphericPressureMeasurement.atmosphericPressure ({value = kPa, unit = "kPa"}))

  -- emit even for custom capability in mBar
  local mBar = value.value
  device:emit_event(atmos_Pressure.atmosPressure(mBar))
end

----- driver template ----------
local zigbee_temp_driver = {
  supported_capabilities = {
    capabilities.relativeHumidityMeasurement,
    capabilities.atmosphericPressureMeasurement,
    atmos_Pressure,
    capabilities.battery,
  },
  lifecycle_handlers = {
    doConfigure = do_configure,    
    infoChanged = do_preferences,
    driverSwitched = do_configure
  },  
  zigbee_handlers = {
    attr = {
      [zcl_clusters.basic_id] = {
        [0xFF02] = xiaomi_utils.battery_handler,
        [0xFF01] = xiaomi_utils.battery_handler
      },
      [tempMeasurement.ID] = {
          [tempMeasurement.attributes.MeasuredValue.ID] = temp_attr_handler
      },
      [zcl_clusters.PressureMeasurement.ID] = {
          [zcl_clusters.PressureMeasurement.attributes.MeasuredValue.ID] = pressure_value_attr_handler
      }
    },  
  },
  --ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE

}

--------- driver run ------
defaults.register_for_default_handlers(zigbee_temp_driver, zigbee_temp_driver.supported_capabilities)
local temperature = ZigbeeDriver("st-zigbee-temp", zigbee_temp_driver)
temperature:run()
