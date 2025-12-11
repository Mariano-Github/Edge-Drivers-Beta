
-- Licensed under the Apache License, Version 2.0


return function(opts, driver, device, ...)

   if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
        local subdriver = require("multi-contact")
        if device:get_manufacturer() == "SmartThings" and device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU" then
        return true, subdriver
        elseif device:get_manufacturer() == "Samjin" then
            return true, subdriver
        elseif device:get_manufacturer() == "CentraLite" and device:get_model() == "3321-S" then
            return true, subdriver
        end
        subdriver = nil
    end
    return false
end