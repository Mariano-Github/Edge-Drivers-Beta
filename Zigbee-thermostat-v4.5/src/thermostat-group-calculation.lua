------- signal metrics emit event----

local capabilities = require "st.capabilities"
local type_temp_calculation = "No Group Controller"
local group_temp = {}
local device_controller = {}

local device_Info = capabilities["legendabsolute60149.deviceInfo"]

local thermostat_group ={}

---Format row HTML
  local function format_row(key, value)
    local info = "<tr> <th align=left>" .. key .. "</th> <td>" .. value .. "</td></tr>"
    return info
  end

  -- emit devices group temperature
  local function emit_device_group_info(driver, device, group,temperature)
    local scale = "ºC"
    if device.preferences.thermTempUnits == "Fahrenheit" then
      scale = "ºF"
    end
    --for group_active, value in pairs (group) do 
      --print("<<< group_active >>>",group_active)
      local info = "<em style='color:Red;font-weight: bold;'".."<b>Thermostat Group: </b>".."</em>".. group.."<BR>"
      info = info .."<em style='color:Red;font-weight: bold;'".."<b>Temp Calculation Type: </b>".."</em>"..type_temp_calculation.."<BR>"
      if type_temp_calculation == "No Group Controller" then
        info = info .."<em style='color:Red;font-weight: bold;'".."<b>Group Temperature: </b>".."</em>".. "-" .. scale.."<BR>"
      else
        info = info .."<em style='color:Red;font-weight: bold;'".."<b>Group Temperature: </b>".."</em>".. group_temp[group] .. scale.."<BR>"
      end
      for dev, value in pairs (temperature) do
        if dev.preferences.useMultipleSensors == true then
          info = info.."<em style='color:Green;font-weight: bold;'".."<b>* Device Controller: </b>".."</em>"..dev.label .."<BR>"
        else
          info = info .."<em style= 'font-weight: bold;'>".."<b>Device: </b>".."</em>"..dev.label .."<BR>"
        end
        info = info.."<em style= 'font-weight: bold;'>".."<b> Temperature: </b>".."</em>".. temperature[dev].. scale .. "<BR>"
      end
      info = "<table style='font-size:75%'> <tbody>".. format_row('', info)
      info = info .. "</tbody></table>"

      for dev, value in pairs (temperature) do
        dev:emit_event(device_Info.deviceInfo({value = info}, {visibility = {displayed = false}}))
      end
    --end
  end

  -- thermostat_group.temperature_calculation
  function thermostat_group.temperature_calculation(driver, device, group)
    local temperature = {}
    device_controller = nil
    local active_group = {nil}
    type_temp_calculation = "No Group Controller"
    local master = 0
    for uuid, dev in pairs(device.driver:get_devices()) do
      if dev.preferences.useMultipleSensors == true and dev.preferences.thermostatGroup == group then
        master = master + 1
      end
      if dev.preferences.thermostatGroup > 0 then
        if active_group[dev.preferences.thermostatGroup] == nil then
          active_group[dev.preferences.thermostatGroup] = dev.preferences.thermostatGroup
        end
      end
    end
    -- detect if Use multisensor = TRUE, selected on in two or more devices
    if master > 1 then
      for uuid, dev in pairs(device.driver:get_devices()) do
        if dev.preferences.useMultipleSensors == true then
          local info = "Use Control Multisensor = TRUE, selected on "..master.." devices in the group: ".. group.."<BR>"
          info = info .."Check the preferences of the group devices".."<BR>"
          info = "<table style='font-size:75%'> <tbody>".. format_row('', info)
          info = info .. "</tbody></table>"

          dev:emit_event(device_Info.deviceInfo({value = info}, {visibility = {displayed = false}}))
        end
      end
      return
    end

    for uuid, dev in pairs(device.driver:get_devices()) do
      print("<<< Device in driver >>>", dev.id, dev.label)
      --if dev.preferences.useMultipleSensors == true or dev.preferences.thermostatGroup == group then
      if dev.preferences.thermostatGroup == group then
        if dev.preferences.useMultipleSensors == true then
          type_temp_calculation = dev.preferences.calculationType
          device_controller = dev
        end
          if dev:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME) == nil then
            dev:emit_event(device_Info.deviceInfo({value = "Waiting for New Temp Event"}, {visibility = {displayed = false}}))
            return 
          end
          temperature[dev]= dev:get_latest_state("main", capabilities.temperatureMeasurement.ID, capabilities.temperatureMeasurement.temperature.NAME) + dev.preferences.tempOffset
          --local scale = "C"
          if device.preferences.thermTempUnits == "Fahrenheit" or dev.preferences.thermTempUnits == "Fahrenheit" then
            --scale = "F"
            temperature[dev] = (temperature[dev] * 9/5) + 32
          end
          if device.preferences.logDebugPrint == true then
            print("<<< temperature[dev] >>>",temperature[dev])
            print("<<< dev.preferences.thermostatGroup >>>",dev.preferences.thermostatGroup)
            print("<<< dev.preferences.calculationType >>>",dev.preferences.calculationType)
          end
        end
    end
    group_temp[group] = 0
    local group_devices = 0
    for dev, value in pairs (temperature) do
      if type_temp_calculation == "Average" then
        group_devices = group_devices + 1
        group_temp[group] = group_temp[group] + temperature[dev]
      end
    end
    if type_temp_calculation == "Average" then
      group_temp[group] = group_temp[group] / group_devices
      group_temp[group] = tonumber(string.format("%.2f", group_temp[group]))
      --print("<<<< group_temp >>>", group_temp)
    elseif type_temp_calculation == "Maximum" then
      local max = 0
      for dev, value in pairs (temperature) do
        max = temperature[dev]
        for dev1, value in pairs (temperature) do
          if max >= temperature[dev1] then 
            max = max
          else
            max = temperature[dev1]
          end
        end
      end
      group_temp[group] = max
    elseif type_temp_calculation == "Minimum" then
      local min = 0
      for dev, value in pairs (temperature) do
        min = temperature[dev]
        for dev1, value in pairs (temperature) do
          if min <= temperature[dev1] then 
            min = min
          else
            min = temperature[dev1]
          end
        end
      end
      group_temp[group] = min
    end
    --print("<<<< group_temp >>>", group_temp)
    print("<<< device_controller >>>",device_controller)
    if device_controller ~= nil then
      device_controller:set_field("last_temp", group_temp[group], {persist = false})
    end
    emit_device_group_info(driver, device, group, temperature)
  end
return thermostat_group