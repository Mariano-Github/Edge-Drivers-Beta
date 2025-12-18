
-- Licensed under the Apache License, Version 2.0

local SONOFF_THERMOSTAT_FINGERPRINTS = {
  { mfr = "SONOFF", model = "TRVZB" }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(SONOFF_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("sonoff")
      return true, subdriver
    end
  end
  return false
end