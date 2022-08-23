-- Copyright 2021 SmartThings
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

------ Author Mariano Colmenarejo (nov 2021) --------

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local xiaomi_utils = require "xiaomi_utils"
local data_types = require "st.zigbee.data_types"

--- Temperature Mesurement config
local zcl_clusters = require "st.zigbee.zcl.clusters"
local BasicInput = zcl_clusters.BasicInput
local tempMeasurement = zcl_clusters.TemperatureMeasurement
local device_management = require "st.zigbee.device_management"
local tempMeasurement_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"

-- default Humidity Measurement
local HumidityCluster = require ("st.zigbee.zcl.clusters").RelativeHumidity
local utils = require "st.utils"

-- Custom Capability AtmPressure declaration
local atmos_Pressure = capabilities ["legendabsolute60149.atmosPressure"]
local temp_Condition = capabilities ["legendabsolute60149.tempCondition2"]
local temp_Target = capabilities ["legendabsolute60149.tempTarget"]
local humidity_Condition = capabilities ["legendabsolute60149.humidityCondition"]
local humidity_Target = capabilities ["legendabsolute60149.humidityTarget"]
local illumin_Condition = capabilities ["legendabsolute60149.illuminCondition"]
local illumin_Target = capabilities ["legendabsolute60149.illuminTarget"]

-- initialice variables
local temp_Condition_set ={}
temp_Condition_set.value = 0
temp_Condition_set.unit = "C"
local humidity_Condition_set = 0
local illumin_Condition_set = 0
local temp_Target_set = " "
local humidity_Target_set = " "
local illumin_Target_set = " "

--- do configure for temperature capability
local function do_configure(self,device)
  ---defualt configuration capabilities
  device:configure()

  if device:get_manufacturer() == "KMPCIL" then
    device:send(device_management.build_bind_request(device, BasicInput.ID, self.environment_info.hub_zigbee_eui))
    device:send(BasicInput.attributes.PresentValue:configure_reporting(device, 0xFFFF, 0xFFFF))
  end
  ----configure temperature capability
  local maxTime = device.preferences.tempMaxTime * 60
  local changeRep = device.preferences.tempChangeRep * 100
  print ("maxTime y changeRep: ",maxTime, changeRep )
  device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
  device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 30, maxTime, changeRep))

  -- configure Humidity
  maxTime = device.preferences.humMaxTime * 60
  changeRep = device.preferences.humChangeRep * 100
  print ("Humidity maxTime & changeRep: ", maxTime, changeRep)
  device:send(device_management.build_bind_request(device, HumidityCluster.ID, self.environment_info.hub_zigbee_eui))
  device:send(HumidityCluster.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
  device:configure()

  -- configure pressure reports
  if device.preferences.pressMaxTime ~= nil or device.preferences.pressChangeRep  ~= nil then
    maxTime = device.preferences.pressMaxTime * 60
    changeRep = device.preferences.pressChangeRep * 10
    print ("Pressure maxTime y changeRep: ",maxTime, changeRep )
    if device:get_manufacturer() == "KMPCIL" then
      local config =
      {
        cluster = 0x0403,
        attribute = 0x0000,
        minimum_interval = 60,
      maximum_interval = maxTime,
      reportable_change = changeRep,
      data_type = data_types.Uint16,
    }
    device:add_configured_attribute(config)
    device:add_monitored_attribute(config)            
  else  
    device:send(device_management.build_bind_request(device, zcl_clusters.PressureMeasurement.ID, self.environment_info.hub_zigbee_eui))
    device:send(zcl_clusters.PressureMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
  end
 end
  -- configure Illuminance reports
 if device.preferences.illuMaxTime ~= nil or device.preferences.illuChangeRep  ~= nil then
  maxTime = device.preferences.illuMaxTime * 60
  changeRep = math.floor(10000 * (math.log((device.preferences.illuChangeRep + 1), 10)))
  print ("Illuminance maxTime y changeRep: ",maxTime, changeRep )
  device:send(device_management.build_bind_request(device, zcl_clusters.IlluminanceMeasurement.ID, self.environment_info.hub_zigbee_eui))
  device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
 end
end

-- preferences update
local function do_preferences(self, device)
  for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id])
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
     if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed: name, old, new >>", id, oldPreferenceValue, newParameterValue)
      if  id == "tempMaxTime" or id == "tempChangeRep" then
        local maxTime = device.preferences.tempMaxTime * 60
        local changeRep = device.preferences.tempChangeRep * 100
        print ("Temp maxTime & changeRep: ", maxTime, changeRep)
        device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
        device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
      elseif id == "humMaxTime" or id == "humChangeRep" then
        local maxTime = device.preferences.humMaxTime * 60
        local changeRep = device.preferences.humChangeRep * 100
        print ("Humidity maxTime & changeRep: ", maxTime, changeRep)
        device:send(device_management.build_bind_request(device, HumidityCluster.ID, self.environment_info.hub_zigbee_eui))
        device:send(HumidityCluster.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
      elseif id == "pressMaxTime" or id == "pressChangeRep" then
        if device:get_manufacturer() == "KMPCIL" then
          local minTime = 60
          local maxTime = device.preferences.pressMaxTime * 60
          local changeRep = device.preferences.pressChangeRep * 10
          print ("Press maxTime & changeRep: ", maxTime, changeRep)
          local config =
          {
            cluster = 0x0403,
            attribute = 0x0000,
            minimum_interval = minTime,
            maximum_interval = maxTime,
            reportable_change = changeRep,
            data_type = data_types.Uint16,
          }
          device:add_configured_attribute(config)
        device:add_monitored_attribute(config)            
        else
          local maxTime = device.preferences.pressMaxTime * 60
          local changeRep = device.preferences.pressChangeRep * 10
          print ("Press maxTime & changeRep: ", maxTime, changeRep)

          device:send(device_management.build_bind_request(device, zcl_clusters.PressureMeasurement.ID, self.environment_info.hub_zigbee_eui))
          device:send(zcl_clusters.PressureMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
        end
      elseif id == "illuMaxTime" or id == "illuChangeRep" then
        local maxTime = device.preferences.illuMaxTime * 60
        local changeRep = math.floor(10000 * (math.log((device.preferences.illuChangeRep + 1), 10)))
        print ("Illumin maxTime & changeRep: ", maxTime, changeRep)
        device:send(device_management.build_bind_request(device, zcl_clusters.IlluminanceMeasurement.ID, self.environment_info.hub_zigbee_eui))
        device:send(zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue:configure_reporting(device, 60, maxTime, changeRep))
      elseif id == "changeProfileTHB" then
        if newParameterValue == "Single" then
           device:try_update_metadata({profile = "temp-humid-battery"})
        else
           device:try_update_metadata({profile = "temp-humid-battery-multi"})
        end
      elseif id == "changeProfileTHPB" then
        if newParameterValue == "Single" then
          device:try_update_metadata({profile = "temp-humid-press-battery"})
        else
          device:try_update_metadata({profile = "temp-humid-press-battery-multi"})
        end
      elseif id == "changeProfileTHPI" then
        if newParameterValue == "Single" then
          device:try_update_metadata({profile = "temp-humid-press-illumin"})
        else
          device:try_update_metadata({profile = "temp-humid-press-illumin-multi"})
        end
      end
      --configure basicinput cluster
      if device:get_manufacturer() == "KMPCIL" then
        device:send(device_management.build_bind_request(device, BasicInput.ID, self.environment_info.hub_zigbee_eui))
        device:send(BasicInput.attributes.PresentValue:configure_reporting(device, 0xFFFF, 0xFFFF))
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

--- temperature handler
local function temp_attr_handler(self, device, tempvalue, zb_rx)

  local last_temp_value = tempvalue.value / 100
  --device:set_field("last_temp_value", last_temp_value, {persist = true})

  local temp_scale = "C"
  -- convert temp sent by device to ºF
  if device.preferences.thermTempUnits == "Fahrenheit" then 
    temp_scale = "F"
    last_temp_value = utils.round((last_temp_value * 9 / 5)) + 32
  end
  last_temp_value =  utils.round(last_temp_value) + device.preferences.tempOffset

  --if last_temp_value == temp_Condition_set.value then
    --temp_Target_set = "Equal"
  --else
  if last_temp_value < temp_Condition_set.value then
    temp_Target_set = "Down"
  elseif last_temp_value >= temp_Condition_set.value then
    temp_Target_set = "Equal-Up"
  end
  
  -- emit temp target
  device:emit_event(temp_Target.tempTarget(temp_Target_set))

  -- emmit device temperature
  tempMeasurement_defaults.temp_attr_handler(self, device, tempvalue, zb_rx)

end

-- attributte handler Atmospheric pressure
local pressure_value_attr_handler = function (driver, device, value, zb_rx)
  print("Pressure.value >>>>>>", value.value)
  -- save previous pressure  and time values
  if device:get_field("last_value") == nil then device:set_field("last_value", 0, {persist = false}) end
  local last_value = device:get_field("last_value")
  if device:get_field("last_value_time") == nil then device:set_field("last_value_time", (os.time() - (device.preferences.pressMaxTime * 60)) , {persist = false}) end
  local last_value_time = device:get_field("last_value_time")
  
  local kPa = math.floor ((value.value + device.preferences.atmPressureOffset) / 10)
  
  --- emmit only events for >= device.preferences.pressChangeRep or device.preferences.pressMaxTim
  if math.abs(value.value + device.preferences.atmPressureOffset - last_value) >= device.preferences.pressChangeRep * 10 or (os.time() - last_value_time) + 20 >= (device.preferences.pressMaxTime * 60) then
    device: emit_event (capabilities.atmosphericPressureMeasurement.atmosphericPressure ({value = kPa, unit = "kPa"}))

    -- emit even for custom capability in mBar
    local mBar = value.value + device.preferences.atmPressureOffset
    device:emit_event(atmos_Pressure.atmosPressure(mBar))

    --save emitted pressure value
    device:set_field("last_value", value.value + device.preferences.atmPressureOffset, {persist = false})
    device:set_field("last_value_time", os.time(), {persist = false})
  end
end

---humidity_attr_handler
local function humidity_attr_handler(driver, device, value, zb_rx)

  local last_humid_value = utils.round(value.value / 100.0) + device.preferences.humidityOffset
  --device:set_field("last_humid_value", utils.round(value.value / 100.0), {persist = true})

  --if last_humid_value == humidity_Condition_set then
    --humidity_Target_set = "Equal"
  --else
  if last_humid_value < humidity_Condition_set then
    humidity_Target_set = "Down"
  elseif last_humid_value >= humidity_Condition_set then
    humidity_Target_set = "Equal-Up"
  end
    
  -- emit temp target
  device:emit_event(humidity_Target.humidityTarget(humidity_Target_set))
  -- emit device humidity
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.relativeHumidityMeasurement.humidity(utils.round(value.value / 100.0) - device.preferences.humidityOffset))

end

--- illuminance_measurement_defaults
local function illuminance_measurement_defaults(driver, device, value, zb_rx)
  --print("luxOffset >>>>>",device.preferences.luxOffset)
  local lux_value = math.floor(10 ^ ((value.value - 1) / 10000)) + device.preferences.luxOffset
  if lux_value < 0 then lux_value = 0 end

  --if lux_value == illumin_Condition_set then
    --illumin_Target_set = "Equal"
  --else
  if lux_value < illumin_Condition_set then
    illumin_Target_set = "Down"
  elseif lux_value >= illumin_Condition_set then
    illumin_Target_set = "Equal-Up"
  end

  -- emit temp target
  device:emit_event(illumin_Target.illuminTarget(illumin_Target_set))
  -- emit device illuminance
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(lux_value))
end

---  set_TempCondition_handler
local function set_TempCondition_handler(self,device,command)
  print("set_TempCondition.value=", command.args.value)
  temp_Condition_set.value = command.args.value

  print("device:get_latest_state >>>>", device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME))
  local last_temp_value = device:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME)
  if last_temp_value == nil then last_temp_value = 0 end
  last_temp_value = utils.round(last_temp_value) + device.preferences.tempOffset

  print("last_temp_value ºC=",last_temp_value)
  local temp_scale = "C"
  -- convert temp sent by device to ºF
  if device.preferences.thermTempUnits == "Fahrenheit" then 
    temp_scale = "F"
    last_temp_value = utils.round((last_temp_value * 9 / 5)) + 32
  end
  print("last_temp_value C or F =",last_temp_value)

  --if last_temp_value == temp_Condition_set.value then
    --temp_Target_set = "Equal"
  --else
  if last_temp_value < temp_Condition_set.value then
    temp_Target_set = "Down"
  elseif last_temp_value >= temp_Condition_set.value then
    temp_Target_set = "Equal-Up"
  end

  -- emit temp target
  device:emit_event(temp_Target.tempTarget(temp_Target_set))
  device:emit_event(temp_Condition.tempCondition({value = temp_Condition_set.value, unit = temp_scale}))
  --device:emit_event(temp_Condition.tempCondition(temp_Condition_set.value))

end

--- set_HumidityCondition_handler
local function set_HumidityCondition_handler(self,device,command)
  print("set_HumidityCondition=", command.args.value)
  humidity_Condition_set = command.args.value
  local last_humid_value = device:get_latest_state("main", capabilities.relativeHumidityMeasurement.ID, capabilities.relativeHumidityMeasurement.humidity.NAME) + device.preferences.humidityOffset
  print ("last_humid_value = ",last_humid_value)

  --if last_humid_value == humidity_Condition_set then
    --humidity_Target_set = "Equal"
  --else
  if last_humid_value < humidity_Condition_set then
    humidity_Target_set = "Down"
  elseif last_humid_value >= humidity_Condition_set then
    humidity_Target_set = "Equal-Up"
  end
    
  --  emit temp target and condition
  device:emit_event(humidity_Target.humidityTarget(humidity_Target_set))
  device:emit_event(humidity_Condition.humidityCondition(humidity_Condition_set))

end

--- set_IlluminCondition_handler
local function set_IlluminCondition_handler(self,device,command)
  print("set_IlluminCondition", command.args.value)
  illumin_Condition_set = command.args.value
  local lux_value = device:get_latest_state("main", capabilities.illuminanceMeasurement.ID, capabilities.illuminanceMeasurement.illuminance.NAME) + device.preferences.luxOffset
  print("lux_value =",lux_value)
  --if lux_value == illumin_Condition_set then
    --illumin_Target_set = "Equal"
  --else
  if lux_value < illumin_Condition_set then
    illumin_Target_set = "Down"
  elseif lux_value >= illumin_Condition_set then
    illumin_Target_set = "Equal-Up"
  end

  -- emit temp target and condition
  device:emit_event(illumin_Target.illuminTarget(illumin_Target_set))
  device:emit_event(illumin_Condition.illuminCondition(illumin_Condition_set))

end

local function do_init(self,device)
    --  initialize values of capabilities
    illumin_Condition_set = device:get_latest_state("main", illumin_Condition.ID, illumin_Condition.illuminCondition.NAME)
    if illumin_Condition_set == nil then illumin_Condition_set = 0 end
    device:emit_event(illumin_Condition.illuminCondition(illumin_Condition_set))

    humidity_Condition_set = device:get_latest_state("main", humidity_Condition.ID, humidity_Condition.humidityCondition.NAME)
    if humidity_Condition_set == nil then humidity_Condition_set = 0 end
    device:emit_event(humidity_Condition.humidityCondition(humidity_Condition_set))

    temp_Condition_set.value = device:get_latest_state("main", temp_Condition.ID, temp_Condition.tempCondition.NAME)
    print("device:get_latest_state", device:get_latest_state("main", temp_Condition.ID, temp_Condition.tempCondition.NAME))
    if temp_Condition_set.value == nil then temp_Condition_set.value = 0 end
    local temp_scale = "C"
    if device.preferences.thermTempUnits == "Fahrenheit" then 
      temp_scale = "F"
    end
    device:emit_event(temp_Condition.tempCondition({value = temp_Condition_set.value, unit = temp_scale }))

    illumin_Target_set = device:get_latest_state("main", illumin_Target.ID, illumin_Target.illuminTarget.NAME)
    if illumin_Target_set == nil then illumin_Target_set = " " end
    device:emit_event(illumin_Target.illuminTarget(illumin_Target_set))

    humidity_Target_set = device:get_latest_state("main", humidity_Target.ID, humidity_Target.humidityTarget.NAME)
    if humidity_Target_set == nil then humidity_Target_set = " " end
    device:emit_event(humidity_Target.humidityTarget(humidity_Target_set))

    temp_Target_set = device:get_latest_state("main", temp_Target.ID, temp_Target.tempTarget.NAME)
    if temp_Target_set == nil then temp_Target_set = " " end
    device:emit_event(temp_Target.tempTarget(temp_Target_set))
end

----- driver template ----------
local zigbee_temp_driver = {
  supported_capabilities = {
    capabilities.relativeHumidityMeasurement,
    capabilities.atmosphericPressureMeasurement,
    atmos_Pressure,
    capabilities.illuminanceMeasurement,
    capabilities.battery,
  },
  lifecycle_handlers = {
    init = do_init,
    doConfigure = do_configure,
    infoChanged = do_preferences,
    driverSwitched = do_configure
  },
  capability_handlers = {
    [temp_Condition.ID] = {
      [temp_Condition.commands.setTempCondition.NAME] = set_TempCondition_handler,
    },
    [humidity_Condition.ID] = {
      [humidity_Condition.commands.setHumidityCondition.NAME] = set_HumidityCondition_handler,
    },
    [illumin_Condition.ID] = {
      [illumin_Condition.commands.setIlluminCondition.NAME] = set_IlluminCondition_handler,
    },
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.basic_id] = {
        [0xFF02] = xiaomi_utils.battery_handler,
        [0xFF01] = xiaomi_utils.battery_handler
      },
      [tempMeasurement.ID] = {
          [tempMeasurement.attributes.MeasuredValue.ID] = temp_attr_handler
      },
      [zcl_clusters.PressureMeasurement.ID] = {
          [zcl_clusters.PressureMeasurement.attributes.MeasuredValue.ID] = pressure_value_attr_handler
      },
      [HumidityCluster.ID] = {
        [HumidityCluster.attributes.MeasuredValue.ID] = humidity_attr_handler
      },
      [zcl_clusters.IlluminanceMeasurement.ID] = {
        [zcl_clusters.IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_measurement_defaults
    }
   }
  },
  sub_drivers = {require("battery")}

}

--------- driver run ------
defaults.register_for_default_handlers(zigbee_temp_driver, zigbee_temp_driver.supported_capabilities)
local temperature = ZigbeeDriver("st-zigbee-temp", zigbee_temp_driver)
temperature:run()
