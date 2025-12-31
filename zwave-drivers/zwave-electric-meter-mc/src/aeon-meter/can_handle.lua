
-- Licensed under the Apache License, Version 2.0

local AEON_FINGERPRINTS = {
  {mfr = 0x0086, prod = 0x0002, model = 0x0009},  -- DSB09xxx-ZWUS
  {mfr = 0x0086, prod = 0x0002, model = 0x0001},  -- DSB28-ZWEU
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(AEON_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("aeon-meter")
      return true, subdriver
    end
  end
  return false
end