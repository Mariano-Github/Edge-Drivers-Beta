
-- Licensed under the Apache License, Version 2.0

local VIMAR_THERMOSTAT_FINGERPRINT = {
    { mfr = "Vimar", model = "WheelThermostat_v1.0" },
    { mfr = "Vimar", model = "Thermostat_v1.0" },

}

return function(opts, driver, device, ...)
    for _, fingerprint in ipairs(VIMAR_THERMOSTAT_FINGERPRINT) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("vimar")
          return true, subdriver
        end
    end
    return false
end