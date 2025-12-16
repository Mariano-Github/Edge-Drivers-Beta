
-- Licensed under the Apache License, Version 2.0

local COOLCAM_DOORBELL_SIREN_FINGERPRINTS = {
  { manufacturerId = 0x0258, productType = 0x0003, productId = 0x0088}, -- Neo Coolcam  (us)
  { manufacturerId = 0x0258, productType = 0x0003, productId = 0x1088}, -- Neo Coolcam (eu)
  { manufacturerId = 0x0258, productType = 0x0003, productId = 0x6088}, -- Neo Coolcam (eu)
  { manufacturerId = 0x017F, productType = 0x0200, productId = 0x0001}, -- Wink (es)
  { manufacturerId = 0x0258, productType = 0x0600, productId = 0x1028}, -- Neo Coolcam
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(COOLCAM_DOORBELL_SIREN_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("coolcam-siren")
      return true, subdriver
    end
  end
  return false
end