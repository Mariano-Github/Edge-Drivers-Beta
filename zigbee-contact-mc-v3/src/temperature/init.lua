local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"
--local capabilities = require "st.capabilities"
--module emit signal metrics
local signal = require "signal-metrics"

local can_handle = function(opts, driver, device)
  if device:get_manufacturer() == "ORVIBO" then
    return device:get_manufacturer() == "ORVIBO"
  elseif device:get_manufacturer() == "Aurora" then
    return device:get_manufacturer() == "Aurora"
  elseif device:get_manufacturer() == "HEIMAN" then
    return device:get_manufacturer() == "HEIMAN"
  elseif device:get_manufacturer() == "Visonic" then
    return device:get_manufacturer() == "Visonic"
  elseif device:get_manufacturer() == "TUYATEC-xnoof3ts" then
    return device:get_manufacturer() == "TUYATEC-xnoof3ts"
  elseif device:get_manufacturer() == "Universal Electronics Inc" then
    return device:get_manufacturer() == "Universal Electronics Inc"
  elseif device:get_manufacturer() == "Sercomm Corp." then
    return device:get_manufacturer() == "Sercomm Corp."
  elseif device:get_manufacturer() == "Ecolink" then
    return device:get_manufacturer() == "Ecolink"
  elseif device:get_manufacturer() == "Samjin" then
    return device:get_manufacturer() == "Samjin"
  elseif device:get_manufacturer() == "SmartThings" then
    return device:get_manufacturer() == "SmartThings"
  elseif device:get_manufacturer() == "CentraLite" then
    return device:get_manufacturer() == "CentraLite"
  elseif device:get_manufacturer() == "Leedarson" then
    return device:get_manufacturer() == "Leedarson"
  end
end

local function do_configure(self,device)
  print ("subdriver do_configure")
  local maxTime = device.preferences.maxTime * 60
  local changeRep = device.preferences.changeRep
  print ("maxTime:", maxTime, "changeRep:", changeRep)
    device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
  device:configure()
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
  
  return temp_sensor