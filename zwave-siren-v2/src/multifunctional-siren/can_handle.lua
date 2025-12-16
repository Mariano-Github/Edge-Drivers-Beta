
-- Licensed under the Apache License, Version 2.0

local MULTIFUNCTIONAL_SIREN_FINGERPRINTS = {
  { manufacturerId = 0x027A, productType = 0x000C, productId = 0x0003 }, -- Zooz S2 Multisiren ZSE19
  { manufacturerId = 0x0060, productType = 0x000C, productId = 0x0003 }, -- Everspring Indoor Voice Siren
  { manufacturerId = 0x0403, productType = 0x0003, productId = 0x0000 },  -- Abus siren
  { manufacturerId = 0x0206, productType = 0x8009, productId = 0x1000 },  -- Heiman HEIEHS2W siren
  { manufacturerId = 0x044A, productType = 0x0004, productId = 0x0002 }  -- Boundary Siren
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(MULTIFUNCTIONAL_SIREN_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("multifunctional-siren")
      return true, subdriver
    end
  end
  return false
end