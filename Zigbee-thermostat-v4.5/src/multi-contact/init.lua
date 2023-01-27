local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local contact_sensor_defaults = require "st.zigbee.defaults.contactSensor_defaults"
local data_types = require "st.zigbee.data_types"
local common = require("common")
local device_management = require "st.zigbee.device_management"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"

local can_handle = function(opts, driver, device)
    if device:get_manufacturer() == "SmartThings" and device:get_model()== "multiv4" then
      return device:get_manufacturer() == "SmartThings"
    elseif device:get_manufacturer() == "Samjin" and device:get_model()== "multi" then
        return device:get_manufacturer() == "Samjin"
    elseif device:get_manufacturer() == "CentraLite" and device:get_model() == "3321-S" then
      return device:get_model() == "3321-S"
    end
end

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
    -- init battery voltage
    if device:get_manufacturer() ~= "Samjin" then
        battery_defaults.build_linear_voltage_init(2.3, 3.0)
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