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

-- DP´s of Fingerbot plus -------
-- DP ---------Name---------Type---------Values ---------------------------CMD
-- 101 (0x65): MODE         Enum(04)     Click(0), Switch(1),Program(2)    0x06 (PROACTIVE REPORT VALUES CHANGES)
-- 102 (0x66): Down MODE    Number(02)   50-100                            0x06 (PROACTIVE REPORT VALUES CHANGES)
-- 103 (0x67): Sustain Time Number(02)   0s-10s                            0x06 (PROACTIVE REPORT VALUES CHANGES)
-- 104 (0x68): Reverse      Enum(04)     Up-on(1)/Up-off(0)                0x06 (PROACTIVE REPORT VALUES CHANGES)
-- 105 (0x69): Battery      Number(02)   0-100                             0x05 (PASIVE REPORT INTERVAL) or 0x06 (PROACTIVE REPORT VALUES CHANGES)
-- 106 (0x6A): Up MODE      Number(02)   0-50                              0x06 (PROACTIVE REPORT VALUES CHANGES)
-- 107 (0x6B): On/off       Bool(1)      On-Off                            0x06 DP NO USADO, SE USA CLUSTER 0006 ATTRIBUTE 0000

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

local mode
local down_move
local up_move
local time
local reverse

local fingerbot_Mode = capabilities["legendabsolute60149.fingerbotMode"]
local fingerbot_DownMotion = capabilities["legendabsolute60149.fingerbotDownMotion"]
local fingerbot_UpMotion = capabilities["legendabsolute60149.fingerbotUpMotion"]
local fingerbot_SustainTime = capabilities["legendabsolute60149.fingerbotSustainTime"]
local fingerbot_Reverse = capabilities["legendabsolute60149.fingerbotReverse"]


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


local function tuya_handler_mode(self, device, zb_rx)
  -- DP 101 (0x65) GenericBody byte 7 is Mode (Click(0), Switch(1), Program(2))
  mode = zb_rx.body.zcl_body.body_bytes:byte(7)
  if device.preferences.logDebugPrint == true then
    print("<<< Mode = ", mode)
  end
    local event = "Click"
  if mode == 1 then event = "Switch" end
  device:emit_event(fingerbot_Mode.fingerBotMode(event))
end

local function tuya_handler_down_move(self, device, zb_rx)
  -- DP 102 (0x66) GenericBody byte 10 is down Movement (50 to 100)
  -- or byte 15 if DP´s 65 and 66 received in the same message
  local body_len = zb_rx.body_length.value
  if body_len >= 18 and zb_rx.body.zcl_body.body_bytes:byte(8) == 102 then
    down_move = zb_rx.body.zcl_body.body_bytes:byte(15)
  else
    down_move = zb_rx.body.zcl_body.body_bytes:byte(10)
  end
  if device.preferences.logDebugPrint == true then
    print("<<< Down Movement = ", down_move)
  end
  device:emit_event(fingerbot_DownMotion.fingerBotDownMotion(down_move))

end

local function tuya_handler_sutant_time(self, device, zb_rx)
  -- DP 103 (0x67) GenericBody byte 10 is Sustant time (0s to 10s)
  time = zb_rx.body.zcl_body.body_bytes:byte(10)
  if device.preferences.logDebugPrint == true then
    print("<<< Sustant Time = ", time)
  end
  device:emit_event(fingerbot_SustainTime.fingerBotSustainTime(time))
end

local function tuya_handler_reverse(self, device, zb_rx)
  -- DP 104 (0x68) GenericBody byte 7 is Reverse (Up-On = 0, Up-Off = 1)
  -- or byte 15 if DP´s 67 and 68 received in the same message
  local body_len = zb_rx.body_length.value
  if body_len >= 18 and zb_rx.body.zcl_body.body_bytes:byte(11) == 104 then
    reverse = zb_rx.body.zcl_body.body_bytes:byte(15)
  else
    reverse = zb_rx.body.zcl_body.body_bytes:byte(7)
  end
  local event = "Up-Off"
  if reverse == 1 then event = "Up-On" end
  if device.preferences.logDebugPrint == true then
    print("<<< Reverse = ", reverse)
  end
  device:emit_event(fingerbot_Reverse.fingerBotReverse(event))
end

local function tuya_handler_battery(self, device, zb_rx)
  -- DP 105 (0x69) GenericBody byte 10 is % battery (64 = 100%)
  local battery_pc = zb_rx.body.zcl_body.body_bytes:byte(10)
  device:emit_event(capabilities.battery.battery(battery_pc))
end

local function tuya_handler_up_move(self, device, zb_rx)
  -- DP 106 (0x6A) GenericBody byte 10 is Up movement (0 to 50)
  -- or byte 15 if DP's 68 and 6A received after change Mode
  local body_len = zb_rx.body_length.value
  if body_len >= 18 and zb_rx.body.zcl_body.body_bytes:byte(8) == 106 then
    up_move = zb_rx.body.zcl_body.body_bytes:byte(15)
  else
    up_move = zb_rx.body.zcl_body.body_bytes:byte(10)
  end
  if device.preferences.logDebugPrint == true then
    print("<<< Up Movement = ", up_move)
  end
  device:emit_event(fingerbot_UpMotion.fingerBotUpMotion(up_move))
end

-- Tuya report handler
local function tuya_handler(self, device, zb_rx)
  print("<<<< Tuya handler >>>>")

  local dp_table = {
    [0x65] = tuya_handler_mode,
    [0x66] = tuya_handler_down_move,
    [0x67] = tuya_handler_sutant_time,
    [0x68] = tuya_handler_reverse,
    [0x69] = tuya_handler_battery,
    [0x6A] = tuya_handler_up_move,
  }
  -- cluster: 0xEF00
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

  if body_len >= 18 and dp == 101  then -- must be dp 102 (65) and dp  102 (66) ZCLCommandId: 0x06 >, GenericBody:  00 02 65 04 00 01 01 66 02 00 04 00 00 00 50 > >
    local dp_2 = zb_rx.body.zcl_body.body_bytes:byte(8)
    if device.preferences.logDebugPrint == true then
      print("<< dp_2 =", dp_2)
    end
    dp_handler = dp_table[dp_2]
    if dp_handler then
      dp_handler(self, device, zb_rx)
    end
  elseif body_len >= 18 and dp == 103  then -- must be dp 103 (67) and dp 104 (68) ZCLCommandId: 0x06 >, GenericBody:  00 03 67 02 00 04 00 00 00 00 68 04 00 01 01 > >
    local dp_2 = zb_rx.body.zcl_body.body_bytes:byte(11)
    if device.preferences.logDebugPrint == true then
      print("<< dp_2 =", dp_2)
    end
    dp_handler = dp_table[dp_2]
    if dp_handler then
      dp_handler(self, device, zb_rx)
    end
  elseif body_len >= 18 and dp == 104  then -- must be dp 104 (68) and dp 106 (6A) ZCLCommandId: 0x06 >, GenericBody:  00 31 68 04 00 01 01 6A 02 00 04 00 00 00 1E 6C 01 00 01 00 > >
    local dp_2 = zb_rx.body.zcl_body.body_bytes:byte(8)
    if device.preferences.logDebugPrint == true then
      print("<< dp_2 =", dp_2)
    end
    dp_handler = dp_table[dp_2]
    if dp_handler then
      dp_handler(self, device, zb_rx)
    end
  --elseif body_len == 21 and (dp == 101 or dp == 103) then
  end
end

--setFingerbotMode_handler
local function setFingerbotMode_handler(self, device, command)
  --DP 102 (0x65)
  mode = 0
  if command.args.value == "Switch" then
    mode = 1
  end
  device:emit_event(fingerbot_Mode.fingerBotMode(command.args.value))

  print("Bot Mode >>>>>>>>>>>>>>>>>")
  local dp_value = "\x00"
  if mode == 1 then
    dp_value = "\x01"
  end
  if device.preferences.logDebugPrint == true then
    print("command.args.value >>>>>", command.args.value)
    print("<< dp_value", dp_value)
  end
  SendCommand(device, "\x65", DP_TYPE_ENUM, dp_value)
end

--setFingerbotDownMotion_handler
local function setFingerbotDownMotion_handler(self, device, command)
  --DP 102 (0x66)
  down_move = command.args.value
  device:emit_event(fingerbot_DownMotion.fingerBotDownMotion(command.args.value))

  print("bot Down Move >>>>>>>>>>>>>>>>>")
  local dp_value = utils.serialize_int(down_move, 4, false, false)
  if device.preferences.logDebugPrint == true then
    print("command.args.value >>>>>", command.args.value)
    print("<< dp_value", dp_value)
  end
  SendCommand(device, "\x6A", DP_TYPE_VALUE, dp_value)
end

--setFingerbotUpMotion_handler
local function setFingerbotUpMotion_handler(self, device, command)
  --DP 106 (0x6A)
  up_move = command.args.value
  device:emit_event(fingerbot_UpMotion.fingerBotUpMotion(command.args.value))

  print("bot Up Move >>>>>>>>>>>>>>>>>")
  local dp_value = utils.serialize_int(up_move, 4, false, false)
  if device.preferences.logDebugPrint == true then
    print("command.args.value >>>>>", command.args.value)
    print("<< dp_value", dp_value)
  end
  SendCommand(device, "\x6A", DP_TYPE_VALUE, dp_value)
end

--setFingerbotSustainTime_handler
local function setFingerbotSustainTime_handler(self, device, command)
  --DP 103 (0x67)
  time = command.args.value
  device:emit_event(fingerbot_SustainTime.fingerBotSustainTime(command.args.value))

  print("bot Sustain Time >>>>>>>>>>>>>>>>>")
  local dp_value = utils.serialize_int(time, 4, false, false)
  if device.preferences.logDebugPrint == true then
    print("command.args.value >>>>>", command.args.value)
    print("<< dp_value", dp_value)
  end
  SendCommand(device, "\x67", DP_TYPE_VALUE, dp_value)
end

-- setFingerbotReverse_handler
local function setFingerbotReverse_handler(self, device, command)
  --DP 104 (0x68)
  reverse = 0
  if command.args.value == "Up-On" then
    reverse = 1
  end
  device:emit_event(fingerbot_Reverse.fingerBotReverse(command.args.value))

  print("bot Reverse >>>>>>>>>>>>>>>>>")
  local dp_value = "\x00"
  if reverse == 1 then
    dp_value = "\x01"
  end
  if device.preferences.logDebugPrint == true then
    print("command.args.value >>>>>", command.args.value)
    print("<< dp_value", dp_value)
  end
  SendCommand(device, "\x68", DP_TYPE_ENUM, dp_value)
end

--- do_driverSwitched
local function do_driverSwitched(self, device) --23/12/23
  print("<<<< DriverSwitched >>>>")
   device.thread:call_with_delay(3, function(d)
     do_configure(self, device)
   end, "configure") 
 end

local tuya_fingerbot = {
  NAME = "tuya fingerbot",
  capability_handlers = {
    [fingerbot_Mode.ID] = {
      [fingerbot_Mode.commands.setFingerBotMode.NAME] = setFingerbotMode_handler,
    },
    [fingerbot_DownMotion.ID] = {
      [fingerbot_DownMotion.commands.setFingerBotDownMotion.NAME] = setFingerbotDownMotion_handler,
    },
    [fingerbot_UpMotion.ID] = {
      [fingerbot_UpMotion.commands.setFingerBotUpMotion.NAME] = setFingerbotUpMotion_handler,
    },
    [fingerbot_SustainTime.ID] = {
      [fingerbot_SustainTime.commands.setFingerBotSustainTime.NAME] = setFingerbotSustainTime_handler,
    },
    [fingerbot_Reverse.ID] = {
      [fingerbot_Reverse.commands.setFingerBotReverse.NAME] = setFingerbotReverse_handler,
    }
  },
  zigbee_handlers = {
    cluster = {
      [TUYA_CLUSTER] = {
        [0x05] = tuya_handler,
        [0x06] = tuya_handler,
      }
    },
    zdo = {
      [mgmt_bind_resp.MGMT_BIND_RESPONSE] = zdo_binding_table_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    --driverSwitched = do_configure,
    driverSwitched = do_driverSwitched,
    doConfigure = do_configure
  },
  can_handle = require("tuya-fingerbot.can_handle"),
}

return tuya_fingerbot