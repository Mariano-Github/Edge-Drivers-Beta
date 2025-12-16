
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
  --if device.manufacturer ~= nil then return false end
    if device:get_manufacturer() == "_TZ2000_a476raq2" or
      (device:get_manufacturer() == "LUMI" and device:get_model() == "lumi.sensor_ht.agl02") then
      --(device:get_manufacturer() == "SONOFF" and device:get_model() == "SNZB-02D") then
      local subdriver = require("battery")
      return true, subdriver
    end
  end
  return false
end