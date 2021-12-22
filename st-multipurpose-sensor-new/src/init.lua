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

local function added(driver, device) 
    --Add the manufacturer-specific attributes to generate their configure reporting and bind requests
    for capability_id, configs in pairs(common.get_cluster_configurations(device:get_manufacturer())) do
        if device:supports_capability_by_id(capability_id) then
            for _, config in pairs(configs) do
                device:add_configured_attribute(config)
                device:add_monitored_attribute(config)
            end
        end
    end
end

----------------------Driver configuration----------------------
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
            [common.X_AXIS_ATTR_ID] = common.axis_handler(2, false),
            [common.Y_AXIS_ATTR_ID] = common.axis_handler(3, false),
            [common.Z_AXIS_ATTR_ID] = common.axis_handler(1, false)
        },
        [zcl_clusters.IASZone.ID] = {
            [zcl_clusters.IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
        }
    },
    zdo = {}
}

-- preferences update
local function do_preferences(self, device)
    local maxTime = device.preferences.maxTime * 60
    local changeRep = device.preferences.changeRep
    print ("maxTime y changeRep: ", maxTime, changeRep)
      device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
      device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
      device:configure()
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
        added = added,
        infoChanged = do_preferences
    },
    ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
    sub_drivers = { require("smartthings"), require("samjin")  }
}

--Run driver
defaults.register_for_default_handlers(zigbee_multipurpose_driver_template, zigbee_multipurpose_driver_template.supported_capabilities)
local zigbee_multipurpose = ZigbeeDriver("smartthingsMultipurposeSensor", zigbee_multipurpose_driver_template)
zigbee_multipurpose:run()