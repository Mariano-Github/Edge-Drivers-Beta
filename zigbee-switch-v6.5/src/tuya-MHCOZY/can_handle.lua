
-- Licensed under the Apache License, Version 2.0

local TUYA_MHCOZY_FINGERPRINTS = {
    { mfr = "_TZ3218_7fiyo3kv", model = "TS000F" },
}

return function(opts, driver, device, ...)
    for _, fingerprint in ipairs(TUYA_MHCOZY_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("tuya-MHCOZY")
          return true, subdriver
        end
    end
    return false
end