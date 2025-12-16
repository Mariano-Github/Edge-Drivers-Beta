
-- Licensed under the Apache License, Version 2.0

local AEON_MFR = 0x0086
local AEON_SIREN_PRODUCT_ID = 0x0050

return function(opts, driver, device, ...)
  if device.zwave_manufacturer_id == AEON_MFR and device.zwave_product_id == AEON_SIREN_PRODUCT_ID then
    local subdriver = require("aeon-siren")
    return true, subdriver
  end
end