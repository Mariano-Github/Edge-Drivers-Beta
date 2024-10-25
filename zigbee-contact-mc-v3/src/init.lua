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
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local configurationMap = require "configurations"

local clusters = require "st.zigbee.zcl.clusters"
local device_management = require "st.zigbee.device_management"
local tempMeasurement = clusters.TemperatureMeasurement
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local IASZone = clusters.IASZone

local multi_utils = require "multi_utils"
local data_types = require "st.zigbee.data_types"
local SAMJIN_MFG = 0x1241
local SMARTTHINGS_MFG = 0x110A
local CENTRALITE_MFG = 0x104E
local SMARTSENSE_MULTI_SENSOR_CUSTOM_PROFILE = 0xFC01

--module emit signal metrics
local signal = require "signal-metrics"
local child_devices = require "child-devices"
local common = require("multi-contact/common")

local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]
--local MONITORED_ATTRIBUTES_KEY = "__monitored_attributes"

-- no offline function users request
local function no_offline(self,device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    print("***** function no_offline *********")

    if device:get_manufacturer() == "_TZ3000_f1hmoyj4" or
      --device:get_manufacturer() == "_TZ1800_ejwkn2h2" or
      device:get_manufacturer() == "eWeLink" or
      device:get_manufacturer() == "TUYATEC-rkqiqvcs" then

      ------ Timer activation
      device.thread:call_on_schedule( 1200,
      function ()
        local last_state = device:get_latest_state("main", capabilities.contactSensor.ID, capabilities.contactSensor.contact.NAME)
        print("<<<<< TIMER Last status >>>>>> ", last_state)
        if last_state == "closed" then
          device:emit_event(capabilities.contactSensor.contact.closed())
        else
          device:emit_event(capabilities.contactSensor.contact.open())
        end
        local value = "Refresh state: ".. os.date("%Y/%m/%d GMT: %H:%M",os.time())
        device:emit_event(signal_Metrics.signalMetrics({value = value}, {visibility = {displayed = false }}))
      end
      ,'Refresh state')
    end
  end
end

-- configure accel threshold
local function configure_accel_threshold (self,device)
  print("<<<<< configure_accel_threshold >>>>>")
  if device:get_manufacturer() == "Samjin" then
      local accelThreshold = device.preferences.accelThreshold
      device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, accelThreshold, SAMJIN_MFG))
  elseif device:get_manufacturer() == "Centralite" then
      local accelThreshold = device.preferences.accelThresholdCentralite
      device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, accelThreshold, CENTRALITE_MFG))  
  elseif device:get_manufacturer() == "SmartThings" and (device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU") then
      local accelThreshold = device.preferences.accelThresholdST
      device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, 0x01, SMARTTHINGS_MFG))
      device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_ATTR, data_types.Uint16, accelThreshold, SMARTTHINGS_MFG))
  end
end

----- Update prefeence changes
local function info_Changed(self,device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    print("***** infoChanged *********")

    -- update preferences
      for id, value in pairs(device.preferences) do
        local oldPreferenceValue = device:get_field(id)
        local newParameterValue = device.preferences[id]
        if oldPreferenceValue ~= newParameterValue then
          device:set_field(id, newParameterValue, {persist = true})
          print("<< Preference changed name:", id, "old value:", oldPreferenceValue, "new value:", newParameterValue)
          if  id == "maxTime" or id == "changeRep" then
            local maxTime = device.preferences.maxTime * 60
            local changeRep = device.preferences.changeRep
              print ("maxTime:", maxTime,"changeRep:", changeRep)
              --device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
              device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))

            --change profile tile
          elseif id == "changeTempProfile" then
              if device.preferences.changeTempProfile == "Contact" then
                device:try_update_metadata({profile = "contact-profile"})
              elseif device.preferences.changeTempProfile == "Temp" then
                device:try_update_metadata({profile = "temp-contact-profile"})
              end
          elseif id == "changeProfile" then
            ------ Set profile to aceleration or multiporpuse device
            print("<<< changeProfile >>>")
            if device.preferences.changeProfile == "Yes" or device.preferences.changeProfile == "Accel" then
              print("<<< Accel >>>")
              device:try_update_metadata({profile = "st-acceleration"})
            elseif device.preferences.changeProfile == "No" or device.preferences.changeProfile == "Multi" then
              print("<<< Multi >>>")
              device:try_update_metadata({profile = "st-multipurpose"})
            elseif device.preferences.changeProfile == "Temp" then
              print("<<< Temp >>>")
              device:try_update_metadata({profile = "st-temp-multipurpose"})
            end
          elseif id == "accelThreshold" or id == "accelThresholdCentralite" or id == "accelThresholdST" then
            configure_accel_threshold (self, device)
          elseif id == "iasZoneReports" then
            if device:get_manufacturer() == "LUMI" and device:get_model() == "lumi.sensor_magnet.aq2" then
              -- Configure OnOff interval report
              local config ={
                cluster = clusters.OnOff.ID,
                attribute = clusters.OnOff.attributes.OnOff.ID,
                minimum_interval = 0,
                maximum_interval = device.preferences.iasZoneReports,
                data_type = clusters.OnOff.attributes.OnOff.base_type
              }
              device:send(clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, device.preferences.iasZoneReports))
              device:add_monitored_attribute(config)
            elseif device:get_manufacturer() ~= "LUMI" then
              -- Configure iasZone interval report
              local config ={
                cluster = IASZone.ID,
                attribute = IASZone.attributes.ZoneStatus.ID,
                minimum_interval = 30,
                maximum_interval = device.preferences.iasZoneReports,
                data_type = IASZone.attributes.ZoneStatus.base_type,
                reportable_change = 1
              }
              device:send(IASZone.attributes.ZoneStatus:configure_reporting(device, 30, device.preferences.iasZoneReports, 1))
              --device:add_monitored_attribute(config)
              --local monitored_attrs = device:get_field(MONITORED_ATTRIBUTES_KEY) or {}
              --print("monitored_attrs-Before remove att 0x0002 >>>>>>",utils.stringify_table(monitored_attrs))
              device:remove_monitored_attribute(0x0500, 0x0002)
              --print("monitored_attrs-After remove att 0x0002 >>>>>>",utils.stringify_table(monitored_attrs))
            end
          elseif id == "childVibration" then
            if oldPreferenceValue ~= nil and newParameterValue == true then
              child_devices.create_new(self, device, "main", "child-contact-accel")
            end
          elseif id == "childBatteries" then
            if oldPreferenceValue ~= nil and newParameterValue == true then
              child_devices.create_new(self, device, "battery", "child-batteries-status")
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

    local firmware_full_version = device.data.firmwareFullVersion
    if firmware_full_version == nil then firmware_full_version = "Unknown" end
    print("<<<<< Firmware Version >>>>>",firmware_full_version)
  end
end

---- driver do_configure
local function do_configure(self,device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE 
    -- Configure contact sensors custom interval report
    local interval = device.preferences.iasZoneReports
    if device.preferences.iasZoneReports == nil then interval = 300 end
    if device:get_manufacturer() == "LUMI" and device:get_model() == "lumi.sensor_magnet.aq2" then
      -- Configure OnOff interval report
      local config ={
        cluster = clusters.OnOff.ID,
        attribute = clusters.OnOff.attributes.OnOff.ID,
        minimum_interval = 0,
        maximum_interval = interval,
        data_type = clusters.OnOff.attributes.OnOff.base_type
      }
      --device:send(clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, device.preferences.iasZoneReports))
      device:add_configured_attribute(config)
      device:add_monitored_attribute(config)
    elseif device:get_manufacturer() ~= "LUMI" then
      -- Configure iasZone interval report
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
      --device:add_monitored_attribute(config)
    end

    -- configure Accel cluster moved from added lifecycle of multi-contact subdriver
    if device:get_manufacturer() == "SmartThings" and device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU" or
    device:get_manufacturer() == "Samjin" or
    (device:get_manufacturer() == "CentraLite" and device:get_model() == "3321-S") then -- is smartthings multipupose
      ---Add the manufacturer-specific attributes to generate their configure reporting and bind requests
      for capability_id, configs in pairs(common.get_cluster_configurations(device:get_manufacturer())) do
          if device:supports_capability_by_id(capability_id) then
              device:send(device_management.build_bind_request(device, 0xFC02, self.environment_info.hub_zigbee_eui))
              for _, config in pairs(configs) do
                  --print("<<< config & monitor >>>")
                  device:add_configured_attribute(config)
                  device:add_monitored_attribute(config)
              end
          end
      end

      configure_accel_threshold (self, device)
    end

    -- custom configure to some devices to not offline
    if device:get_manufacturer() == "_TZ3000_f1hmoyj4" or
    device:get_manufacturer() == "eWeLink" or
    device:get_manufacturer() == "LUMI" or -- 3600s IAZone and batttery voltaje 3600s
    device:get_manufacturer() == "TUYATEC-rkqiqvcs" then
      print("<<< special configure battery 900 sec or LUMI >>>")
      local configuration = configurationMap.get_device_configuration(device)
      if configuration ~= nil then
        for _, attribute in ipairs(configuration) do
          device:add_configured_attribute(attribute)
          device:add_monitored_attribute(attribute)
        end
      end
    end

    device:configure()
    device:remove_monitored_attribute(0x0500, 0x0002)

    -- Configure temperature custom interval report
    if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
      if device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU" then
        local maxTime = device.preferences.maxTime * 60
        local changeRep = device.preferences.changeRep
        print ("maxTime:", maxTime, "changeRep:", changeRep)
        device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
        device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
      end
    end
    print("doConfigure performed, transitioning device to PROVISIONED")
    device:try_update_metadata({ provisioning_state = "PROVISIONED" })

  else -- is EDGE Child with Accel-contact profile
    if device.preferences.profileType == "contact" then
        local parent_device = device:get_parent_device()
        local accel_status= parent_device:get_latest_state("main", capabilities.accelerationSensor.ID, capabilities.accelerationSensor.acceleration.NAME)
        if accel_status == nil then
            device:emit_event(capabilities.accelerationSensor.acceleration("inactive"))
            device:emit_event(capabilities.contactSensor.contact.closed())
        else
            device:emit_event(capabilities.accelerationSensor.acceleration(accel_status))
            if accel_status == "inactive" then
                device:emit_event(capabilities.contactSensor.contact.closed())
            else
                device:emit_event(capabilities.contactSensor.contact.open())
            end
        end
    end
  end
end

  -- init 
local function do_init(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    
    --change profile tile
    if device.preferences.changeTempProfile == "Contact" then
      device:try_update_metadata({profile = "contact-profile"})
    elseif device.preferences.changeTempProfile == "Temp" then
      device:try_update_metadata({profile = "temp-contact-profile"})

    ------ Set profile to aceleration or multiporpuse device
    elseif device.preferences.changeProfile == "Yes" or device.preferences.changeProfile == "Accel" then
      device:try_update_metadata({profile = "st-acceleration"})
    elseif device.preferences.changeProfile == "No" or device.preferences.changeProfile == "Multi" then
      device:try_update_metadata({profile = "st-multipurpose"})
    elseif device.preferences.changeProfile == "Temp" then
      device:try_update_metadata({profile = "st-temp-multipurpose"})
    end

    if device:get_manufacturer() == "Ecolink" or 
      device:get_manufacturer() == "frient A/S" or
      device:get_manufacturer() == "Sercomm Corp." or
      device:get_manufacturer() == "Universal Electronics Inc" or
      device:get_manufacturer() == "SmartThings" and (device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU") or
      device:get_manufacturer() == "Leedarson" or
      (device:get_manufacturer() == "LUMI" and device:get_model() ~= "lumi.sensor_magnet.aq2") or
      device:get_manufacturer() == "IKEA of Sweden" or
      device:get_manufacturer() == "CentraLite" then
        
      -- init battery voltage
      battery_defaults.build_linear_voltage_init(2.3, 3.0)

      --- Read Battery voltage
      device:send(clusters.PowerConfiguration.attributes.BatteryVoltage:read(device))

    elseif device:get_manufacturer() == "_TZ3000_f1hmoyj4" or
      device:get_manufacturer() == "eWeLink" or
      device:get_manufacturer() == "LUMI" or -- 3600s IAZone and batttery voltaje 3600s
      device:get_manufacturer() == "TUYATEC-rkqiqvcs" then
      print("<<< special configure battery 900 sec or LUMI >>>")
      local configuration = configurationMap.get_device_configuration(device)
      if configuration ~= nil then
        for _, attribute in ipairs(configuration) do
          device:add_configured_attribute(attribute)
          device:add_monitored_attribute(attribute)
        end
      end
    end

    -- Configure contact sensors custom interval report
    local interval = device.preferences.iasZoneReports
    if device.preferences.iasZoneReports == nil then interval = 300 end
    if device:get_manufacturer() == "LUMI" and device:get_model() == "lumi.sensor_magnet.aq2" then
      -- Configure OnOff interval report
      local config ={
        cluster = clusters.OnOff.ID,
        attribute = clusters.OnOff.attributes.OnOff.ID,
        minimum_interval = 0,
        maximum_interval = interval,
        data_type = clusters.OnOff.attributes.OnOff.base_type
      }
      --device:send(clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, device.preferences.iasZoneReports))
      device:add_configured_attribute(config)
      device:add_monitored_attribute(config)
    elseif device:get_manufacturer() ~= "LUMI" then
      -- Configure iasZone monitored attributes
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
      --device:add_monitored_attribute(config)
      --local monitored_attrs = device:get_field(MONITORED_ATTRIBUTES_KEY) or {}
      --print("monitored_attrs-Before remove att 0x0002 >>>>>>",utils.stringify_table(monitored_attrs))
      device:remove_monitored_attribute(0x0500, 0x0002)
      --print("monitored_attrs-After remove att 0x0002 >>>>>>",utils.stringify_table(monitored_attrs))
    end

    if device:get_latest_state("main", signal_Metrics.ID, signal_Metrics.signalMetrics.NAME) == nil then
      device:emit_event(signal_Metrics.signalMetrics({value = "Waiting Zigbee Message"}, {visibility = {displayed = false }}))
    end

    -- set timer for offline devices issue at user request
    no_offline(self,device)

    device:refresh()
  end
end

-- battery_percentage_handler
local function battery_percentage_handler(driver, device, raw_value, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)

  --print("raw_value >>>>",raw_value.value)
  local percentage = utils.clamp_value(utils.round(raw_value.value / 2), 0, 100)
  device:emit_event(capabilities.battery.battery(percentage))
end

--- do_driverSwitched
local function do_driverSwitched(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    print("<<<< DriverSwitched >>>>")
    device.thread:call_with_delay(3, function(d)
      do_configure(self, device)
    end, "configure")
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

local function do_refresh(driver, device)
  if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
    device:send(tempMeasurement.attributes.MeasuredValue:read(device))
    --device:send(tempMeasurement.attributes.MaxMeasuredValue:read(device))
    --device:send(tempMeasurement.attributes.MinMeasuredValue:read(device))
  end
  device:refresh()
end

---Driver template
local zigbee_contact_driver_template = {
  supported_capabilities = {
    capabilities.contactSensor,
    --capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.threeAxis,
    capabilities.accelerationSensor,
    capabilities.refresh
  },
  additional_zcl_profiles = {
    [SMARTSENSE_MULTI_SENSOR_CUSTOM_PROFILE] = true
  },
  lifecycle_handlers = {
    infoChanged = info_Changed,
    driverSwitched = do_driverSwitched, -- 23/12/23
    init = do_init,
    doConfigure = do_configure

    },
    capability_handlers = {
      [capabilities.refresh.ID] = {
        [capabilities.refresh.commands.refresh.NAME] = do_refresh,
      }
    },
    zigbee_handlers = {
      attr = {
        [clusters.PowerConfiguration.ID] = {
          [clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_percentage_handler
        }
     }
    },
  sub_drivers = {
    lazy_load_if_possible("battery-overrides"),
    lazy_load_if_possible("battery-voltage"),
    lazy_load_if_possible("temperature"),
    lazy_load_if_possible("multi-contact"),
    lazy_load_if_possible("smartsense-multi"),
    lazy_load_if_possible("lumi-switch-cluster"),
    lazy_load_if_possible("battery-virtual-status")
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE
}

defaults.register_for_default_handlers(zigbee_contact_driver_template, zigbee_contact_driver_template.supported_capabilities)
local zigbee_contact = ZigbeeDriver("zigbee_contact", zigbee_contact_driver_template)
zigbee_contact:run()
