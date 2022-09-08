local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local contact_sensor_defaults = require "st.zigbee.defaults.contactSensor_defaults"
local data_types = require "st.zigbee.data_types"
local common = require("common")
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"

local multi_utils = require "multi_utils"
local utils = require "st.utils"
local SAMJIN_MFG = 0x1241
local SMARTTHINGS_MFG = 0x110A
local CENTRALITE_MFG = 0x104E


local function ias_zone_status_change_handler(driver, device, zb_rx)
    if (device.preferences.garageSensor ~= "Yes") then
        contact_sensor_defaults.ias_zone_status_change_handler(driver, device, zb_rx)
    end
end

local function ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
    if (device.preferences.garageSensor ~= "Yes") then
        contact_sensor_defaults.ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
    end
end

-- configure accel threshold
local function configure_accel_threshold (self,device)
    if device:get_manufacturer() == "Samjin" then
        local accelThreshold = device.preferences.accelThreshold
        device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, accelThreshold, SAMJIN_MFG))
    elseif device:get_manufacturer() == "Centralite" then
        local accelThreshold = device.preferences.accelThresholdCentralite
        device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, accelThreshold, CENTRALITE_MFG))  
    elseif device:get_manufacturer() == "SmartThings" then
        local accelThreshold = device.preferences.accelThresholdST
        device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, 0x01, SMARTTHINGS_MFG))
        device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_ATTR, data_types.Uint16, accelThreshold, SMARTTHINGS_MFG))
    end
end

local function added(self, device) 
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

    ------ Set profile to aceleration or multiporpuse device
    if device.preferences.changeProfile == "Yes" or device.preferences.changeProfile == "Accel" then
        device:try_update_metadata({profile = "st-acceleration"})
    elseif device.preferences.changeProfile == "No" or device.preferences.changeProfile == "Multi" then
        device:try_update_metadata({profile = "st-multipurpose"})
    elseif device.preferences.changeProfile == "Temp" then
        device:try_update_metadata({profile = "st-temp-multipurpose"})
    end

end

----------------------Driver handelrs----------------------
local handlers = {
    global = {},
    cluster = {
        [zcl_clusters.IASZone.ID] = {
            [zcl_clusters.IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
        }
    },
    attr = {
        [common.MFG_CLUSTER] = {
            [common.ACCELERATION_ATTR_ID] = common.acceleration_handler,
            [common.X_AXIS_ATTR_ID] = common.axis_handler(1, false),
            [common.Y_AXIS_ATTR_ID] = common.axis_handler(2, false),
            [common.Z_AXIS_ATTR_ID] = common.axis_handler(3, false)
        },
        [zcl_clusters.IASZone.ID] = {
            [zcl_clusters.IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
        }
    },
    zdo = {}
}

-- preferences update
local function do_preferences(self, device)
    for id, value in pairs(device.preferences) do
        print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
        local oldPreferenceValue = device:get_field(id)
        local newParameterValue = device.preferences[id]
         if oldPreferenceValue ~= newParameterValue then
          device:set_field(id, newParameterValue, {persist = true})
          print("<< Preference changed name:", id, "Old Value:", oldPreferenceValue, "New Value:>>", newParameterValue)
          if  id == "maxTime" or id == "changeRep" then
            local maxTime = device.preferences.maxTime * 60
            local changeRep = device.preferences.changeRep
             print ("maxTime y changeRep: ", maxTime, changeRep)
              device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
              device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
              --device:configure()
          elseif id == "accelThreshold" then
            configure_accel_threshold (self, device)
                ------ Change profile to aceleration, temp or multiporpuse device
          elseif id == "changeProfile" then
            if newParameterValue == "Yes" or newParameterValue == "Accel" then
                device:try_update_metadata({profile = "st-acceleration"})
            elseif newParameterValue == "No" or newParameterValue == "Multi" then
                device:try_update_metadata({profile = "st-multipurpose"})
            elseif newParameterValue == "Temp" then
                device:try_update_metadata({profile = "st-temp-multipurpose"})
            end
          end
        end
      end
      local firmware_full_version = device.data.firmwareFullVersion
      print("<<<<< Firmware Version >>>>>",firmware_full_version)
  end

--init refresh
local function do_refresh(self, device)
    device:refresh()
end
  -----device configuration
local function device_config(self,device)
    device.thread:call_with_delay(3, function() added(self,device) end)
    device.thread:call_with_delay(6, function() do_refresh(self,device) end)
  end


local zigbee_multipurpose_driver_template = {
    supported_capabilities = {
        capabilities.contactSensor,
        capabilities.battery,
        --capabilities.temperatureMeasurement,
        capabilities.threeAxis,
        capabilities.accelerationSensor,
        capabilities.refresh
    },
    zigbee_handlers = handlers,
    lifecycle_handlers = {
        --init = added,
        --driverSwitched = added,
        --added = added,
        init = device_config,
        infoChanged = do_preferences
    },
    ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
    sub_drivers = { require("smartthings"), require("samjin")  }
}

--Run driver
defaults.register_for_default_handlers(zigbee_multipurpose_driver_template, zigbee_multipurpose_driver_template.supported_capabilities)
local zigbee_multipurpose = ZigbeeDriver("smartthingsMultipurposeSensor", zigbee_multipurpose_driver_template)
zigbee_multipurpose:run()