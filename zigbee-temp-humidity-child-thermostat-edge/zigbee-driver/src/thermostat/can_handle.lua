
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" and device.preferences.profileType ~= "Batteries" then
    local subdriver = require("thermostat")
    return true, subdriver
  else
    return false
  end
end