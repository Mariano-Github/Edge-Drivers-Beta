-- Copyright 2022 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local zigbee_constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local ElectricalMeasurement = clusters.ElectricalMeasurement
local SimpleMetering = clusters.SimpleMetering
local constants = require "st.zigbee.constants"

local do_configure = function(self, device)
  device:refresh()
  device:configure()

    --[[-- Additional one time configuration
    if device:supports_capability(capabilities.energyMeter) or device:supports_capability(capabilities.powerMeter) then
      -- Divisor and multipler for EnergyMeter
      device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
      device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
      -- Divisor and multipler for PowerMeter
      device:send(SimpleMetering.attributes.Divisor:read(device))
      device:send(SimpleMetering.attributes.Multiplier:read(device))
    end]]

    if device:get_model() == "PCM_00.00.03.09TC" then
      local divisor = 10000
      if  device.preferences.simpleMeteringDivisor ~= nil  then
        divisor = device.preferences.simpleMeteringDivisor
      end
      device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, divisor, {persist = true})
      if device:get_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY) == nil then
        device:set_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, 1000, {persist = true})
      end
    end
end

local device_init = function(self, device)

  -- Additional one time configuration
  if device:supports_capability(capabilities.energyMeter) or device:supports_capability(capabilities.powerMeter) then
    -- Divisor and multipler for EnergyMeter
    device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
    device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
    -- Divisor and multipler for PowerMeter
    device:send(SimpleMetering.attributes.Divisor:read(device))
    device:send(SimpleMetering.attributes.Multiplier:read(device))
  end

  -- We check the keys to see if they're already set so that we don't clobber the values w/ the defaults if they already exist.
  if device:get_model() == "PCM_00.00.03.09TC" then
    local divisor = 10000
    if  device.preferences.simpleMeteringDivisor ~= nil  then
      divisor = device.preferences.simpleMeteringDivisor
    end
    device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, divisor, {persist = true})
    if device:get_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY) == nil then
      device:set_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, 1000, {persist = true})
    end
  else
    if device:get_field(zigbee_constants.SIMPLE_METERING_DIVISOR_KEY) == nil then
      device:set_field(zigbee_constants.SIMPLE_METERING_DIVISOR_KEY, 1000, {persist = true})
    end

    if device:get_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY) == nil then
      device:set_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, 1000, {persist = true})
    end
  end

end

-- preferences update
local function do_preferences(self, device, event, args)
  for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id])
    --local oldPreferenceValue = device:get_field(id)
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      --device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed:", id, "old=",oldPreferenceValue, "new =", newParameterValue)
      if  id == "simpleMeteringDivisor"  then
        device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, newParameterValue, {persist = true})
      elseif id == "electricalMeasureDivisor" then
        device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, newParameterValue, {persist = true})
      elseif id == "intallationType" then
        if newParameterValue == "independetTwoClamp" then
          device:try_update_metadata({profile = "power-meter-energy-solar-dual-2-clamp"})
        elseif newParameterValue == "exportProduct" then
          device:try_update_metadata({profile = "power-meter-energy-solar-dual-exp-prod"})
        elseif newParameterValue == "exportConsumption" then
          device:try_update_metadata({profile = "power-meter-energy-solar-dual-exp-cons"})
        end
      elseif id == "intallationClamp" then
        if newParameterValue == "exportConsumption" then
          device:try_update_metadata({profile = "power-meter-energy-solar"})
        elseif newParameterValue == "production" then
          device:try_update_metadata({profile = "power-meter-energy-solar-production"})
        end
      end
    end
  end

  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len)
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

-- this new function in libraries version 9 allow load only subdrivers with devices paired
local function lazy_load_if_possible(sub_driver_name)
  -- gets the current lua libs api version
  local version = require "version"

  --print("<<<<< Library Version:", version.api)
  -- version 9 will include the lazy loading functions
  if version.api >= 9 then
    return ZigbeeDriver.lazy_load_sub_driver(require(sub_driver_name))
  else
    return require(sub_driver_name)
  end
end

local zigbee_power_meter_driver_template = {
  supported_capabilities = {
    capabilities.refresh,
    capabilities.powerMeter,
    capabilities.energyMeter,
    capabilities.powerConsumptionReport,
    capabilities.temperatureMeasurement
  },
  sub_drivers = {
    lazy_load_if_possible("ezex"),
    lazy_load_if_possible("frient"),
    lazy_load_if_possible("shinasystems"),
    lazy_load_if_possible("tuya-meter"),
    lazy_load_if_possible("tuya-meter-dual")
  },
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
    infoChanged = do_preferences,
  }
}

defaults.register_for_default_handlers(zigbee_power_meter_driver_template, zigbee_power_meter_driver_template.supported_capabilities)
local zigbee_power_meter = ZigbeeDriver("zigbee_power_meter", zigbee_power_meter_driver_template)
zigbee_power_meter:run()
