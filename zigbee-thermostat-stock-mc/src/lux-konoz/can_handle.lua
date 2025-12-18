
-- Licensed under the Apache License, Version 2.0

local LUX_KONOZ_THERMOSTAT_FINGERPRINTS = {
  { mfr = "LUX", model = "KONOZ" }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(LUX_KONOZ_THERMOSTAT_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
        local subdriver = require("lux-konoz")
        return true, subdriver
      end
  end
  return false
end