-- Mariano Colmenarejo 2024
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

-- DP´s of MHCOZY switch-temp-humid -------
-- DP ---------Name---------Type---------Values ---------------------------CMD
-- 101 (0x65): MODE Manual  Enum(04)     OFF(0), ON(1)                     0x06 (PROACTIVE REPORT VALUES CHANGES)
-- 102 (0x66): Temperature  Number(02)   ------                            0x06 (PROACTIVE REPORT VALUES CHANGES)

local constants = require "st.zigbee.constants"
--local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"
local zdo_messages = require "st.zigbee.zdo"

local ZigbeeZcl = require "st.zigbee.zcl"
local ZigbeeConstants = require "st.zigbee.constants"
local data_types = require "st.zigbee.data_types"
--local Messages = require "st.zigbee.messages"
local generic_body = require "st.zigbee.generic_body"
local utils = require"st.utils"

local TUYA_CLUSTER = 0xEF00
local DP_TYPE_VALUE = "\x02"
local DP_TYPE_ENUM = "\x04"
local SeqNum = 0

local TUYA_MHCOZY_FINGERPRINTS = {
    { mfr = "_TZ3218_7fiyo3kv", model = "TS000F" },
}

local is_tuya_mhcozy = function(opts, driver, device)
    for _, fingerprint in ipairs(TUYA_MHCOZY_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("tuya-MHCOZY")
          return true, subdriver
        end
    end
    return false
end

-- Send command to cluster EF00
local function SendCommand(device, DpId, Type, Value)
  local addrh = messages.AddressHeader(
    ZigbeeConstants.HUB.ADDR, 					-- Source Address
    ZigbeeConstants.HUB.ENDPOINT,				-- Source Endpoint
    device:get_short_address(),			-- Destination Address
    device:get_endpoint(TUYA_CLUSTER),	-- Destination Address
    ZigbeeConstants.HA_PROFILE_ID,				-- Profile Id
    TUYA_CLUSTER						-- Cluster Id
  )
  -- iquix use command 0x00. I use command 0x04 according tuya documment EF00
  --https://developer.tuya.com/en/docs/iot/tuya-zigbee-module-uart-communication-protocol?id=K9ear5khsqoty#dataFormat
  local zclh = ZigbeeZcl.ZclHeader({cmd = data_types.ZCLCommandId(0x04)})
  zclh.frame_ctrl:set_cluster_specific()	-- sets this frame control field to be cluster specific
  -- Make a payload body
  SeqNum = (SeqNum + 1) % 65536
  local strSeqNum = string.pack(">I2", SeqNum)  -- Pack the Sequence number to 2 bytes unsigned integer type with big endian.
  local LenOfValue = string.pack(">I2",string.len(Value))  -- Pack length of Value to 2 bytes unsigned integer type wiht big endian.
  local PayloadBody = generic_body.GenericBody(strSeqNum .. DpId .. Type .. LenOfValue .. Value)
  local MsgBody = ZigbeeZcl.ZclMessageBody({zcl_header = zclh, zcl_body = PayloadBody})
  local TxMsg = messages.ZigbeeMessageTx({address_header = addrh, body = MsgBody})
  device:send(TxMsg)
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

local tuyaDatapoints = {
  CurrentTemp = 0x66,
  CurrentHumidity = 0x67,
  modeManual = 0x65
}

local function getDataPointName(id)
  for key, value in pairs(tuyaDatapoints) do
    if value == id then return key end
  end
end

local function getCommand(body)
  local cmd = {}
  cmd.seq = string.sub(body, 1, 2)
  cmd.dpid = string.unpack("B", string.sub(body, 3, 3))
  cmd.dataType = string.unpack("B", string.sub(body, 4, 4))
  cmd.len = string.unpack(">I2", string.sub(body, 5, 6))
  cmd.data = string.sub(body, 7, 7 + cmd.len)
  cmd.dpName = getDataPointName(cmd.dpid)
  if cmd.dpName == nil then cmd.dpName = "Unknown" end
  return cmd
end

local function tuya_handler_mode(self, device, zb_rx)
  -- DP 101 (0x65) GenericBody byte 7 is Mode (OFF(0), ON(1))
 local  mode = zb_rx.body.zcl_body.body_bytes:byte(7)
  if device.preferences.logDebugPrint == true then
    print("<<< Mode = ", mode)
  end
    local event = "Click"
  if mode == 1 then event = "Switch" end
 -- device:emit_event(fingerbot_Mode.fingerBotMode(event))
end

local function tuya_handler_temperature(self, device, zb_rx)
  print("<<<< tuya_handler_temperature >>>>")
  -- DP 102 (0x66) GenericBody byte 10 is temperature
  if device:supports_capability_by_id(capabilities.temperatureMeasurement.ID) then
    local value = 0
    local cmd = getCommand(zb_rx.body.zcl_body.body_bytes)
    --print(commands.stringify_command(cmd, false))
    if cmd.dpName == "CurrentTemp" then
      local divisor = 10
      value = string.unpack(">i", cmd.data) / divisor
      device:emit_event(capabilities.temperatureMeasurement.temperature({value = value, unit = "C" }))
    end
  end
end

local function tuya_handler_humidity(self, device, zb_rx)
  print("<<<< tuya_handler_humidity >>>>")
  -- DP 103 (0x67) GenericBody byte 10 is Humidity
  if device:supports_capability_by_id(capabilities.relativeHumidityMeasurement.ID) then
    local value = 0
    local cmd = getCommand(zb_rx.body.zcl_body.body_bytes)
    --print(commands.stringify_command(cmd, false))
    if cmd.dpName == "CurrentHumidity" then
      local divisor = 1
      value = utils.round(string.unpack(">i", cmd.data) / divisor)
      device:emit_event(capabilities.relativeHumidityMeasurement.humidity(value))
    end
  end
end


-- Tuya report handler
local function tuya_handler(self, device, zb_rx)
  print("<<<< Tuya handler >>>>")

  local dp_table = {
    --[0x65] = tuya_handler_mode,
    [0x66] = tuya_handler_temperature,
    [0x67] = tuya_handler_humidity,
  }
  -- cluster: 0xEF00 example
  -- ZCLCommandId: 0x05 >, GenericBody:  00 08 69 02 00 04 00 00 00 64 > >
  -- Command id with battery is [0x05] Report status (passively) received avery 4 hours
  -- dp in this device is 0x69 and byte 10 is de % battery (64 = 100%)

  local dp = zb_rx.body.zcl_body.body_bytes:byte(3)
  local type = zb_rx.body.zcl_body.body_bytes:byte(4)
  local value_len = zb_rx.body.zcl_body.body_bytes:byte(6)
  local body_len = zb_rx.body_length.value
  if device.preferences.logDebugPrint == true then
    print("<<< dp =",dp)
    print("<<< type =", type)
    print("<<< dp value len =", value_len)
    print("<<< body len =", body_len)
  end

  local dp_handler = dp_table[dp]
  if dp_handler then
    dp_handler(self, device, zb_rx)
  end
end


--- do_driverSwitched
local function do_driverSwitched(self, device) --23/12/23
  print("<<<< DriverSwitched >>>>")
   device.thread:call_with_delay(3, function(d)
     do_configure(self, device)
   end, "configure") 
 end

local tuya_mhcozy = {
  NAME = "tuya MHCOZY",
  capability_handlers = {

  },
  zigbee_handlers = {
    cluster = {
      [TUYA_CLUSTER] = {
        [0x05] = tuya_handler,
        [0x06] = tuya_handler,
        [0x02] = tuya_handler,
      }
    },
    zdo = {
      [mgmt_bind_resp.MGMT_BIND_RESPONSE] = zdo_binding_table_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    driverSwitched = do_driverSwitched,
    doConfigure = do_configure
  },
  can_handle = is_tuya_mhcozy
}

return tuya_mhcozy