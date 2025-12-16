
-- Licensed under the Apache License, Version 2.0

local UTILITECH_MFR = 0x0060
local UTILITECH_SIREN_PRODUCT_ID = 0x0001

return function(opts, driver, device, ...)
  if device.zwave_manufacturer_id == UTILITECH_MFR and device.zwave_product_id == UTILITECH_SIREN_PRODUCT_ID then
    local subdriver = require("utilitech-siren")
    return true, subdriver
  end
end