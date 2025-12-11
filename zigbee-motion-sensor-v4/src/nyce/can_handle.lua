
-- Licensed under the Apache License, Version 2.0


local ZIGBEE_NYCE_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "NYCE", model = "3041" },
  { mfr = "NYCE", model = "3043" },
  { mfr = "NYCE", model = "3045" }
}

return function(opts, driver, device, ...)

    if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(ZIGBEE_NYCE_MOTION_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("nyce")
          return true, subdriver
        end
    end
  end
  return false
end
