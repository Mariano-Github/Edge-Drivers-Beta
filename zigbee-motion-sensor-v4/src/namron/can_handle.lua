
-- Licensed under the Apache License, Version 2.0


local ZIGBEE_NAMRON_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "NAMRON AS", model = "4512770" },
  { mfr = "NAMRON AS", model = "4512771" },
  { mfr = "Sunricher", model = "HK-SENSOR-4IN1-A" },
}

return function(opts, driver, device, ...)

   if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(ZIGBEE_NAMRON_MOTION_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("namron")
          return true, subdriver
        end
    end
  end
  return false
end