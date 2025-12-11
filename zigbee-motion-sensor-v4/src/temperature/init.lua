local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"

--module emit signal metrics
local signal = require "signal-metrics"

---- Temperature mesure handler
local function temp_attr_handler(self, device, tempvalue, zb_rx)
    -- emit signal metrics
    signal.metrics(device, zb_rx)
    tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)
end

local temp_sensor = {
    NAME = "MultiSensor",
    lifecycle_handlers = {
    },
    zigbee_handlers = {
      attr = {
        [tempMeasurement.ID] = {
            [tempMeasurement.attributes.MeasuredValue.ID] = temp_attr_handler
        }
      }
    },
    can_handle = require("temperature.can_handle")
  }
  
  return temp_sensor