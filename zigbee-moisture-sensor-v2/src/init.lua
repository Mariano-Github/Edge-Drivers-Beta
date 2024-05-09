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

------ Author Mariano Colmenarejo (Dec 2021) --------

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local utils = require "st.utils"

local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"
local xiaomi_utils = require "xiaomi_utils"
--module emit signal metrics
local signal = require "signal-metrics"
local child_devices = require "child-devices"

--custom capabilities
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

--- Temperature Mesurement config Samjin
local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"

-- preferences update
local function do_preferences(self, device)
  
  if device.network_type == "DEVICE_EDGE_CHILD" then return end-- is CHILD DEVICE
  for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
     if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
      if  id == "maxTime" or id == "changeRep" then
        local maxTime = device.preferences.maxTime * 60
        local changeRep = device.preferences.changeRep * 100
         print ("maxTime y changeRep: ", maxTime, changeRep)
          device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
          device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
        elseif id == "childBatteries" then
          if oldPreferenceValue ~= nil and newParameterValue == true then
            child_devices.create_new(self, device, "main", "child-batteries-status")
          end
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
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- battery_percentage_handler
local function battery_percentage_handler(driver, device, raw_value, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)

  local percentage = utils.clamp_value(utils.round(raw_value.value / 2), 0, 100)
  device:emit_event(capabilities.battery.battery(percentage))
end

-- do added
local function do_added(driver, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end-- is CHILD DEVICE
  if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
    device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
  end
  device:refresh()
end

local function device_refresh(driver, device, command)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end-- is CHILD DEVICE
  device:refresh()
  if device:get_manufacturer() == "LUMI" then
    device:send(cluster_base.read_attribute(device, data_types.ClusterId(0x0000), data_types.AttributeId(0xFF01)))
    device:send(cluster_base.read_attribute(device, data_types.ClusterId(0x0000), data_types.AttributeId(0xFF02)))
  end
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
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

  -- do_configure
  local function do_configure(driver, device)
    if device:get_model() == "TS0207" then
      local config ={
        cluster = zcl_clusters.PowerConfiguration.ID,
        attribute = zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID,
        minimum_interval = 30,
        maximum_interval = 3600,
        data_type = zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.base_type,
        reportable_change = 1
      }
      device:add_configured_attribute(config)
      device:add_monitored_attribute(config)

      config ={
        cluster = zcl_clusters.IASZone.ID,
        attribute = zcl_clusters.IASZone.attributes.ZoneStatus.ID,
        minimum_interval = 30,
        maximum_interval = 2100,
        data_type = zcl_clusters.IASZone.attributes.ZoneStatus.base_type,
        reportable_change = 1
      }
      device:add_configured_attribute(config)

      device:configure() -- mod (19/04/2024)
      device:remove_monitored_attribute(0x0500, 0x0002)
    else
      device:configure() -- mod (19/04/2024)
    end
  end

----- driver template ----------
local zigbee_moisture_driver = {
  supported_capabilities = {
    capabilities.waterSensor,
    capabilities.battery,
    capabilities.refresh
  },
  lifecycle_handlers = {
    infoChanged = do_preferences,
    added = do_added,
    doConfigure = do_configure
},
capability_handlers = {
  [capabilities.refresh.ID] = {
    [capabilities.refresh.commands.refresh.NAME] = device_refresh,
  }
},
zigbee_handlers = {
  attr = {
    [zcl_clusters.PowerConfiguration.ID] = {
      [zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_percentage_handler
    },
    [zcl_clusters.basic_id] = {
      [0xFF02] = xiaomi_utils.battery_handler,
      [0xFF01] = xiaomi_utils.battery_handler
    },
  }
},
sub_drivers = {
  lazy_load_if_possible("samjin"), 
  lazy_load_if_possible("smartthings"), 
  lazy_load_if_possible("thirdreality"),
  lazy_load_if_possible("battery-virtual-status")
},
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

--------- driver run ------
defaults.register_for_default_handlers(zigbee_moisture_driver, zigbee_moisture_driver.supported_capabilities)
local moisture = ZigbeeDriver("st-zigbee-moisture", zigbee_moisture_driver)
moisture:run()
