
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
if device:get_manufacturer() == "Fidure" and device:get_model() == "A1732R3" then
      local subdriver = require("fidure")
      return true, subdriver
    end
    return false
  end