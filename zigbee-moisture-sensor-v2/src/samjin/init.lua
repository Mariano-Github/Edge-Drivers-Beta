local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"
--module emit signal metrics
local signal = require "signal-metrics"

local can_handle = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    local subdriver = require("samjin")
    if device:get_manufacturer() == "Samjin" then
      return true, subdriver
    elseif device:get_manufacturer() == "Nortek Security and Control" then
      return true, subdriver
    elseif device:get_manufacturer() == "CentraLite" then
      return true, subdriver
    elseif device:get_manufacturer() == "LUMI" then
      return true, subdriver
    elseif device:get_manufacturer() == "SmartThings" then
      return true, subdriver
    end
    subdriver = nil
  end
  return false
end

local function do_configure(self,device)
  print ("subdriver do_configure")
  local maxTime = device.preferences.maxTime * 60
  local changeRep = device.preferences.changeRep * 100
  print ("maxTime y changeRep: ",maxTime, changeRep )
    device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
    device:configure()
end

local function temp_attr_handler(self, device, tempvalue, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)
  
  tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)
end

local samjin_sensor = {
    NAME = "MultiSensor",
    lifecycle_handlers = {
      doConfigure = do_configure
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
  
  return samjin_sensor