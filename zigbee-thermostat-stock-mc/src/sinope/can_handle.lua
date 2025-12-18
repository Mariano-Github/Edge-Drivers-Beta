
-- Licensed under the Apache License, Version 2.0

local SINOPE_TECHNOLOGIES_MFR_STRING = "Sinope Technologies"

return function(opts, driver, device, ...)
  if device:get_manufacturer() == SINOPE_TECHNOLOGIES_MFR_STRING then
    local subdriver = require("sinope")
    return true, subdriver
  else
    return false
  end
end