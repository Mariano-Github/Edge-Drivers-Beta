
-- Licensed under the Apache License, Version 2.0

local AEOTEC_DOORBELL_SIREN_FINGERPRINTS = {
  { manufacturerId = 0x0371, productType = 0x0003, productId = 0x00A2}, -- Aeotec Doorbell 6 (EU)
  { manufacturerId = 0x0371, productType = 0x0103, productId = 0x00A2}, -- Aeotec Doorbell 6 (US)
  { manufacturerId = 0x0371, productType = 0x0203, productId = 0x00A2}, -- Aeotec Doorbell 6 (AU)
  { manufacturerId = 0x0371, productType = 0x0003, productId = 0x00A4}, -- Aeotec Siren 6 (EU)
  { manufacturerId = 0x0371, productType = 0x0103, productId = 0x00A4}, -- Aeotec Siren 6 (US)
  { manufacturerId = 0x0371, productType = 0x0203, productId = 0x00A4}, -- Aeotec Siren 6 (AU)
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(AEOTEC_DOORBELL_SIREN_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("aeotec-doorbell-siren")
      return true, subdriver
    end
  end
  return false
end