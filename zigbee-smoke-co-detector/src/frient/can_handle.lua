
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    if device:get_manufacturer() == "frient A/S" or device:get_manufacturer() == "LUMI" or device:get_manufacturer() == "Develco Products A/S" then
      local subdriver = require("frient")
      return true, subdriver
    end
  end
  return false
end