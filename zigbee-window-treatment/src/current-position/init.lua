-- Copyright 2022 SmartThings
-- 
-- this module created by M.Colmenarejo
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
local zcl_clusters = require "st.zigbee.zcl.clusters"
local window_shade_defaults = require "st.zigbee.defaults.windowShade_defaults"
local WindowCovering = zcl_clusters.WindowCovering

local SHADE_SET_STATUS = "shade_set_status"

local is_tuya_window_shade = function(opts, driver, device)
  if device:get_manufacturer() == "_TZ3000_zirycpws" then
    return true
  end
  return false
end

local function current_position_attr_handler(driver, device, value, zb_rx)
  print("<<<< Subdriver current-position: current_position_attr_handler")
  local level = value.value
  local current_level = device:get_latest_state("main", capabilities.windowShadeLevel.ID, capabilities.windowShadeLevel.shadeLevel.NAME)
  local windowShade = capabilities.windowShade.windowShade
  if device:get_field("curtain_switch") ~= 1 then --- if curtain is stopped then skip level report
    if level <= 1 and device:get_field("curtain_switch") ==  2 then
      level =  0
      device:emit_event(windowShade.closed())
      device:emit_event(capabilities.windowShadeLevel.shadeLevel(0))
    elseif level >= 99 and device:get_field("curtain_switch") ==  0 then
      level = 100
      device:emit_event(windowShade.open())
      device:emit_event(capabilities.windowShadeLevel.shadeLevel(100))
    else
      if current_level ~= level or current_level == nil then
        current_level = current_level or 0
        device:emit_event(capabilities.windowShadeLevel.shadeLevel(level))
        local event = nil
        if current_level ~= level then
          event = current_level < level and windowShade.opening() or windowShade.closing()
        end
        if event ~= nil then
          device:emit_event(event)
        end
      end
      local set_status_timer = device:get_field(SHADE_SET_STATUS)
      if set_status_timer then
        device.thread:cancel_timer(set_status_timer)
        device:set_field(SHADE_SET_STATUS, nil)
      end
      local set_window_shade_status = function()
        current_level = device:get_latest_state("main", capabilities.windowShadeLevel.ID, capabilities.windowShadeLevel.shadeLevel.NAME)
        if current_level <= 1 then
          level = 0
          device:emit_event(capabilities.windowShadeLevel.shadeLevel(level))
          device:emit_event(windowShade.closed())
        elseif current_level >= 99 then
          level = 100
          device:emit_event(capabilities.windowShadeLevel.shadeLevel(level))
          device:emit_event(windowShade.open())
        else
          device:emit_event(windowShade.partially_open())
        end
        device:set_field("")
      end
      set_status_timer = device.thread:call_with_delay(2, set_window_shade_status)
      device:set_field(SHADE_SET_STATUS, set_status_timer)
    end
  end
end

local current_position_window_shade = {
  NAME = "current position window shade",
  capability_handlers = {
  },
  zigbee_handlers = {
    attr = {
      [WindowCovering.ID] = {
        [WindowCovering.attributes.CurrentPositionLiftPercentage.ID] = current_position_attr_handler
      },
    }
  },
  can_handle = is_tuya_window_shade
}

return current_position_window_shade
