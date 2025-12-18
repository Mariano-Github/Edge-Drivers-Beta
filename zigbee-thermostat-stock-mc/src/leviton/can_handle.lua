
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
    if device:get_manufacturer() == "HAI" and device:get_model() == "65A01-1" then
      local subdriver = require("leviton")
      return true, subdriver
    end
    return false
  end