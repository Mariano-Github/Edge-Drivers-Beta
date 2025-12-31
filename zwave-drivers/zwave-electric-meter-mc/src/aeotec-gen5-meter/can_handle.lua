
-- Licensed under the Apache License, Version 2.0

local AEOTEC_GEN5_FINGERPRINTS = {
  {mfr = 0x0086, prod = 0x0102, model = 0x005F},  -- Aeotec Home Energy Meter (Gen5) US
  {mfr = 0x0086, prod = 0x0002, model = 0x005F},  -- Aeotec Home Energy Meter (Gen5) EU
  --{mfr = 0x0086, prod = 0x0002, model = 0x001C},  -- Aeotec Home Energy Meter (Gen2) EU
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(AEOTEC_GEN5_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("aeotec-gen5-meter")
      return true, subdriver
    end
  end
  return false
end