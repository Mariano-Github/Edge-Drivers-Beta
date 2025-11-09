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

-- Modified M.Colmenarejo 2022

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local utils = require "st.utils"
local data_types = require "st.zigbee.data_types"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local PowerConfiguration = zcl_clusters.PowerConfiguration
local battery_defaults = require "st.zigbee.defaults.battery_defaults"

--- Temperature Mesurement config Samjin
local IASZone = zcl_clusters.IASZone
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"

local signal = require "signal-metrics"
local write = require "writeAttribute"
--local child_devices = require "child-devices"
local xiaomi_utils = require "xiaomi_utils"

-- custom capabilities
local sensor_Sensitivity = capabilities["legendabsolute60149.sensorSensitivity"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]


-- no offline function
local function no_offline(self,device)

  if device.network_type == "DEVICE_EDGE_CHILD" then return end-- is CHILD DEVICE

  print("***** function no_offline *********")

  if device:get_model() == "MS01" or 
    device:get_model() == "ms01" or
    device:get_manufacturer() == "TUYATEC-smmlguju" or
    device:get_manufacturer() == "TUYATEC-zn9wyqtr" then

      ------ Timer activation
      device.thread:call_on_schedule( 1200,
      function ()
        local last_state = device:get_latest_state("main", capabilities.motionSensor.ID, capabilities.motionSensor.motion.NAME)
        print("<<<<< TIMER Last status >>>>>> ", last_state)
        if last_state == "active" then
          device:emit_event(capabilities.motionSensor.motion.active())
        else
          device:emit_event(capabilities.motionSensor.motion.inactive())
        end
        local value = "Refresh state: ".. os.date("%Y/%m/%d GMT: %H:%M",os.time())
        device:emit_event(signal_Metrics.signalMetrics({value = value}, {visibility = {displayed = false }}))
      end
      ,'Refresh state')
  end  
end

-- preferences update
local function do_preferences(self, device, event, args)
  print("***** infoChanged *********")
  
   for id, value in pairs(device.preferences) do
    --print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:", id, "old:", oldPreferenceValue, "new:", newParameterValue)
      if  id == "maxTime" or id == "changeRep" then
        local maxTime = device.preferences.maxTime * 60
        local changeRep = device.preferences.changeRep
        print ("maxTime y changeRep: ", maxTime, changeRep)
        device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))

      elseif id == "humMaxTime" or id == "humChangeRep" then
        local max = device.preferences.humMaxTime * 60
        local change = device.preferences.humChangeRep * 100
        print ("Humidity maxTime & changeRep: ", max, change)
        device:send(zcl_clusters.RelativeHumidity.attributes.MeasuredValue:configure_reporting(device, 30, max, change):to_endpoint (4))

      elseif id == "illuMaxTime" or id == "illuChangeRep" then
        local max = device.preferences.illuMaxTime * 60
        local change = math.floor(10000 * (math.log((device.preferences.illuChangeRep), 10)))
        print ("Illumin maxTime & changeRep: ", max, change)
        device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, max, change):to_endpoint (5))
      
      --- Configure motionSensitivity IAS cluster 0x0500 and attribute 0013 
      elseif id == "motionSensitivity" then
        print("<<< Write Sensitivity Level >>>")
        local value_send = newParameterValue
        local data_value = {value = value_send, ID = 0x20}
        local cluster_id = {value = 0x0500}
        --write atribute for zigbee standard devices
        local attr_id = 0x0013
        write.write_attribute_function(device, cluster_id, attr_id, data_value)

        device.thread:call_with_delay(3, function(d)
          --device:send_to_component("main", zcl_clusters.Basic.attributes.ApplicationVersion:read(device))
          device:send_to_component("main", zcl_clusters.IASZone.attributes.CurrentZoneSensitivityLevel:read(device))
          device:send_to_component("main", zcl_clusters.IASZone.attributes.NumberOfZoneSensitivityLevelsSupported:read(device))
        end)

      --- Configure motionSensitivity Namron cluster 0x0406 attribute 0x1000 manufacturer 0x1224
      elseif id == "motionSensitivityNamron" then
        local value_send = device.preferences.motionSensitivityNamron
        if value_send == nil then value_send = 15 end
        --local data_value = data_types.Enum8
        --local cluster_id = 0x0406
        --local attr_id = 0x1000
        --mfg_code = 0x1224
        device:send(write.custom_write_attribute(device, 0x0406, 0x1000, data_types.Enum8, value_send, 0x1224))

      --- Configure motionBlindTime Namron cluster 0x0406 attribute 0x1001 manufacturer 0x1224
      elseif id == "motionBlindTime" then
        local value_send = device.preferences.motionBlindTime
        if value_send == nil then value_send = 15 end
        --local data_value = data_types.Uint8
        --local cluster_id = 0x0406
        --local attr_id = 0x1001
        --mfg_code = 0x1224
        device:send(write.custom_write_attribute(device, 0x0406, 0x1001, data_types.Uint8, value_send, 0x1224))

      --- Configure unoccupiedDelay cluster 0x0406 attribute 0x0010 
      elseif id == "unoccupiedDelay" then
        local value_send = device.preferences.unoccupiedDelay
        if value_send == nil then value_send = 30 end
        device:send(zcl_clusters.OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(device, value_send))


      elseif id == "iasZoneReports" and device:get_manufacturer() ~= "IKEA of Sweden" and device:get_model() ~= "lumi.sen_ill.mgl01" then
        -- Configure iasZone interval report
        local interval = device.preferences.iasZoneReports
        if device.preferences.iasZoneReports == nil then interval = 300 end
        local config ={
          cluster = IASZone.ID,
          attribute = IASZone.attributes.ZoneStatus.ID,
          minimum_interval = 30,
          maximum_interval = interval,
          data_type = IASZone.attributes.ZoneStatus.base_type,
          reportable_change = 1
        }
        device:send(IASZone.attributes.ZoneStatus:configure_reporting(device, 30, interval, 1))
      
        
      
      elseif id == "motionSensitivitySonoff" then
        print("<<< Write Sensitivity Level sonoff>>>")
        local value_send = tonumber(device.preferences.motionSensitivitySonoff)
        device:send(zcl_clusters.OccupancySensing.attributes.UltrasonicUnoccupiedToOccupiedThreshold:write(device, value_send))
      elseif id == "unoccupiedDelaySonoff" then
        print("<<< Write unoccupied Delay sonoff>>>")
        local value_send = device.preferences.unoccupiedDelaySonoff
        device:send(zcl_clusters.OccupancySensing.attributes.UltrasonicOccupiedToUnoccupiedDelay:write(device, value_send))
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

  print("Device ID >>>", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len)

  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")

  local firmware_full_version = device.data.firmwareFullVersion
  if firmware_full_version == nil then firmware_full_version = "Unknown" end
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
end

-- do_configure
local function do_configure(self,device)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end-- is CHILD DEVICE

  if device:get_manufacturer() ~= "IKEA of Sweden" and
  device:get_manufacturer() ~= "NAMRON AS" and
  device:get_model() ~= "lumi.sen_ill.mgl01" then
    -- Configure iasZone interval report and monitoring atrribute
    local interval = device.preferences.iasZoneReports
    if device.preferences.iasZoneReports == nil then interval = 300 end
    local config ={
      cluster = IASZone.ID,
      attribute = IASZone.attributes.ZoneStatus.ID,
      minimum_interval = 30,
      maximum_interval = interval,
      data_type = IASZone.attributes.ZoneStatus.base_type,
      reportable_change = 1
    }
    --device:send(IASZone.attributes.ZoneStatus:configure_reporting(device, 30, interval, 1))
    device:add_configured_attribute(config)
  

  
    --print("monitored_attrs-Before remove att 0x0002 >>>>>>",utils.stringify_table(monitored_attrs))
  
   -- print("monitored_attrs-After remove att 0x0002 >>>>>>",utils.stringify_table(monitored_attrs))
    if device:get_model() == "MS01" or 
    device:get_model() == "ms01" or
    device:get_manufacturer() == "TUYATEC-smmlguju" or
    device:get_manufacturer() == "TUYATEC-zn9wyqtr" then
      config ={
        cluster = PowerConfiguration.ID,
        attribute = PowerConfiguration.attributes.BatteryPercentageRemaining.ID,
        minimum_interval = 30,
        maximum_interval = 1800,
        data_type = PowerConfiguration.attributes.BatteryPercentageRemaining.base_type,
        reportable_change = 1
      }
      device:add_configured_attribute(config)
    
    end
  end

  device:configure() -- mod (09/01/2023)


  if device:get_manufacturer() == "frient A/S" or 
      (device:get_manufacturer() == "IKEA of Sweden" and device:get_model() == "TRADFRI motion sensor") or
      device:get_manufacturer() == "SmartThings" or
      device:get_manufacturer() == "Bosch" or
      device:get_manufacturer() == "Konke" or
      device:get_manufacturer() == "NYCE"  or
      device:get_manufacturer() == "CentraLite" or
      device:get_manufacturer() == "Universal Electronics Inc" or
      device:get_manufacturer() == "Visonic" or
      device:get_manufacturer() == "TLC" or
      device:get_manufacturer() == "Develco Products A/S" or
      device:get_manufacturer() == "LUMI" or
      (device:get_manufacturer() == "iMagic by GreatStar" and device:get_model() == "1117-S") then

        device:send(device_management.build_bind_request(device, zcl_clusters.PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
        device:send(zcl_clusters.PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 30, 21600, 1))
  elseif device:get_model() == "SNZB-06P" then
    device:send(device_management.build_bind_request(device, zcl_clusters.OccupancySensing.ID, self.environment_info.hub_zigbee_eui))
    device:send(zcl_clusters.OccupancySensing.attributes.Occupancy:configure_reporting(device, 0, 600))
  end

  if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
    local maxTime = device.preferences.maxTime * 60
    local changeRep = device.preferences.changeRep
    print ("maxTime:", maxTime, "changeRep:", changeRep)
    device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
  end
  print("doConfigure performed, transitioning device to PROVISIONED") --23/12/23
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })

  --- Configure motionSensitivity IAS cluster 0x0500 and attribute 0013
  if device.preferences.motionSensitivity ~= nil then
    print("<<< Write Sensitivity Level >>>")
    local value_send = device.preferences.motionSensitivity
    local data_value = {value = value_send, ID = 0x20}
    local cluster_id = {value = 0x0500}
    local attr_id = 0x0013
    write.write_attribute_function(device, cluster_id, attr_id, data_value)

    device.thread:call_with_delay(4, function(d)
      device:send_to_component("main", zcl_clusters.IASZone.attributes.CurrentZoneSensitivityLevel:read(device))
    end)
  elseif device.preferences.motionSensitivitySonoff ~= nil then
    --if device:get_manufacturer() == "SONOFF" then
    print("<<< Write Sensitivity Level sonoff>>>")
    local value_send = tonumber(device.preferences.motionSensitivitySonoff)
    device:send(zcl_clusters.OccupancySensing.attributes.UltrasonicUnoccupiedToOccupiedThreshold:write(device, value_send))
  elseif device.preferences.unoccupiedDelaySonoff ~= nil then
    print("<<< Write unoccupied Delay sonoff>>>")
    local value_send = device.preferences.unoccupiedDelaySonoff
    device:send(zcl_clusters.OccupancySensing.attributes.UltrasonicOccupiedToUnoccupiedDelay:write(device, value_send))
  end
end

local function applicationVersion_handler(self, device, value, zb_rx)
  print("Firmware >>>>>>>>>",value.value)
  --print("zb_rx >>>>>>",utils.stringify_table(zb_rx))
  local body = zb_rx.body.zcl_body.attr_records
  --print("body >>>>>>",utils.stringify_table(body))
  local status = body[1].status.value
  print("<<<<<< applicationVersion_handler Status >>>>>>>",status)

end

local function currentZoneSensitivityLevel_handler(self, device, value, zb_rx)
  print("currentZoneSensitivityLevel >>>>>>>>>",value.value)
  local sensitivity = tostring(value.value)
  device:emit_event(sensor_Sensitivity.sensorSensitivity(sensitivity))

  --local body = zb_rx.body.zcl_body.attr_records
  --print("body >>>>>>",utils.stringify_table(body))
  --local status = body[1].status.value
  --print("<<<<<< currentZoneSensitivityLevel Status >>>>>>>",status)

    -- emit signal metrics
    signal.metrics(device, zb_rx)
end

--- NumberOfZoneSensitivityLevelsSupported_handler
local function NumberOfZoneSensitivityLevelsSupported_handler(self, device, value, zb_rx)
  print("NumberOfZoneSensitivityLevelsSupported >>>>>>>>>",value.value)
end

local function do_init(self, device)

  if device.network_type == "DEVICE_EDGE_CHILD" then return end-- is CHILD DEVICE

  print("<<<<< do_init for Main int.lua >>>>>>")

  if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
    device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
  end

  -- set battery type and quantity
  --print("<<<< read battery type and quantity >>>>>")
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

  -- set timer for offline devices issue
  no_offline(self, device)

  if device:get_manufacturer() ~= "IKEA of Sweden" and
  device:get_manufacturer() ~= "NAMRON AS" and
  device:get_model() ~= "lumi.sen_ill.mgl01" then

    -- Configure iasZone monitoring atrribute
    local interval = device.preferences.iasZoneReports
    if device.preferences.iasZoneReports == nil then interval = 300 end
    local config ={
      cluster = IASZone.ID,
      attribute = IASZone.attributes.ZoneStatus.ID,
      minimum_interval = 30,
      maximum_interval = interval,
      data_type = IASZone.attributes.ZoneStatus.base_type,
      reportable_change = 1
    }
    --device:send(IASZone.attributes.ZoneStatus:configure_reporting(device, 30, device.preferences.iasZoneReports, 1))
    device:add_configured_attribute(config)
  

    if device:get_model() == "MS01" or 
    device:get_model() == "ms01" or
    device:get_manufacturer() == "TUYATEC-smmlguju" or
    device:get_manufacturer() == "TUYATEC-zn9wyqtr" then
      config ={
        cluster = PowerConfiguration.ID,
        attribute = PowerConfiguration.attributes.BatteryPercentageRemaining.ID,
        minimum_interval = 30,
        maximum_interval = 1800,
        data_type = PowerConfiguration.attributes.BatteryPercentageRemaining.base_type,
        reportable_change = 1
      }
      device:add_configured_attribute(config)
    
    end

  
    --print("monitored_attrs-Before remove att 0x0002 >>>>>>",utils.stringify_table(monitored_attrs))
  
    --print("monitored_attrs-After remove att 0x0002 >>>>>>",utils.stringify_table(monitored_attrs))

    local firmware_full_version = device.data.firmwareFullVersion
    if device:get_model() == "SNZB-06P" and firmware_full_version ~= nil then
      firmware_full_version = tonumber(device.data.firmwareFullVersion)
      print("<<< firmware_full_version:",firmware_full_version)
      if firmware_full_version >= 1005 then
        device.thread:call_with_delay(5, function(d)
          device:try_update_metadata({profile = "sonoff-motion-occupancy-105"})
        end)
      end
      config ={
        cluster = zcl_clusters.OccupancySensing.ID,
        attribute = 0x0000,
        minimum_interval = 0,
        maximum_interval = 600,
        data_type = zcl_clusters.OccupancySensing.attributes.Occupancy.base_type,
      }
      device:add_configured_attribute(config)
    
    end
    if device:get_manufacturer() == "frient A/S" or 
      (device:get_manufacturer() == "IKEA of Sweden" and device:get_model() == "TRADFRI motion sensor") or
      device:get_manufacturer() == "SmartThings" or
      device:get_manufacturer() == "Bosch" or
      device:get_manufacturer() == "Konke" or
      device:get_manufacturer() == "NYCE"  or
      device:get_manufacturer() == "CentraLite" or
      device:get_manufacturer() == "Universal Electronics Inc" or
      device:get_manufacturer() == "Visonic" or
      device:get_manufacturer() == "TLC" or
      device:get_manufacturer() == "Develco Products A/S" or
      device:get_manufacturer() == "LUMI" or
      (device:get_manufacturer() == "iMagic by GreatStar" and device:get_model() == "1117-S") then

        battery_defaults.build_linear_voltage_init(2.3, 3.0)
    end
  end
  device:refresh()
end

--- sensor_Sensitivity_handler
local function sensor_Sensitivity_handler(self, device, command)
  print("command.args.value >>>>>", command.args.value)

  if command.args.value == "Read" then
    device:emit_event(sensor_Sensitivity.sensorSensitivity("Read Attribute"))
    --- Read firmware version and sensor_Sensitivity
    --device:send_to_component("main", zcl_clusters.Basic.attributes.ApplicationVersion:read(device))
    device:send_to_component("main", zcl_clusters.IASZone.attributes.CurrentZoneSensitivityLevel:read(device))
    device:send_to_component("main", zcl_clusters.IASZone.attributes.NumberOfZoneSensitivityLevelsSupported:read(device))
  end
end

-- battery_percentage_handler
local function battery_percentage_handler(driver, device, raw_value, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)

  if device:get_manufacturer() == "Samjin" then
    local raw_percentage = raw_value.value - (200 - raw_value.value) / 2
    --print("raw_value >>>>",raw_value.value)
    --print("raw_percentage >>>>",raw_percentage)
    local percentage = utils.clamp_value(utils.round(raw_percentage / 2), 0, 100)
    device:emit_event(capabilities.battery.battery(percentage))
  elseif device:get_manufacturer() == "NAMRON AS" then
    local percentage = utils.clamp_value(utils.round(raw_value.value), 0, 100)
    device:emit_event(capabilities.battery.battery(percentage))
  else
    local percentage = utils.clamp_value(utils.round(raw_value.value / 2), 0, 100)
    device:emit_event(capabilities.battery.battery(percentage))
  end
end

--- do_driverSwitched
local function do_driverSwitched(self, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then return end-- is CHILD DEVICE
  print("<<<< DriverSwitched >>>>")
  device.thread:call_with_delay(2, function(d)
    do_configure(self, device)
  end, "configure") 
end
local version = require "version"

local lazy_handler
if version.api >= 15 then
  lazy_handler = require "st.utils.lazy_handler"
else
  lazy_handler = require
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

  local function illuminance_state_handler(driver, device, value, zb_rx)
    print("<<< Illuminance handler >>>")
    -- emit signal metrics
    signal.metrics(device, zb_rx)
  
    device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(value.value))
  end

  --illuminance_measurement_defaults
local function illuminance_measurement_defaults(driver, device, value, zb_rx)

  -- emit signal metrics
  signal.metrics(device, zb_rx)

  local lux_value = math.floor(10 ^ ((value.value - 1) / 10000))
  if lux_value < 0 then lux_value = 0 end
  if device:get_model() == "lumi.sensor_motion.aq2" then
    lux_value = value.value
  end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(lux_value))
  
end

  local function do_refresh(driver, device)
    if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
      device:send(tempMeasurement.attributes.MeasuredValue:read(device))
      --device:send(tempMeasurement.attributes.MaxMeasuredValue:read(device))
      --device:send(tempMeasurement.attributes.MinMeasuredValue:read(device))
    end
    device:refresh()
  end

local zigbee_motion_driver = {
  supported_capabilities = {
    capabilities.motionSensor,
    --capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.battery,
    capabilities.presenceSensor,
    capabilities.contactSensor,
    capabilities.occupancySensor,
    capabilities.illuminanceMeasurement,
    capabilities.powerSource,
    capabilities.refresh
  },
  lifecycle_handlers = {
    init = do_init,
    infoChanged = do_preferences,
    driverSwitched = do_driverSwitched, -- 23/12/23
    doConfigure = do_configure
},
capability_handlers = {
  [sensor_Sensitivity.ID] = {
    [sensor_Sensitivity.commands.setSensorSensitivity.NAME] = sensor_Sensitivity_handler,
  },
  [capabilities.refresh.ID] = {
    [capabilities.refresh.commands.refresh.NAME] = do_refresh,
  }
},
zigbee_handlers = {
  attr = {
    --[zcl_clusters.Basic.ID] = {
       --[zcl_clusters.Basic.attributes.ApplicationVersion.ID] = applicationVersion_handler
    --},
    [zcl_clusters.basic_id] = {
      [0xFF02] = xiaomi_utils.battery_handler,
      [0xFF01] = xiaomi_utils.battery_handler
    },
    [0xFC11] = {
      [0x2001] = illuminance_state_handler -- for sonoff SNZB-06P
    },
    [zcl_clusters.IlluminanceMeasurement.ID] = {
      [zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_measurement_defaults
    },
    [zcl_clusters.IASZone.ID] = {
      [zcl_clusters.IASZone.attributes.CurrentZoneSensitivityLevel.ID] = currentZoneSensitivityLevel_handler,
      [zcl_clusters.IASZone.attributes.NumberOfZoneSensitivityLevelsSupported.ID] = NumberOfZoneSensitivityLevelsSupported_handler
    },
    [zcl_clusters.PowerConfiguration.ID] = {
      [zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_percentage_handler
    }
 }
},
  sub_drivers = { lazy_load_if_possible("aurora"),
                  lazy_load_if_possible("ikea"),
                  lazy_load_if_possible("tuya"),
                  lazy_load_if_possible("tuya-vibration"),
                  lazy_load_if_possible("gatorsystem"),
                  lazy_load_if_possible("motion_timeout"),
                  lazy_load_if_possible("nyce"),
                  lazy_load_if_possible("zigbee-plugin-motion-sensor"),
                  lazy_load_if_possible("battery"),
                  lazy_load_if_possible("temperature"),
                  lazy_load_if_possible("frient"),
                  lazy_load_if_possible("namron"),
                  lazy_load_if_possible("ikea-vallhorn"),
                  lazy_load_if_possible("aqara-fp1e")
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  health_check = false
}

defaults.register_for_default_handlers(zigbee_motion_driver, zigbee_motion_driver.supported_capabilities, {native_capability_attrs_enabled = true})
local motion = ZigbeeDriver("zigbee-motion", zigbee_motion_driver)
motion:run()
