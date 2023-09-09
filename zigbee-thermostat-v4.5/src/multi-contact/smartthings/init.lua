local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local battery = capabilities.battery
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local common = require("common")
local utils = require "st.utils"

local can_handle = function(opts, driver, device)
  if device:get_manufacturer() == "SmartThings" and device:get_model()== "multiv4" then
    return device:get_manufacturer() == "SmartThings"
  elseif device:get_manufacturer() == "CentraLite" and device:get_model() == "3321-S" then
    --return device:get_manufacturer() == "CentraLite"
    return device:get_model() == "3321-S"
  end
end

local battery_handler = function(driver, device, value, zb_rx)
    local batteryMap = {[28] = 100, [27] = 100, [26] = 100, [25] = 90, [24] = 90, [23] = 70,
                      [22] = 70, [21] = 50, [20] = 50, [19] = 30, [18] = 30, [17] = 15, [16] = 1, [15] = 0}
    local minVolts = 15
    local maxVolts = 28

    value = utils.clamp_value(value.value, minVolts, maxVolts)

    device:emit_event(battery.battery(batteryMap[value]))
end

local smartthings_multi_sensor = {
	NAME = "SmartThings multi sensor",
    zigbee_handlers = {
        attr = {
            [common.MFG_CLUSTER] = {
                [common.ACCELERATION_ATTR_ID] = common.acceleration_handler,
                [common.X_AXIS_ATTR_ID] = common.axis_handler(3, true), -- lua indexes from 1
                [common.Y_AXIS_ATTR_ID] = common.axis_handler(2, false),
                [common.Z_AXIS_ATTR_ID] = common.axis_handler(1, false)
            },
            --[zcl_clusters.PowerConfiguration.ID] = {
              --[zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.ID] = battery_handler
            --}
        }
    },
    lifecycle_handlers = {
        --init = battery_defaults.build_linear_voltage_init(2.3, 3.0)
    },
	can_handle = can_handle
}

return smartthings_multi_sensor
