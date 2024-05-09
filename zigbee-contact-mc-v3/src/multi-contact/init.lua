--- M. Colmenarejo
local zcl_clusters = require "st.zigbee.zcl.clusters"
local constants = require "st.zigbee.constants"
local contact_sensor_defaults = require "st.zigbee.defaults.contactSensor_defaults"
local common = require("multi-contact/common")
local signal = require "signal-metrics"

local can_handle = function(opts, driver, device)
    if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
        local subdriver = require("multi-contact")
        if device:get_manufacturer() == "SmartThings" and device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU" then
        return true, subdriver
        elseif device:get_manufacturer() == "Samjin" then
            return true, subdriver
        elseif device:get_manufacturer() == "CentraLite" and device:get_model() == "3321-S" then
            return true, subdriver
        end
        subdriver = nil
    end
    return false
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
        --added = do_added,
    },
    ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
    sub_drivers = {
        require("multi-contact/smartthings")
    },

    can_handle = can_handle
}

return multipurpose_driver_template