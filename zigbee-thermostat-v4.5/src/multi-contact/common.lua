local capabilities = require "st.capabilities"
local data_types = require "st.zigbee.data_types"
local threeAxis = capabilities.threeAxis
local utils = require "st.utils"
local log = require "log"

local common = {}

local INTERIM_XYZ = "interim_xyz"

common.MFG_CLUSTER = 0xFC02
common.MFG_CODES = { 
    Samjin = 0x1241, 
    SmartThings = 0x110A, 
    Centralite = 0x104E 
}
common.ACCELERATION_ATTR_ID = 0x0010
common.X_AXIS_ATTR_ID = 0x0012
common.Y_AXIS_ATTR_ID = 0x0013
common.Z_AXIS_ATTR_ID = 0x0014

function common.axis_handler(axis_index, invert)
    return function(driver, device, value, zb_rx)
        local current_value = device:get_latest_state("main", threeAxis.ID, threeAxis.threeAxis.NAME, device:get_field(INTERIM_XYZ))
        if current_value == nil then current_value = {} end
        current_value[axis_index] = not invert and value.value or value.value * -1
        log.trace("current_value ",utils.stringify_table(current_value))
        if utils.table_size(current_value) == 3 then -- emit an event when we have a value for all three directions (installation)
            -- elements have to be broken out this way because of the translation to storage and back
            device:emit_event(threeAxis.threeAxis({current_value[1], current_value[2], current_value[3]}))
            device:set_field(INTERIM_XYZ,nil)
        else
            device:set_field(INTERIM_XYZ, current_value)
        end
        
        --if axis_index == 3 and device.preferences.garageSensor == "Yes" then
        if axis_index == tonumber(device.preferences.garageSensorAxis) and device.preferences.garageSensor == "Yes" then
            print("garageSensorAxis >>>>",axis_index)
            -- if this is the Axis-index selected ein preferences and we're using as a garage door, send contact events
            if math.abs(value.value) > 900 then
                device:emit_event(capabilities.contactSensor.contact.closed())
            elseif math.abs(value.value) < 100 then
                device:emit_event(capabilities.contactSensor.contact.open())
            end
        end
    end
end

function common.acceleration_handler(driver, device, value, zb_rx)
    device:emit_event(capabilities.accelerationSensor.acceleration(value.value == 1 and "active" or "inactive"))
end

function common.get_cluster_configurations(manufacturer)
    print("<<< Configure three axis >>>")
    return {
        [capabilities.accelerationSensor.ID] = {
            {
                cluster = common.MFG_CLUSTER,
                attribute = common.ACCELERATION_ATTR_ID,
                minimum_interval = 0,
                maximum_interval = 3600,
                reportable_change = 1,
                data_type = data_types.Bitmap8,
                mfg_code = common.MFG_CODES[manufacturer]
            }
        },
        [capabilities.threeAxis.ID] = {
            {
                cluster = common.MFG_CLUSTER,
                attribute = common.X_AXIS_ATTR_ID,
                minimum_interval = 0,
                maximum_interval = 3600,
                reportable_change = 0x0001,
                data_type = data_types.Int16,
                mfg_code = common.MFG_CODES[manufacturer]
            },
            {
                cluster = common.MFG_CLUSTER,
                attribute = common.Y_AXIS_ATTR_ID,
                minimum_interval = 0,
                maximum_interval = 3600,
                reportable_change = 0x0001,
                data_type = data_types.Int16,
                mfg_code = common.MFG_CODES[manufacturer]
            },
            {
                cluster = common.MFG_CLUSTER,
                attribute = common.Z_AXIS_ATTR_ID,
                minimum_interval = 0,
                maximum_interval = 3600,
                reportable_change = 0x0001,
                data_type = data_types.Int16,
                mfg_code = common.MFG_CODES[manufacturer]
            }
        }
    }
end

return common