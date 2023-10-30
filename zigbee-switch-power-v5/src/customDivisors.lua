------- Set Cuatom Divisor Module----
local constants = require "st.zigbee.constants"

local customDivisors ={}

 --- save optionals device divisors
 function customDivisors.set_custom_divisors(self, device)
  print("<<< Custom divisor handler >>>")

  if device.preferences.simpleMeteringDivisor1 == 0 or device.preferences.simpleMeteringDivisor1 == nil then -- use default divisor for energy
    local energy_divisor = device:get_field(constants.SIMPLE_METERING_DIVISOR_KEY)
    if device:get_manufacturer() == "sengled" then
      --energy_divisor = 10
    elseif device:get_model() == "TS011F" then
      if (device:get_manufacturer() == "_TZ3000_gjnozsaz" or
        device:get_manufacturer() == "_TZ3000_gvn91tmx" or
        device:get_manufacturer() == "_TZ3000_qeuvnohg" or
        device:get_manufacturer() == "_TZ3000_amdymr71" or
        device:get_manufacturer() == "_TZ3000_typdpbpg" or
        device:get_manufacturer() == "_TZ3000_ynmowqk2" or
        device:get_manufacturer() == "_TZ3000_2putqrmw" or
        device:get_manufacturer() == "_TZ3000_w0qqde0g" or
        device:get_manufacturer() == "_TZ3000_cphmq0q7") then
          energy_divisor = 100
      elseif device:get_manufacturer() == "_TZ3000_zloso4jk" then
        energy_divisor = 1000
      end
    elseif device:get_model() == "lumi.switch.n0agl1" then
      energy_divisor = 1000
    end
    device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, energy_divisor, {persist = true})
  else
    device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, device.preferences.simpleMeteringDivisor1, {persist = true})
  end

  if device.preferences.electricalMeasureDiviso1 == 0 or device.preferences.electricalMeasureDiviso1 == nil then --use default divisor for Active Power
    local power_divisor = device:get_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY)
    if device:get_manufacturer() == "sengled" then
      --power_divisor = 10000
    elseif device:get_manufacturer() == "Third Reality, Inc" and device:get_model() == "3RSP02028BZ" then
      power_divisor = 10
    elseif device:get_model() == "lumi.switch.n0agl1" then
      power_divisor = 1000
    end
    device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, power_divisor, {persist = true})
  else
    device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, device.preferences.electricalMeasureDiviso1, {persist = true})
  end
  if device.preferences.logDebugPrint == true then
    print("SIMPLE_METERING_DIVISOR_KEY >>>>", device:get_field(constants.SIMPLE_METERING_DIVISOR_KEY))
    print("ELECTRICAL_MEASUREMENT_DIVISOR_KEY >>>>>", device:get_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY))
  end
end

return customDivisors