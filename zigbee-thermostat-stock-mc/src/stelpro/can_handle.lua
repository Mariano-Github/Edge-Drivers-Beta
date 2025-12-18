
-- Licensed under the Apache License, Version 2.0

local STELPRO_THERMOSTAT_FINGERPRINTS = {
  { mfr = "Stelpro", model = "MaestroStat" },
  { mfr = "Stelpro", model = "SORB" },
  { mfr = "Stelpro", model = "SonomaStyle" },
  { mfr = "Stelpro", model = "SMT402AD" }, -- added M.Colmenarejo
  { mfr = "Stelpro", model = "SMT402AD01" }, -- added M.Colmenarejo
  { mfr = "Stelpro", model = "" } -- added M.Colmenarejo "SMT402AD01" is nil in fingerprints
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(STELPRO_THERMOSTAT_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
        local subdriver = require("stelpro")
        return true, subdriver
      end
  end
  return false
end