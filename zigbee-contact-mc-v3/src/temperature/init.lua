local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"

--module emit signal metrics
local signal = require "signal-metrics"

local can_handle = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    local subdriver = require("temperature")
    if device:get_manufacturer() == "ORVIBO" then
      return true, subdriver
    elseif device:get_manufacturer() == "Aurora" then
      return true == "Aurora", subdriver
    elseif device:get_manufacturer() == "HEIMAN" then
      return true == "HEIMAN", subdriver
    elseif device:get_manufacturer() == "Visonic" then
      return true, subdriver
    elseif device:get_manufacturer() == "TUYATEC-xnoof3ts" then
      return true, subdriver
    elseif device:get_manufacturer() == "Universal Electronics Inc" then
      return true, subdriver
    elseif device:get_manufacturer() == "Sercomm Corp." and device:get_model() ~= "Tripper" then
      return true, subdriver
    elseif device:get_manufacturer() == "Ecolink" then
      return true, subdriver
    elseif device:get_manufacturer() == "Samjin" then
      return true, subdriver
    elseif device:get_manufacturer() == "SmartThings" and device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU" then
      return true, subdriver
    elseif device:get_manufacturer() == "CentraLite" then
      return true, subdriver
    elseif device:get_manufacturer() == "Leedarson" then
      return true, subdriver
    end
    subdriver = nil
  end
  return false
end

---- Temperature mesure handler
local function temp_attr_handler(self, device, tempvalue, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)

  tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)
end

local temp_sensor = {
    NAME = "Temp-Sensor",
    lifecycle_handlers = {
    },
    zigbee_handlers = {
      attr = {
        [tempMeasurement.ID] = {
            [tempMeasurement.attributes.MeasuredValue.ID] = temp_attr_handler
        }
      }
    },
    can_handle = can_handle
  }
  
  return temp_sensor