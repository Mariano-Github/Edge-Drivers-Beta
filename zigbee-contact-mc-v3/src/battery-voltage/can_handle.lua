
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)

     if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    local subdriver = require("battery-voltage")
    if device:get_manufacturer() == "Ecolink" then
      return true, subdriver
    elseif device:get_manufacturer() == "frient A/S" then
      return true, subdriver
    elseif device:get_manufacturer() == "Sercomm Corp." then
      return true, subdriver
    elseif device:get_manufacturer() == "Universal Electronics Inc" then
      return true, subdriver
    elseif device:get_manufacturer() == "SmartThings" and device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU" then
      return true, subdriver
    elseif device:get_manufacturer() == "CentraLite" then
      return true, subdriver
    elseif device:get_manufacturer() == "Visonic" then
      return true, subdriver
    elseif device:get_manufacturer() == "Leedarson" then
      return true, subdriver
    elseif (device:get_manufacturer() == "LUMI" and device:get_model() ~= "lumi.sensor_magnet.aq2") then
      return true, subdriver
    elseif device:get_manufacturer() == "IKEA of Sweden" then
      return true, subdriver
    end
    subdriver = nil
  end
  return false
end