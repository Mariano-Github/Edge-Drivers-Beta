local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local battery = capabilities.battery
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local utils = require "st.utils"

-- Notes on this device:
-- Tuya Leak Sensor
-- 
-- Sold as:
-- "Tuya Water Sensor" (TS0207)
-- Blitzwolf BW-IS5 Water Leak Sensor https://www.blitzwolf.com/ZigBee-Water-Leak-Sensor-p-444.html
-- RSH-ZigBee-WS01
-- Ewelink Wireless Water Detector
-- And probably others...
--
-- To pair this device, press and hold the button for 5+ seconds.  
-- While holding, the green light will go out indicating its ready to pair.
-- Release the button, the green light should begin to blink indicating its ready to pair.
--
-- Pressing the button will send the current leak status as a zone status update.
--
-- Every ~250 minutes or so, the device will send a battery report (with voltage and percentage remaining).
-- The frequency of the battery reports is not queryable or configurable.
-- 
-- Details:
-- Leak sensor only.  No temperature or humidity. 
-- Uses a single 2032 battery
-- Does not do long poll checkins at any frequency
--
-- Water events:
--   Registers as an IAS device.    Water events are sent as an IAS zone status update for alarm 1.
--   There are NO supervision updates for IAS Status in both the non faulted (dry) and faulted (wet)
--   states.   If the hub misses the IAS Zone report, no further alerts will be generated.
--
-- Does not support report configurations on any cluster (including IAS Zone, PowerConfiguration, etc).
-- This makes it not a very good water sensor as there is no way to change its reporting frequency.
--


local can_handle = function(opts, driver, device)
  -- If this device supports the "Tuya Cluster"
  return device:supports_server_cluster(0xEF01)
end

-- preferences update
local function do_tuya_init(self, device)
  -- Tuya doesn't support reporting configurations at all, so remove 
  -- the default ones added by:
  --    capabilities.waterSensor
  --       IASZone/ZoneStatus
  --    capabilities.battery
  --       PowerConfiguration/BatteryPercentageRemaining
  device:remove_configured_attribute(zcl_clusters.IASZone.ID, zcl_clusters.IASZone.attributes.ZoneStatus.ID)
  device:remove_monitored_attribute(zcl_clusters.IASZone.ID, zcl_clusters.IASZone.attributes.ZoneStatus.ID)
  device:remove_configured_attribute(zcl_clusters.PowerConfiguration.ID, zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID)
  device:remove_monitored_attribute(zcl_clusters.PowerConfiguration.ID, zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID)
end

local function do_tuya_configure(self, device)
  -- Manually request the status of the supported attributes
  device:send(zcl_clusters.IASZone.attributes.ZoneStatus:read(device))
  device:send(zcl_clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))
  device:send(zcl_clusters.PowerConfiguration.attributes.BatteryVoltage:read(device))
end

-- Customize the battery voltage handler to send voltage events
local battery_voltage_handler = function(driver, device, value, zb_rx)
  -- Emit Battery voltage event
  device:emit_event(capabilities.voltageMeasurement.voltage(value.value / 10))
end

local tuya_leak_sensor = {
	NAME = "Tuya Leak Sensor",
    zigbee_handlers = {
        attr = {
            [zcl_clusters.PowerConfiguration.ID] = {
              [zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.ID] = battery_voltage_handler
            }
        }
    },
    lifecycle_handlers = {
        init = do_tuya_init,
        doConfigure = do_tuya_configure,
    },
	can_handle = can_handle
}

return tuya_leak_sensor
