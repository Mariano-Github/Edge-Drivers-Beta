local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local battery = capabilities.battery
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local utils = require "st.utils"

local can_handle = function(opts, driver, device)
 if device:get_manufacturer() == "SmartThings" then
    return device:get_manufacturer() == "SmartThings"
 elseif device:get_manufacturer() == "Samjin" then
    return device:get_manufacturer() == "Samjin"
 elseif device:get_manufacturer() == "CentraLite" then
    return device:get_manufacturer() == "CentraLite"
 elseif device:get_manufacturer() == "Bosch" then
    return device:get_manufacturer() == "Bosch"
  elseif device:get_manufacturer() == "frient A/S" then
    return device:get_manufacturer() == "frient A/S"
 end
end

local battery_handler = function(driver, device, value, zb_rx)
  if device:get_manufacturer() == "SmartThings" then   
    local batteryMap = {[28] = 100, [27] = 100, [26] = 100, [25] = 90, [24] = 90, [23] = 70,
                      [22] = 70, [21] = 50, [20] = 50, [19] = 30, [18] = 30, [17] = 15, [16] = 1, [15] = 0}
    local minVolts = 15
    local maxVolts = 28

    value = utils.clamp_value(value.value, minVolts, maxVolts)

    device:emit_event(battery.battery(batteryMap[value]))
  else
    local minVolts = 2.3
    local maxVolts = 3.0
    if device:get_manufacturer() == "Bosch" then
      if device:get_model() == "ISW-ZPR1-WP13" then
        minVolts = 1.5
        maxVolts = 3.0
      else
        minVolts = 2.1
        maxVolts = 3.0
      end
    end

    local battery_pct = math.floor(((((value.value / 10) - minVolts) + 0.001) / (maxVolts - minVolts)) * 100)
    if battery_pct > 100 then 
      battery_pct = 100
     elseif battery_pct < 0 then
      battery_pct = 0
     end
    device:emit_event(battery.battery(battery_pct))
  end
end

-- samjin_battery_percentage_handler
local function samjin_battery_percentage_handler(driver, device, raw_value, zb_rx)
  if device:get_manufacturer() == "Samjin" then
    local raw_percentage = raw_value.value - (200 - raw_value.value) / 2
    print("raw_percentage >>>>",raw_percentage)
    local percentage = utils.clamp_value(utils.round(raw_percentage / 2), 0, 100)
    device:emit_event(capabilities.battery.battery(percentage))
  end
end

---- device init
local function do_init(self, device)
  if device:get_manufacturer() ~= "Samjin" then
    battery_defaults.build_linear_voltage_init(2.3, 3.0)
  end
end

local smartthings_multi_sensor = {
	NAME = "SmartThings multi sensor",
    zigbee_handlers = {
        attr = {
            [zcl_clusters.PowerConfiguration.ID] = {
              [zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.ID] = battery_handler
            },
            [zcl_clusters.PowerConfiguration.ID] = {
              [zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = samjin_battery_percentage_handler
            }
          }
    },
    lifecycle_handlers = {
        --init = battery_defaults.build_linear_voltage_init(2.3, 3.0)
        init = do_init
    },
	can_handle = can_handle
}

return smartthings_multi_sensor
