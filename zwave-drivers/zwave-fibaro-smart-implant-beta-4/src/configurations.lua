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

--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=1 })
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version=2 })
--- @type st.zwave.CommandClass.Notification
local Notification = (require "st.zwave.CommandClass.Notification")({ version=8 })
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 2 })

local devices = {
  FIBARO_MOTION_SENSOR_ZW5 = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0801
    },
    ASSOCIATION = {
      {grouping_identifier = 1}
    },
    CONFIGURATION = {
      {parameter_number = 24, configuration_value = 2, size = 1}
    },
    WAKE_UP = {
      {seconds = 7200}
    }
  },
  FIBARO_FLOOD_SENSOR_ZW5 = {
    MATCHING_MATRIX = {
      mfrs = 0x010F,
      product_types = 0x0B01,
      product_ids = nil
    },
    ASSOCIATION = {
      {grouping_identifier = 1},
      {grouping_identifier = 3},
      {grouping_identifier = 4}
    },
    CONFIGURATION = {
      {parameter_number = 74, configuration_value = 3, size = 1}
    },
    WAKE_UP = {
      {seconds = 21600}
    }
  },
  FIBARO_OPEN_CLOSE_SENSOR_1 = {
    MATCHING_MATRIX = {
      mfrs = {0x010F,0x0086,0x0109,0x017F},
      product_types = {0x0002,0x0100,0x0102,0x200A,0x0501},
      product_ids = {0x0001,0x0004,0x0061,0x1001,0x1002,0x0A02}
    },
    ASSOCIATION = {
      {grouping_identifier = 1},
      {grouping_identifier = 2},
      {grouping_identifier = 3}
    },
    CONFIGURATION = {
      {parameter_number = 1, configuration_value = 0, size = 1},
      {parameter_number = 2, configuration_value = 1, size = 1},
      {parameter_number = 3, configuration_value = 0, size = 1},
      {parameter_number = 5, configuration_value = 255, size = 2},
      {parameter_number = 7, configuration_value = 255, size = 2},
      {parameter_number = 9, configuration_value = 0, size = 1},
      {parameter_number = 10, configuration_value = 1, size = 1},
      {parameter_number = 12, configuration_value = 4, size = 1},
      {parameter_number = 13, configuration_value = 0, size = 1},
      {parameter_number = 14, configuration_value = 0, size = 1}
    }
  }
}
local configurations = {}

configurations.initial_configuration = function(driver, device)
  local configuration = configurations.get_device_configuration(device)
  if configuration ~= nil then
    for _, value in ipairs(configuration) do
      --device:send(Configuration:Set(value))
      device:send(Configuration:Set({parameter_number = value.parameter_number, size = value.size, configuration_value = value.configuration_value}))
    end
  end
  local association = configurations.get_device_association(device)
  if association ~= nil then
    for _, value in ipairs(association) do
      local _node_ids = value.node_ids or {driver.environment_info.hub_zwave_id}
      device:send(Association:Set({grouping_identifier = value.grouping_identifier, node_ids = _node_ids}))
    end
  end
  local notification = configurations.get_device_notification(device)
  if notification ~= nil then
    for _, value in ipairs(notification) do
      device:send(Notification:Set(value))
    end
  end
  local wake_up = configurations.get_device_wake_up(device)
  if wake_up ~= nil then
    for _, value in ipairs(wake_up) do
      local _node_id = value.node_id or driver.environment_info.hub_zwave_id
      device:send(WakeUp:IntervalSet({seconds = value.seconds, node_id = _node_id}))
    end
  end
end

configurations.get_device_configuration = function(zw_device)
  for _, device in pairs(devices) do
    if zw_device:id_match(
      device.MATCHING_MATRIX.mfrs,
      device.MATCHING_MATRIX.product_types,
      device.MATCHING_MATRIX.product_ids) then
      return device.CONFIGURATION
    end
  end
  return nil
end

configurations.get_device_association = function(zw_device)
  for _, device in pairs(devices) do
    if zw_device:id_match(
      device.MATCHING_MATRIX.mfrs,
      device.MATCHING_MATRIX.product_types,
      device.MATCHING_MATRIX.product_ids) then
      return device.ASSOCIATION
    end
  end
  return nil
end

configurations.get_device_notification = function(zw_device)
  for _, device in pairs(devices) do
    if zw_device:id_match(
      device.MATCHING_MATRIX.mfrs,
      device.MATCHING_MATRIX.product_types,
      device.MATCHING_MATRIX.product_ids) then
      return device.NOTIFICATION
    end
  end
  return nil
end

configurations.get_device_wake_up = function(zw_device)
  for _, device in pairs(devices) do
    if zw_device:id_match(
      device.MATCHING_MATRIX.mfrs,
      device.MATCHING_MATRIX.product_types,
      device.MATCHING_MATRIX.product_ids) then
      return device.WAKE_UP
    end
  end
  return nil
end

return configurations
