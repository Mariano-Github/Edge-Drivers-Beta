
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)

   if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    if device:get_manufacturer() == "LUMI" and 
    (device:get_model() == "lumi.sensor_magnet.aq2" or device:get_model() == "lumi.sensor_magnet") then
      local subdriver = require("lumi-switch-cluster")
      return true, subdriver
    end
  end
  return false
end