
-- Licensed under the Apache License, Version 2.0

local QUBINO_FINGERPRINTS = {
  {mfr = 0x0159, prod = 0x0007, model = 0x0054},  -- Qubino 3 Phase Meter
  {mfr = 0x0159, prod = 0x0007, model = 0x0052}   -- Qubino Smart Meter
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(QUBINO_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("qubino-meter")
      return true, subdriver
    end
  end
  return false
end