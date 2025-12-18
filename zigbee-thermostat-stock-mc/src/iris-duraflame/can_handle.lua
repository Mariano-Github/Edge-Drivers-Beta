
-- Licensed under the Apache License, Version 2.0

local IRIS_THERMOSTAT_FINGERPRINTS = {
  { mfr = "Twin-Star International", model = "20QI071ARA" }
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(IRIS_THERMOSTAT_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      local subdriver = require("iris-duraflame")
      return true, subdriver
    end
  end
  return false
end