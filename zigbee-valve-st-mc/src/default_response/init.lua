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

local clusters = require "st.zigbee.zcl.clusters"
--local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local capabilities = require "st.capabilities"
--local utils = require "st.utils"
local zcl_global_commands = require "st.zigbee.zcl.global_commands"
local Status = require "st.zigbee.generated.types.ZclStatus"

local ZIGBEE_DEFAULT_RESPONSE_FINGERPRINTS = {
  { mfr = "_TZ3000_tvuarksa", model = "TS011F" }
}

local is_zigbee_default_response_device = function(opts, driver, device)
    for _, fingerprint in ipairs(ZIGBEE_DEFAULT_RESPONSE_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("default_response")
          return true, subdriver
        end
    end
  return false
end

local function default_response_handler(driver, device, zb_rx)
  local status = zb_rx.body.zcl_body.status.value

  if status == Status.SUCCESS then
    local cmd = zb_rx.body.zcl_body.cmd.value
    local event = nil

    if cmd == clusters.OnOff.server.commands.On.ID then
      event = capabilities.valve.valve.open()
    elseif cmd == clusters.OnOff.server.commands.Off.ID then
      event = capabilities.valve.valve.closed()
    end

    if event ~= nil then
      device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, event)
    end
  end
end

local function on_off_attr_handler(driver, device, zb_rx)
  print("<< on_off_attr_handler --> not supported >>")
end

local default_response_device = {
  NAME = "default response device",
  zigbee_handlers = {
    global = {
      [clusters.OnOff.ID] = {
        [zcl_global_commands.DEFAULT_RESPONSE_ID] = default_response_handler
      }
    },
    attr = {
      [clusters.OnOff.ID] = {
        [clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
      }
    }
  },
  can_handle = is_zigbee_default_response_device
}

return default_response_device