--local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
--local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
--local defaults = require "st.zigbee.defaults"
local contact_sensor_defaults = require "st.zigbee.defaults.contactSensor_defaults"
local data_types = require "st.zigbee.data_types"
local common = require("common")
local device_management = require "st.zigbee.device_management"
--local battery_defaults = require "st.zigbee.defaults.battery_defaults"
--module emit signal metrics
local signal = require "signal-metrics"

local multi_utils = require "multi_utils"
--local utils = require "st.utils"
local SAMJIN_MFG = 0x1241
local SMARTTHINGS_MFG = 0x110A
local CENTRALITE_MFG = 0x104E


local can_handle = function(opts, driver, device)
    if device:get_manufacturer() == "SmartThings" then
      return device:get_manufacturer() == "SmartThings"
    elseif device:get_manufacturer() == "Samjin" then
        return device:get_manufacturer() == "Samjin"
    elseif device:get_manufacturer() == "CentraLite" and device:get_model() == "3321-S" then
      return device:get_model() == "3321-S"
    end
end

local function ias_zone_status_change_handler(driver, device, zb_rx)
    -- emit signal metrics
    signal.metrics(device, zb_rx)

    if (device.preferences.garageSensor ~= "Yes") then
        contact_sensor_defaults.ias_zone_status_change_handler(driver, device, zb_rx)
    end
end

local function ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
    -- emit signal metrics
    signal.metrics(device, zb_rx)
    
    if (device.preferences.garageSensor ~= "Yes") then
        contact_sensor_defaults.ias_zone_status_attr_handler(driver, device, zone_status, zb_rx)
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
    elseif device:get_manufacturer() == "SmartThings" then
        local accelThreshold = device.preferences.accelThresholdST
        device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_MULTIPLIER_ATTR, data_types.Uint8, 0x01, SMARTTHINGS_MFG))
        device:send(multi_utils.custom_write_attribute(device, multi_utils.MOTION_THRESHOLD_ATTR, data_types.Uint16, accelThreshold, SMARTTHINGS_MFG))
    end
end

local function do_added(self, device) 
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


local multipurpose_driver_template = {
    NAME = "Multiporpuse",

    zigbee_handlers ={
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
    },
    lifecycle_handlers = {
        --init = added,
        added = do_added,
    },
    ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
    sub_drivers = {
        require("multi-contact/smartthings")
    },

    can_handle = can_handle
}

return multipurpose_driver_template