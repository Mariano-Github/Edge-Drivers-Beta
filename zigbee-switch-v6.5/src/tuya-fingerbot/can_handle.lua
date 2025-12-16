
-- Licensed under the Apache License, Version 2.0

local TUYA_FINGERBOT_FINGERPRINTS = {
    { mfr = "_TZ3210_dse8ogfy", model = "TS0001" },
    { mfr = "_TZ3210_j4pdtz9v", model = "TS0001" },
    { mfr = "_TZ3210_cm9mbpr1", model = "TS0001" }
}

return function(opts, driver, device, ...)
    for _, fingerprint in ipairs(TUYA_FINGERBOT_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("tuya-fingerbot")
          return true, subdriver
        end
    end
    return false
end