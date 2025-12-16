
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
  if device:get_manufacturer() == "Samjin" and device:get_model() == "button" then
      local subdriver = require("button")
      return true, subdriver
    end
    return false
end