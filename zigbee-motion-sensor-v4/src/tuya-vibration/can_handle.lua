
-- Licensed under the Apache License, Version 2.0


local TUYA_VIBRATION_SENSOR_FINGERPRINTS = {
    { mfr = "_TZE200_iba1ckek", model = "TS0601" },
    { mfr = "_TZE200_jfw0a4aa", model = "TS0601" },
}

return function(opts, driver, device, ...)

   if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(TUYA_VIBRATION_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("tuya-vibration")
          return true, subdriver
        end
    end
  end
    return false
end