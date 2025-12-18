
-- Licensed under the Apache License, Version 2.0

local POPP_DANFOSS_THERMOSTAT_FINGERPRINTS = {
  --{ mfr = "D5X84YU", model = "eT093WRO" },
  --{ mfr = "D5X84YU", model = "eT093WRG" },
  { mfr = "Danfoss", model = "eTRV0100" },
  { mfr = "Danfoss", model = "eTRV0103" }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(POPP_DANFOSS_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("popp_danfoss")
      return true, subdriver
    end
  end
  return false
end