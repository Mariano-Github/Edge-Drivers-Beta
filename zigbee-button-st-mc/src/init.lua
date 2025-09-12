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

--- Author Mariano Colmenarejo with ST zigbee button base (Dec 2021)

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local IASZone = (require "st.zigbee.zcl.clusters").IASZone

local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"

--module emit signal metrics
local signal = require "signal-metrics"

local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

local generate_event_from_zone_status = function(driver, device, zone_status, zb_rx)
   -- emit signal metrics
   signal.metrics(device, zb_rx)

  print("zone_status >>>>>>>>>",zone_status)
  local event
  local additional_fields = {
    state_change = true
  }
  if zone_status:is_alarm1_set() and zone_status:is_alarm2_set() then
    event = capabilities.button.button.held(additional_fields)
  elseif zone_status:is_alarm1_set() then
    event = capabilities.button.button.pushed(additional_fields)
  elseif zone_status:is_alarm2_set() then
    event = capabilities.button.button.double(additional_fields)
  end
  if event ~= nil then
    device:emit_event_for_endpoint(
      zb_rx.address_header.src_endpoint.value,
      event)
  end
end

--- Default handler for zoneStatus attribute on the IAS Zone cluster
---
--- This converts the 2 byte bitmap value to motionSensor.motion."active" or motionSensor.motion."inactive"
---
--- @param driver Driver The current driver running containing necessary context for execution
--- @param device ZigbeeDevice The device this message was received from containing identifying information
--- @param zone_status 2 byte bitmap zoneStatus attribute value of the IAS Zone cluster
--- @param zb_rx ZigbeeMessageRx the full message this report came in

local ias_zone_status_attr_handler = function(driver, device, zone_status, zb_rx)
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--- Default handler for zoneStatus change handler
---
--- This converts the 2 byte bitmap value to motionSensor.motion."active" or motionSensor.motion."inactive"
---
--- @param driver Driver The current driver running containing necessary context for execution
--- @param device ZigbeeDevice The device this message was received from containing identifying information
--- @param zb_rx containing zoneStatus attribute value of the IAS Zone cluster

local ias_zone_status_change_handler = function(driver, device, zb_rx)
  generate_event_from_zone_status(driver, device, zb_rx.body.zcl_body.zone_status, zb_rx)
end

local function added_handler(self, device)
  device:emit_event(capabilities.button.supportedButtonValues({"pushed","held","double"}))
  device:emit_event(capabilities.button.numberOfButtons({value = 1}))
end

--- Update preferences after infoChanged recived---
local function do_preferences (self, device, event, args)
    for id, value in pairs(device.preferences) do
      local oldPreferenceValue = args.old_st_store.preferences[id]
      local newParameterValue = device.preferences[id]
      if device:get_field(id) ~= nil then
        device:set_field(id, nil, {persist = false})
      end
      if oldPreferenceValue ~= newParameterValue then
        print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
        --- Configure new preferences values
        if id == "maxTime" or id == "changeRep" then  
          local maxTime = device.preferences.maxTime * 60
          local changeRep = device.preferences.changeRep
          print ("maxTime y changeRep: ", maxTime, changeRep)
          --device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
          device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
          local config ={
            cluster = zcl_clusters.TemperatureMeasurement.ID,
            attribute = zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.ID,
            minimum_interval = 30,
            maximum_interval = maxTime,
            data_type = zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.base_type,
            reportable_change = changeRep
          }
          device:add_monitored_attribute(config)
        elseif id == "batteryType" and newParameterValue ~= nil then
          device:emit_event(capabilities.battery.type(newParameterValue))
        elseif id == "batteryQuantity" and newParameterValue ~= nil then
          device:emit_event(capabilities.battery.quantity(newParameterValue))
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

-- do configure for temperature reports
  local function do_configure(self,device)
    if device.network_type == "DEVICE_EDGE_CHILD" then return end -- is CHILD DEVICE
    if device:get_manufacturer() == "Samjin" then
      local maxTime = device.preferences.maxTime * 60
      local changeRep = device.preferences.changeRep
      print ("maxTime y changeRep: ",maxTime, changeRep )
      device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
      device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
      local config ={
        cluster = zcl_clusters.TemperatureMeasurement.ID,
        attribute = zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.ID,
        minimum_interval = 30,
        maximum_interval = maxTime,
        data_type = zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.base_type,
        reportable_change = changeRep
      }
      device:add_configured_attribute(config)
      device:add_monitored_attribute(config)
    end
    device:configure()
  end

  ---- temperature handler
local function temp_attr_handler(self, device, tempvalue, zb_rx)
   -- emit signal metrics
   signal.metrics(device, zb_rx)

  tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)
end

local function do_init(self,device)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end -- is CHILD DEVICE
  if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
    device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
  end
  -- set battery type and quantity
  --device:send(zcl_clusters.PowerConfiguration.attributes.BatterySize:read(device))
  --device:send(zcl_clusters.PowerConfiguration.attributes.BatteryQuantity:read(device))
  if device:supports_capability_by_id(capabilities.battery.ID) then
    local cap_status = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.type.NAME)
    if cap_status == nil and device.preferences.batteryType ~= nil then
      device:emit_event(capabilities.battery.type(device.preferences.batteryType))
    end

    cap_status = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.quantity.NAME)
    if cap_status == nil and device.preferences.batteryQuantity ~= nil then
      device:emit_event(capabilities.battery.quantity(device.preferences.batteryQuantity))
    end
  end

  if device:get_manufacturer() == "Samjin" then
    local maxTime = device.preferences.maxTime * 60
    local changeRep = device.preferences.changeRep
    print ("maxTime y changeRep: ",maxTime, changeRep )
    local config ={
      cluster = zcl_clusters.TemperatureMeasurement.ID,
      attribute = zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.ID,
      minimum_interval = 30,
      maximum_interval = maxTime,
      data_type = zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.base_type,
      reportable_change = changeRep
    }
    device:add_configured_attribute(config)
    device:add_monitored_attribute(config)
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

local zigbee_button_driver_template = {
  supported_capabilities = {
    capabilities.button,
    capabilities.battery,
    capabilities.refresh
  },
  zigbee_handlers = {
  attr = {
    [IASZone.ID] = {
      [IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
    },
    [tempMeasurement.ID] = {
      [tempMeasurement.attributes.MeasuredValue.ID] = temp_attr_handler
    },
  },
  cluster = {
      [IASZone.ID] = {
        [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    }
  },
  lifecycle_handlers = {
    added = added_handler,
    infoChanged = do_preferences,
    doConfigure = do_configure,
    init = do_init
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  health_check = false,
  sub_drivers = {
    lazy_load_if_possible("samjin-battery"), 
    lazy_load_if_possible("ezviz"), 
  }
}

defaults.register_for_default_handlers(zigbee_button_driver_template, zigbee_button_driver_template.supported_capabilities)
local zigbee_button = ZigbeeDriver("zigbee_button", zigbee_button_driver_template)
zigbee_button:run()
