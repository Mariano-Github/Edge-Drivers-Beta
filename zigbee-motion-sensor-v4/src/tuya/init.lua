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
local signal = require "signal-metrics"

--local PowerConfiguration = clusters.PowerConfiguration
local TUYA_CLUSTER = 0xEF00

local TUYA_MOTION_SENSOR_FINGERPRINTS = {
    { mfr = "_TZE200_3towulqd", model = "TS0601" }
}

local is_tuya_motion = function(opts, driver, device)
    for _, fingerprint in ipairs(TUYA_MOTION_SENSOR_FINGERPRINTS) do
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
  --device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  --device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1))
  --device:send(clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))

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
end

local function tuya_handler_battery(self, device, zb_rx)
  local battery_pc = zb_rx.body.zcl_body.body_bytes:byte(10)
  device:emit_event(capabilities.battery.battery(battery_pc))
end

local function tuya_handler_motion(self, device, zb_rx)
  local event_table = {
    [0x00] = capabilities.motionSensor.motion.active,
    [0x01] = capabilities.motionSensor.motion.inactive,
  }
  local motion_active = zb_rx.body.zcl_body.body_bytes:byte(7)
  local ev = event_table[motion_active]
  if ev then
    device:emit_event(ev())
  end
end

local function tuya_handler_illuminance(self, device, zb_rx)
  local bytes = zb_rx.body.zcl_body.body_bytes:byte(9,10)
  local lux = string.unpack(">I2", zb_rx.body.zcl_body.body_bytes, 9)
  device:emit_event_for_endpoint(
    zb_rx.address_header.src_endpoint.value,
    capabilities.illuminanceMeasurement.illuminance(lux))
end

local function tuya_handler(self, device, zb_rx)

    -- emit signal metrics
    signal.metrics(device, zb_rx)

  local dp_table = {
    [0x01] = tuya_handler_motion,
    [0x04] = tuya_handler_battery,
    [0x0c] = tuya_handler_illuminance,
    -- Zigbee EUI + Network ID
    --[0xe2] = GenericBody:  00 01 E2 55 44 33 22 11 00 11 00
  }
  local version = zb_rx.body.zcl_body.body_bytes:byte(1)
  local sequence = zb_rx.body.zcl_body.body_bytes:byte(2)
  local dp = zb_rx.body.zcl_body.body_bytes:byte(3)
  local dp_handler = dp_table[dp]
  if dp_handler then
    dp_handler(self, device, zb_rx)
  end
end

local tuya_motion_sensor = {
  NAME = "tuya motion sensor",
  zigbee_handlers = {
    cluster = {
      [TUYA_CLUSTER] = {
        [0x02] = tuya_handler,
      }
    },
    zdo = {
      [mgmt_bind_resp.MGMT_BIND_RESPONSE] = zdo_binding_table_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    doConfigure = do_configure
  },
  can_handle = is_tuya_motion
}

return tuya_motion_sensor