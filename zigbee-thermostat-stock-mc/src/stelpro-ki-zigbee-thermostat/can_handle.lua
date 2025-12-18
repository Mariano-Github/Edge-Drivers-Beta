
-- Licensed under the Apache License, Version 2.0

local STELPRO_KI_ZIGBEE_THERMOSTAT_FINGERPRINTS = {
  { mfr = "Stelpro", model = "STZB402+" },
  { mfr = "Stelpro", model = "ST218" },
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(STELPRO_KI_ZIGBEE_THERMOSTAT_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
        local subdriver = require("stelpro-ki-zigbee-thermostat")     
        return true, subdriver
      end
  end
  return false
end