
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)

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
