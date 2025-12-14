
-- Licensed under the Apache License, Version 2.0

local TUYA_METER_FINGERPRINTS = {
    { mfr = "_TZE204_ac0fhfiq", model = "TS0601" }
}

return function(opts, driver, device, ...)
    for _, fingerprint in ipairs(TUYA_METER_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("tuya-meter")
          return true, subdriver
        end
    end
    return false
end
