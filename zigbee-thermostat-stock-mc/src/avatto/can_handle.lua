
-- Licensed under the Apache License, Version 2.0

local AVATTO_THERMOSTAT_FINGERPRINTS = {
  { mfr = "_TZE204_xnbkhhdr", model = "TS0601" }, --ZWT198 battery
  { mfr = "_TZE204_lzriup1j", model = "TS0601" },
  { mfr = "_TZE200_viy9ihs7", model = "TS0601" }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(AVATTO_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("avatto")
      return true, subdriver
    end
  end
  return false
end