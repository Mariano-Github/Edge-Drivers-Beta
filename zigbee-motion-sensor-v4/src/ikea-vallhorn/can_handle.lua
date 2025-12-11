
-- Licensed under the Apache License, Version 2.0



local ZIGBEE_IKEA_VALLHORN_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "IKEA of Sweden", model = "VALLHORN Wireless Motion Sensor" },
}

return function(opts, driver, device, ...)

   if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(ZIGBEE_IKEA_VALLHORN_MOTION_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("ikea-vallhorn")
          return true, subdriver
        end
    end
  end
  return false
end