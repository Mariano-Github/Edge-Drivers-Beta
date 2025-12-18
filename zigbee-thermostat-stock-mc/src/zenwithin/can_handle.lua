
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
    if device:get_manufacturer() == "Zen Within" and device:get_model() == "Zen-01" then
      local subdriver = require("zenwithin")
      return true, subdriver
    end
    return false
  end