-- Copyright 2021 Zach Varberg, SmartThings
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
local data_types = require "st.zigbee.data_types"
local capabilities = require "st.capabilities"
local buf = require "st.buf"

local xiaomi_utils = {}

xiaomi_utils.xiaomi_custom_data_type = {
  deserialize = function(data_buf)
    local out = {
      items = {}
    }
    while data_buf:remain() > 0 do
      local index = data_types.Uint8.deserialize(data_buf)
      local data_type = data_types.ZigbeeDataType.deserialize(data_buf)
      local data = data_types.parse_data_type(data_type.value, data_buf)
      out.items[#out.items + 1] = {
        index = index,
        data_type = data_type,
        data = data,
      }
    end
    return out
  end,
}


xiaomi_utils.emit_battery_event = function(self, device, battery_record)
  local raw_bat_volt = (battery_record.value / 1000)
  local raw_bat_perc = (raw_bat_volt - 2.5) * 100 / (3.0 - 2.5)
  local bat_perc = math.floor(math.max(math.min(raw_bat_perc, 100), 0))
  device:emit_event(capabilities.battery.battery(bat_perc))
end

xiaomi_utils.battery_handler = function(self, device, value)
  if value.ID == data_types.CharString.ID then
    local bytes = value.value
    local message_buf = buf.Reader(bytes)
    local xiaomi_data_type = xiaomi_utils.xiaomi_custom_data_type.deserialize(message_buf)
    for i, item in ipairs(xiaomi_data_type.items) do
      if item.data_type.value == data_types.Uint16.ID then
        xiaomi_utils.emit_battery_event(self, device, item.data)
        return
      end
    end
  elseif value.ID == data_types.Structure.ID then
    for i, record in ipairs(value.elements) do
      if record.data_type.value == data_types.Uint16.ID then
        xiaomi_utils.emit_battery_event(self, device, record.data)
        return
      end
    end
  end
end

return xiaomi_utils