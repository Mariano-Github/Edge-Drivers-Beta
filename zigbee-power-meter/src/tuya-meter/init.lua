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

--DP´s of Power meter -------
-- DP ---------Name---------
--[0x01] = tuya_handler_energy,
--[0x02] = tuya_handler_produced_energy,
--[0x06] = tuya_handler_power,
--[0x66] = tuya_handler_power_direction,

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
--local utils = require"st.utils"

local TUYA_CLUSTER = 0xEF00
local DP_TYPE_RAW = "\x00"
local DP_TYPE_VALUE = "\x02"
local DP_TYPE_ENUM = "\x04"
local SeqNum = 0


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
  local cap_status = device:get_latest_state("main", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)
  if cap_status == nil then
    device:emit_event(capabilities.energyMeter.energy({value = 0, unit = "kWh" }))
  end
  cap_status = device:get_latest_state("energyConsumption", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)
  if cap_status == nil then
    device.profile.components["energyConsumption"]:emit_event(capabilities.energyMeter.energy({value = 0, unit = "kWh" }))
  end
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

  --device:configure()
end


local function tuya_handler_power(self, device, zb_rx)
  -- DP 06 (0x06) GenericBody byte 12, len 3 byte for power value
  -- DP 06 (0x06) GenericBody byte 7, len 2 byte for voltage value / 10
  -- DP 06 (0x06) GenericBody byte 9, len 3 byte for current value / 1000
  if device:get_field("power_interval") == nil then
    device:set_field("power_interval", os.time()- device.preferences.powerIntervalEvent)
  end
  local last_event_sent = os.time() - device:get_field("power_interval")
  if last_event_sent >= device.preferences.powerIntervalEvent then
    local body_len = zb_rx.body_length.value
    -- power value
    local power
    power = string.unpack(">I3", zb_rx.body.zcl_body.body_bytes, 12)
    local direction = device:get_field("power_direction")
    if direction == nil then direction = 1 end
    power = power * direction
    if device.preferences.logDebugPrint == true then
      print("<<< Power = ", power)
    end
    local cap_status = device:get_latest_state("main", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
    if cap_status ~= power then
      device:emit_event(capabilities.powerMeter.power({value = power, unit = "W" }))
    end

    --voltage value
    local voltage = string.unpack(">I2", zb_rx.body.zcl_body.body_bytes, 7) / 10
    device:emit_event(capabilities.voltageMeasurement.voltage({value = voltage, unit = "V" }))

    --current value
    local current = (string.unpack(">I3", zb_rx.body.zcl_body.body_bytes, 9) / 1000) * direction
    device:emit_event(capabilities.currentMeasurement.current({value = current, unit = "A" }))

    device:set_field("power_interval", os.time())
  end
end

local function tuya_handler_power_direction(self, device, zb_rx)
  -- DP 102 (0x66) GenericBody byte 7 is value current direction (0 or 1)
  local power_direction = zb_rx.body.zcl_body.body_bytes:byte(7)
  if power_direction == 1 then -- power produced
    if device.preferences.powerSign == "1" then --"Export->Positive and Import->Negative"
      power_direction = 1 --power export, positive power
    else
      power_direction = -1  -- power consumed, negative power
    end
  else -- power consumed, power_direction == 0
    if device.preferences.powerSign == "1" then --"Export->Negative and Import->Positive"
      power_direction = -1 -- power export, negative power
    else
      power_direction = 1 -- power consumed, positive power
    end
  end
  if device.preferences.logDebugPrint == true then
    print("<<< Power Direction = ", power_direction)
  end
  device:set_field("power_direction", power_direction)
end

local function tuya_handler_energy(self, device, zb_rx)
  -- DP  (0x01) Energy consumption byte 7, len 4 and divided by 100 for real value in kwh
  local energy = string.unpack(">I4", zb_rx.body.zcl_body.body_bytes, 7) /100
  if device.preferences.logDebugPrint == true then
    print("<<<<<<<<<<<<<<< tuya_handler_energy", energy)
  end

  local offset = device:get_field("energy_offset_energyConsumption") or 0
  if energy < offset then
    --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
    offset = 0
    device:set_field("energy_offset_energyConsumption", offset, {persist = true})
  end
  energy = energy - offset
  if device.preferences.logDebugPrint == true then
    print("<<<<<<<<<<<<<<< energy-offset", energy)
  end
  device.profile.components["energyConsumption"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))
end

local function tuya_handler_produced_energy(self, device, zb_rx)
  -- DP 2 (0x02) energy_produced, byte 7, len 4 and divided by 100 for real value in kwh

  local energy_produced = string.unpack(">I4", zb_rx.body.zcl_body.body_bytes, 7) / 100

  if device.preferences.logDebugPrint == true then
    print("<<<<<<<<<<<<<<< tuya_handler_energy", energy_produced)
  end

  local offset = device:get_field("energy_offset_produced") or 0
  if energy_produced < offset then
    --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
    offset = 0
    device:set_field("energy_offset_produced", offset, {persist = true})
  end
  energy_produced = energy_produced - offset
  if device.preferences.logDebugPrint == true then
    print("<<<<<<<<<<<<<<< energy_produced-offset=", energy_produced)
  end
  device:emit_event(capabilities.energyMeter.energy({value = energy_produced, unit = "kWh" }))
end

-- Tuya report handler
local function tuya_handler(self, device, zb_rx)

  if device.preferences.logDebugPrint == true then
    print("<<<< Tuya handler >>>>")
  end

  local dp_table = {
    --[0x65] = tuya_handler_power_1,
    [0x01] = tuya_handler_energy,
    [0x02] = tuya_handler_produced_energy,
    [0x06] = tuya_handler_power, -- power + current + voltage
    [0x66] = tuya_handler_power_direction,
  }

  -- cluster: 0xEF00 in this device:
  -- ZCLCommandId: 0x02 >, GenericBody: 00 11 66 04 00 01 00 > >
  -- dp in this device 0x66 and byte 7 is power direction 00 = consumed, 001 = produced

  -- ZCLCommandId: 0x02 >, GenericBody:  00 CB 06 00 00 08 09 28 00 00 BE 00 00 1D > >
  -- dp 0x06, raw type. byte 12,13 14 is power raw value (1D = 29w)
  -- Positive power = exported or produced power
  -- negative power = imported or Consumed power

  -- DP 06 (0x06) GenericBody byte 7, len 2 byte for voltage value / 10
  -- DP 06 (0x06) GenericBody byte 9, len 3 byte for current value / 1000

  -- ZCLCommandId: 0x02 >, GenericBody: 00 DE 01 02 00 04 00 00 00 04 > >
  -- dp 0x01, integer type. byte 10, len 4, is energy consumed /100 in kwh, 08 = 40wh

  -- ZCLCommandId: 0x02 >, GenericBody: 00 DE 02 02 00 04 00 00 00 08 > >
  -- dp 0x02, integer type. byte 10, len 4 is energy produced /100 in kwh, 08 = 80wh

  -- ZCLCommandId: 0x02 >, GenericBody: 00 EE 65 02 00 04 00 00 00 1D > >
  -- dp 0x65 and byte 7, len 4 is power value = value (1D = 29w)
  -- same value of dp 0x06 in integer type (0x02)
  
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

-- Reset energy values
local function resetEnergyMeter_handler(driver, device, command)
  local _,last_reading = device:get_latest_state(command.component, capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME, 0, {value = 0, unit = "kWh"})
  if command.component == "main" then
    if last_reading.value ~= 0 then
      local offset = device:get_field("energy_offset_produced") or 0
      device:set_field("energy_offset_produced", last_reading.value+offset, {persist = true})
    end
  else
    if last_reading.value ~= 0 then
      local offset = device:get_field("energy_offset_energyConsumption") or 0
      device:set_field("energy_offset_energyConsumption", last_reading.value+offset, {persist = true})
    end
  end
  device:emit_component_event({id = command.component}, capabilities.energyMeter.energy({value = 0.0, unit = "kWh"}))
end

--- do_driverSwitched
local function do_driverSwitched(self, device) --23/12/23
  print("<<<< DriverSwitched >>>>")
   device.thread:call_with_delay(3, function(d)
     do_configure(self, device)
   end, "configure") 
 end

local tuya_meter = {
  NAME = "Tuya meter bidirectional",
  capability_handlers = {
    [capabilities.energyMeter.ID] = {
      [capabilities.energyMeter.commands.resetEnergyMeter.NAME] = resetEnergyMeter_handler,
    },
  },
  zigbee_handlers = {
    cluster = {
      [TUYA_CLUSTER] = {
        [0x02] = tuya_handler,
        --[0x06] = tuya_handler,
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
  can_handle = require("tuya-meter.can_handle"),
}

return tuya_meter