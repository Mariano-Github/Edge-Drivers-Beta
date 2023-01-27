local zcl_clusters = require "st.zigbee.zcl.clusters"
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"
local capabilities = require "st.capabilities"

--module emit signal metrics
local signal = require "signal-metrics"

local can_handle = function(opts, driver, device)
  if device:get_manufacturer() == "Samjin" then
    return device:get_manufacturer() == "Samjin"
  elseif device:get_manufacturer() == "HiveHome.com" then
    return device:get_manufacturer() == "HiveHome.com"
  elseif device:get_manufacturer() == "SmartThings" then
    return device:get_manufacturer() == "SmartThings"
  elseif device:get_manufacturer() == "CentraLite" then
    return device:get_manufacturer() == "CentraLite"  
  elseif device:get_manufacturer() == "Bosch" then
    return device:get_manufacturer() == "Bosch"
  elseif device:get_manufacturer() == "frient A/S" and device:get_model() == "MOSZB-140" then
    return device:get_manufacturer() == "frient A/S"
  elseif device:get_manufacturer() == "iMagic by GreatStar" and device:get_model() == "1117-S" then
    return device:get_manufacturer() == "iMagic by GreatStar"
  elseif device:get_manufacturer() == "Universal Electronics Inc" then
    return device:get_manufacturer() == "Universal Electronics Inc"
  elseif device:get_manufacturer() == "Visonic" then
    return device:get_manufacturer() == "Visonic"
  end
end

local function do_configure(self,device)
  print ("subdriver do_configure")
  local maxTime = device.preferences.maxTime * 60
  local changeRep = device.preferences.changeRep
  print ("maxTime y changeRep: ",maxTime, changeRep )
    device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))
  device:configure()
  if device:get_manufacturer() == "frient A/S" or 
      device:get_manufacturer() == "SmartThings" or
      device:get_manufacturer() == "Bosch" or
      device:get_manufacturer() == "CentraLite" or
      device:get_manufacturer() == "Universal Electronics Inc" or
      device:get_manufacturer() == "Visonic" or
      (device:get_manufacturer() == "iMagic by GreatStar" and device:get_model() == "1117-S") then

        device:send(device_management.build_bind_request(device, zcl_clusters.PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
        device:send(zcl_clusters.PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 30, 21600, 1))
  end
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
      doConfigure = do_configure,
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