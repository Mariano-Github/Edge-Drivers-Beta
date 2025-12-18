
-- Licensed under the Apache License, Version 2.0

local EUROTRONIC_THERMOSTAT_FINGERPRINTS = {
  { mfr = "Eurotronic", model = "SPZB0001" }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(EUROTRONIC_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("eurotronic")
      return true, subdriver
    end
  end
  return false
end