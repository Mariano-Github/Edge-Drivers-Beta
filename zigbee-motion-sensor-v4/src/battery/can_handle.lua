
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)
 if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    local subdriver = require("battery")
    if device:get_manufacturer() == "SmartThings" then
      return true, subdriver
    elseif device:get_manufacturer() == "CentraLite" then
      return true, subdriver
    elseif device:get_manufacturer() == "Bosch" then
      return true, subdriver
    elseif device:get_manufacturer() == "frient A/S" then
      return true, subdriver
    elseif device:get_manufacturer() == "Konke" then
      return true, subdriver
    elseif device:get_manufacturer() == "iMagic by GreatStar" and device:get_model() == "1117-S" then
      return true, subdriver
    elseif device:get_manufacturer() == "NYCE" then
      return true, subdriver
    elseif device:get_manufacturer() == "IKEA of Sweden" and device:get_model() == "TRADFRI motion sensor" then
      return true, subdriver
    elseif device:get_manufacturer() == "Universal Electronics Inc" then
      return true, subdriver
    elseif device:get_manufacturer() == "Visonic" then
      return device:get_manufacturer() == "Visonic", subdriver
    elseif device:get_manufacturer() == "TLC" then
      return true, subdriver
    elseif device:get_manufacturer() == "Develco Products A/S" then
      return true, subdriver
    elseif device:get_manufacturer() == "LUMI" then
      return true, subdriver
    end
    subdriver = nil
  end
  return false
end