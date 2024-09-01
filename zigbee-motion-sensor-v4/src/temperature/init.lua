local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"

--module emit signal metrics
local signal = require "signal-metrics"

local can_handle = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    local subdriver = require("temperature")
    if device:get_manufacturer() == "Samjin" then
      return true, subdriver
    elseif device:get_manufacturer() == "HiveHome.com" then
      return true, subdriver
    elseif device:get_manufacturer() == "SmartThings" then
      return true, subdriver
    elseif device:get_manufacturer() == "CentraLite" then
      return true, subdriver
    elseif device:get_manufacturer() == "Bosch" then
      return true, subdriver
    elseif device:get_manufacturer() == "frient A/S" and device:get_model() == "MOSZB-140" then
      return true, subdriver
    elseif device:get_manufacturer() == "iMagic by GreatStar" and device:get_model() == "1117-S" then
      return true, subdriver
    elseif device:get_manufacturer() == "Universal Electronics Inc" then
      return true, subdriver
    elseif device:get_manufacturer() == "Visonic" then
      return true, subdriver
    elseif device:get_manufacturer() == "NAMRON AS" then
      return true, subdriver
    elseif device:get_manufacturer() == "Sunricher" and device:get_model() == "HK-SENSOR-4IN1-A" then
      return true, subdriver
    elseif device:get_manufacturer() == "Develco Products A/S" and (device:get_model() == "MOSZB-140" or device:get_model() == "MOSZB-130") then
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
    can_handle = can_handle
  }
  
  return temp_sensor