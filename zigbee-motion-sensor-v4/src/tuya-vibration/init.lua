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

local PowerConfiguration = clusters.PowerConfiguration
local TUYA_CLUSTER = 0xEF00
local DP_TYPE_VALUE = "\x02"
local DP_TYPE_ENUM = "\x04"

-- TUYA commands
local TUYA_REQUEST =      0x00
local TUYA_RESPONE =      0x01
local TUYA_REPORT =       0x02
local TUYA_QUERY =        0x03
local DEFAULT_RESPONSE =  0X0B

local SeqNum = 0
local ZigbeeConstants = require "st.zigbee.constants"
local data_types = require "st.zigbee.data_types"
local ZigbeeZcl = require "st.zigbee.zcl"
local generic_body = require "st.zigbee.generic_body"

-- custom capabilities
local sensor_Sensitivity = capabilities["legendabsolute60149.sensorSensitivity"]

local TUYA_VIBRATION_SENSOR_FINGERPRINTS = {
    { mfr = "_TZE200_iba1ckek", model = "TS0601" },
}

local is_tuya_vibration = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(TUYA_VIBRATION_SENSOR_FINGERPRINTS) do
        if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          local subdriver = require("tuya-vibration")
          return true, subdriver
        end
    end
  end
    return false
end

-- Send command to cluster EF00
local function SendCommand(device, DpId, Type, Value, command)
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
  local zclh = ZigbeeZcl.ZclHeader({cmd = data_types.ZCLCommandId(command)})
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
  SendCommand(device, "\x68", DP_TYPE_ENUM, "\x00", TUYA_QUERY)
end

local do_configure = function(self, device)
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 3600, 1))
  device:send(clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))

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
  -- emit signal metrics
  signal.metrics(device, zb_rx)
  
  local battery_pc = zb_rx.body.zcl_body.body_bytes:byte(10)
  device:emit_event(capabilities.battery.battery(battery_pc))
end

local function tuya_handler_motion(self, device, zb_rx)

  -- emit signal metrics
  signal.metrics(device, zb_rx)

  local event_table = {
    [0x01] = capabilities.motionSensor.motion.active,
    [0x00] = capabilities.motionSensor.motion.inactive,
  }
  local motion_active = zb_rx.body.zcl_body.body_bytes:byte(7)
  local ev = event_table[motion_active]
  if ev then
    device:emit_event(ev())
  end
end

local function tuya_handler_sensitivity(self, device, zb_rx)
  local event_table = {
    [0x00] = "Low",
    [0x01] = "Middle",
    [0x02] = "High"
  }
  local motion_active = zb_rx.body.zcl_body.body_bytes:byte(7)
  local sensitivity = event_table[motion_active]
  if sensitivity then
    device:emit_event(sensor_Sensitivity.sensorSensitivity(sensitivity))
  end
end

local function tuya_handler(self, device, zb_rx)

  local dp_table = {
    [0x01] = tuya_handler_motion,
    [0x69] = tuya_handler_battery,
    [0x07] = tuya_handler_motion, -- Tilt detection
    [0x68] = tuya_handler_sensitivity,
    -- Zigbee EUI + Network ID
    --[0xe2] = GenericBody:  00 01 E2 55 44 33 22 11 00 11 00
  }
  local version = zb_rx.body.zcl_body.body_bytes:byte(1)
  local sequence = zb_rx.body.zcl_body.body_bytes:byte(2)
  local dp = zb_rx.body.zcl_body.body_bytes:byte(3)
  print ("<<< dp Number:", dp)
  local dp_handler = dp_table[dp]
  if dp_handler then
    dp_handler(self, device, zb_rx)
  end
end

-- preferences update
local function do_preferences(self, device, event, args)
  print("***** infoChanged *********")
  
   for id, value in pairs(device.preferences) do
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      print("<< Preference changed name:", id, "old:", oldPreferenceValue, "new:", newParameterValue)
      if  id == "motionSensitivity2" then

        --DP 104 (0x68) sensitivity 0 = low, 1= middle, 2 = high
        local sensitivity_value = "\x01"
        local sensitivity = "Middle"
        if newParameterValue == "0" then
          sensitivity_value = "\x00"
          sensitivity = "Low"
        elseif newParameterValue == "2" then
          sensitivity_value = "\x02"
          sensitivity = "High"
        end
        device:emit_event(sensor_Sensitivity.sensorSensitivity(sensitivity))

        SendCommand(device, "\x68", DP_TYPE_ENUM, sensitivity_value, TUYA_REQUEST)
        SendCommand(device, "\x68", DP_TYPE_ENUM, sensitivity_value, TUYA_QUERY)
      elseif id == "batteryType" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.type(newParameterValue))
      elseif id == "batteryQuantity" and newParameterValue ~= nil then
        device:emit_event(capabilities.battery.quantity(newParameterValue))
      end
    end
  end
end


local tuya_vibration_sensor = {
  NAME = "tuya vibration sensor",
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
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = device_added,
    }
  },
  lifecycle_handlers = {
    added = device_added,
    doConfigure = do_configure,
    infoChanged = do_preferences,
  },
  can_handle = is_tuya_vibration
}

return tuya_vibration_sensor