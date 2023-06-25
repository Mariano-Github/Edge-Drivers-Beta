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

local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"
local zdo_messages = require "st.zigbee.zdo"

local TUYA_CLUSTER = 0xEF00

local TUYA_FINGERBOT_FINGERPRINTS = {
    { mfr = "_TZ3210_dse8ogfy", model = "TS0001" }
}

local is_tuya_fingerbot = function(opts, driver, device)
    for _, fingerprint in ipairs(TUYA_FINGERBOT_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
            return true
        end
    end
    return false
end

local function zdo_binding_table_handler(driver, device, zb_rx)
  for _, binding_table in pairs(zb_rx.body.zdo_body.binding_table_entries) do
    if binding_table.dest_addr_mode.value == binding_table.DEST_ADDR_MODE_SHORT then
      -- send add hub to zigbee group command
      driver:add_hub_to_zigbee_group(binding_table.dest_addr.value)
    end
  end
end

local function device_added(self, device)
  device:refresh()
end

local do_configure = function(self, device)
  device:send(device_management.build_bind_request(device, 0xEF00, self.environment_info.hub_zigbee_eui))

  -- Read binding table
  local addr_header = messages.AddressHeader(
    constants.HUB.ADDR,
    constants.HUB.ENDPOINT,
    device:get_short_address(),
    device.fingerprinted_endpoint_id,
    constants.ZDO_PROFILE_ID,
    mgmt_bind_req.BINDING_TABLE_REQUEST_CLUSTER_ID
  )
  local binding_table_req = mgmt_bind_req.MgmtBindRequest(0) -- Single argument of the start index to query the table
  local message_body = zdo_messages.ZdoMessageBody({
                                                   zdo_body = binding_table_req
                                                 })
  local binding_table_cmd = messages.ZigbeeMessageTx({
                                                     address_header = addr_header,
                                                     body = message_body
                                                   })
  device:send(binding_table_cmd)

  device:configure()
end

local function tuya_handler_battery(self, device, zb_rx)
  -- GenericBody byte 10 is de % battery (64 = 100%)
  local battery_pc = zb_rx.body.zcl_body.body_bytes:byte(10)
  device:emit_event(capabilities.battery.battery(battery_pc))
end

-- Tuya report handler
local function tuya_handler(self, device, zb_rx)
  print("<<<< Tuya handler >>>>")

  local dp_table = {
    [0x69] = tuya_handler_battery,
  }
  -- cluster: 0xEF00
  -- ZCLCommandId: 0x05 >, GenericBody:  00 08 69 02 00 04 00 00 00 64 > >
  -- Command id with battery is [0x05] Report status (passively) received avery 4 hours
  -- dp in this device is 0x69 and byte 10 is de % battery (64 = 100%)

  local dp = zb_rx.body.zcl_body.body_bytes:byte(3)
  print("<<< dp=",dp)
  local dp_handler = dp_table[dp]
  if dp_handler then
    dp_handler(self, device, zb_rx)
  end
end

local tuya_fingerbot = {
  NAME = "tuya fingerbot",
  zigbee_handlers = {
    cluster = {
      [TUYA_CLUSTER] = {
        [0x05] = tuya_handler,
      }
    },
    zdo = {
      [mgmt_bind_resp.MGMT_BIND_RESPONSE] = zdo_binding_table_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    driverSwitched = do_configure,
    doConfigure = do_configure
  },
  can_handle = is_tuya_fingerbot
}

return tuya_fingerbot