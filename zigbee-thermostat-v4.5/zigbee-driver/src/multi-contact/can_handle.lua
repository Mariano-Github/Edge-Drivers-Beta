
-- Licensed under the Apache License, Version 2.0

return function(opts, driver, device, ...)
    local subdriver = require("multi-contact")
    if device:get_manufacturer() == "SmartThings" and device:get_model()== "multiv4" then
      return true, subdriver
    elseif device:get_manufacturer() == "Samjin" and device:get_model()== "multi" then
        return true, subdriver
    elseif device:get_manufacturer() == "CentraLite" and device:get_model() == "3321-S" then
        return true, subdriver
    end
    subdriver = nil
    return false
end