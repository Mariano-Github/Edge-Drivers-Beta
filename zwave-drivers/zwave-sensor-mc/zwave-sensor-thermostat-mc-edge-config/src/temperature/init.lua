-- subdriver to refresh virtual thermostat 

local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.SensorMultilevel
local SensorMultilevel = (require "st.zwave.CommandClass.SensorMultilevel")({ version = 5 })
--- @type st.utils
local utils = require "st.utils"
local refresh_thermostat = require "thermostat/refresh-thermostat"

---
--- @param driver Driver driver instance
--- @param device Device device isntance
--- @return boolean true if the device proper, else false
local function can_handle_temperature_sensor(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end  ---- device (is Child device)
  local cmd = ...
  if(cmd.args) == nil then
    return false
  else
    if device.preferences.logDebugPrint == true then
      print("<<<< cmd.args.sensor_type >>>>>>", utils.stringify_table(cmd.args.sensor_type))
      --print("<<<< cmd >>>>>>", utils.stringify_table(cmd))
    end
    if cmd.args.sensor_type == 1 then
        return true
    else
      return false
    end
  end
end

--local zwave_handlers = {}

--- Handler for sensor multilevel report command class
---
--- @param self st.zwave.Driver
--- @param device st.zwave.Device
--- @param cmd st.zwave.CommandClass.SensorMultilevel.Report
local function temperature_report_handler(self, device, cmd)
  print("<< Sub-driver temperature_report_handler >>")

  if (cmd.args.sensor_type == SensorMultilevel.sensor_type.TEMPERATURE) then
    local scale = 'C'
    local temp_value = cmd.args.sensor_value
    if (cmd.args.scale == SensorMultilevel.scale.temperature.FAHRENHEIT) then scale = 'F' end

    -- if model 0700 v2.5 use custom temperature offset
    if device:get_field("app_version") ~= nil then
      if device:get_field("app_version") == 25 then
        if scale == "F" and device.preferences.tempUnits == "F" then
          temp_value = temp_value + device.preferences.temCustomOffset
        elseif scale == "F" and device.preferences.tempUnits == "C" then
          temp_value = temp_value + (device.preferences.temCustomOffset * 9/5)
        elseif scale == "C" and device.preferences.tempUnits == "C" then
          temp_value = temp_value + device.preferences.temCustomOffset
        elseif scale == "C" and device.preferences.tempUnits == "F" then
          temp_value = temp_value + (device.preferences.temCustomOffset * 5/9)
        end
      end
    end
    device:emit_event_for_endpoint(cmd.src_channel, capabilities.temperatureMeasurement.temperature({value = temp_value, unit = scale}))

    -- save new temperature for Thermostat Child device
    local component = device:endpoint_to_component(cmd.src_channel)
    local child_device = device:get_child_by_parent_assigned_key(component)
    if child_device ~= nil then 
      child_device:set_field("last_temp", temp_value, {persist = false})
      child_device:set_field("stateUnit", scale, {persist = false})
      child_device:emit_event(capabilities.temperatureMeasurement.temperature({value = temp_value, unit = scale}))

      -- thermostat calculations
      refresh_thermostat.thermostat_data_check (self, child_device)

      ---- GET Temperature Timer Cancel ------
      for timer in pairs(device.thread.timers) do
        if device.preferences.logDebugPrint == true then
          print("<<< Cancel GET Temp timer >>>")
        end
        device.thread:cancel_timer(timer)
      end

      local get_new_temperature = function(d)
        device:send(SensorMultilevel:Get({sensor_type = SensorMultilevel.sensor_type.TEMPERATURE}, {dst_channels = {cmd.src_channel}}))
        if device:get_field("app_version") == 25 then
          device:send(SensorMultilevel:Get({sensor_type = SensorMultilevel.sensor_type.TEMPERATURE}, {dst_channels = {0x02}}))
        end
      end
      device.thread:call_with_delay(300, get_new_temperature, "GET temperature")
    end
  end
end

local temperature_sensor_handler = {
  zwave_handlers = {
    [cc.SENSOR_MULTILEVEL] = {
      [SensorMultilevel.REPORT] = temperature_report_handler
    }
  },
  NAME = "temperature sensor handler",
  can_handle = can_handle_temperature_sensor
}

return temperature_sensor_handler
