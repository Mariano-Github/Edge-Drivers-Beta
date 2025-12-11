
-- Licensed under the Apache License, Version 2.0


local AQARA_FP1_SENSOR_FINGERPRINTS = {
  { mfr = "aqara", model = "lumi.sensor_occupy.agl1" },
}

return function(opts, driver, device, ...)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(AQARA_FP1_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("aqara-fp1e")
          return true, subdriver
        end
    end
  end
  return false
end