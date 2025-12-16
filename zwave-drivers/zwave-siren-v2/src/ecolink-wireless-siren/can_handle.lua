
-- Licensed under the Apache License, Version 2.0

local ECOLINK_WIRELESS_SIREN_FINGERPRINTS = {
  { manufacturerId = 0x014A, productType = 0x0005, productId = 0x000A }, -- Ecolink Siren
}

return function(opts, driver, device, ...)
  for _, fingerprint in ipairs(ECOLINK_WIRELESS_SIREN_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturerId, fingerprint.productType, fingerprint.productId) then
      local subdriver = require("ecolink-wireless-siren")
      return true, subdriver
    end
  end
  return false
end