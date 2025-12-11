
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE

      if device:get_manufacturer() == "Aurora" and device:get_model() == "MotionSensor51AU" then
        local subdriver = require("aurora")
        return true, subdriver
      end
    end
    return false
  end