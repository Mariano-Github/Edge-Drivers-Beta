local data_types = require "st.zigbee.data_types"
local zcl_messages = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local constants = require "st.zigbee.constants"
local generic_body = require "st.zigbee.generic_body"
local read_attribute = require "st.zigbee.zcl.global_commands.read_attribute"
local utils = require "st.utils"
local capabilities = require "st.capabilities"

local backlightLevel = capabilities["fabricbypass11616.backlightLevel"]

local commands = {}

local TUYA_CLUSTER = 0xEF00

-- DP data format: dpid(1 byte) + type(1 byte) + len(2 bytes) + value(1/2/4/N bytes)
local tuyaTypes = {
  raw = 0x00,     -- Byte(s): N
  bool = 0x01,    -- Byte(s): 1
  value = 0x02,   -- Byte(s): 4 big-endian
  string = 0x03,  -- Byte(s): N
  enum = 0x04,    -- Byte(s): 1
  bitmap = 0x05,  -- Byte(s): 1, 2, or 4 big-endian
}

-- TUYA commands
local TUYA_REQUEST =      0x00
local TUYA_RESPONE =      0x01
local TUYA_REPORT =       0x02
local TUYA_QUERY =        0x03
local TUYA_TIME_SYNCHRONISATION = 0x24


local tuyaDatapoints = {
  switch = 0x01,
  thermostatMode = 0x04,
  thermostatOperatingState = 0x65,
  FrostProtection = 0x66,
  SetTemp = 0x02,
  MaxTemp = 0x0F,
  CurrentTemp = 0x03,
  TempCorrection = 0x13,
  WeeklyProcedure = 0x6D,
  WorkingDaySetting = 0x68,
  FactoryReset = 0x67,
  ChildLock = 0x09,
  SensorSelection = 0x6A,
  FaultAlarm = 0x0B,
  Hysteresis = 0x6B,
  ProtectionTempLimit = 0x66,
  BackplaneBrightness = 0x6E,
}

local seq_no = 0x0

--[[ local BackplaneBrightness = {
  Off = 0,
  Low = 1,
  Medium = 2,
  High = 3
} ]]

--[[commands.supportedThermostatModes = {
  "auto",           -- scheduled mode
  "manual",         -- manual mode
  "autowithreset"   -- auto only once
}]]

commands.thermostatWeekFormat = {
  disabled = 0,
  mondayToFriday = 1,
  mondayToSaturday = 2,
  mondayToSunday = 3
}

local function getDataPointId(name)
  for key, value in pairs(tuyaDatapoints) do
    if key == name then return value end
  end
end

local function getDataPointName(id)
  for key, value in pairs(tuyaDatapoints) do
    if value == id then return key end
  end
end

local function getDataTypeName(id)
  for key, value in pairs(tuyaTypes) do
    if value == id then return key end
  end
end

local function split(str, sep)
  local t = {}
  for s in string.gmatch(str, "([^" .. sep .. "]+)") do
    table.insert(t, s)
  end
  return t
end

-- Tuya command frame
  --seq: DataType.uint16
  --dp: DataType.uint8
  --datatype: DataType.uint8
  --length: DataType.uint16
  --data: Buffer

local function sendCommand(device, dpId, type, data)
  local seq = string.pack(">I2", seq_no)
  local header_args = { cmd = data_types.ZCLCommandId(TUYA_REQUEST)}
  local zclh = zcl_messages.ZclHeader(header_args)
  zclh.frame_ctrl:set_cluster_specific()          -- 01	Command is specific to a cluster.
  zclh.frame_ctrl:set_direction_server()          -- 00 Gateway to Zigbee device.
  zclh.frame_ctrl:set_disable_default_response()  -- No response confirmation
  local addrh = messages.AddressHeader(
    constants.HUB.ADDR,
    constants.HUB.ENDPOINT,
    device:get_short_address(),
    device:get_endpoint(TUYA_CLUSTER),
    constants.HA_PROFILE_ID,
    TUYA_CLUSTER
  )
  local body = seq .. string.pack("B", dpId) .. string.pack("B", type) .. string.pack(">I2", string.len(data)) .. data
  local payload_body = generic_body.GenericBody(body)
  local message_body = zcl_messages.ZclMessageBody({
    zcl_header = zclh,
    zcl_body = payload_body
  })
  local send_message = messages.ZigbeeMessageTx({
    NAME = "TUYA_CMD",
    address_header = addrh,
    body = message_body
  })
  device:send(send_message)
  seq_no = (seq_no + 1) % 0x10000
end

local function sendSync(device, body)
  local seq = string.pack(">I2", seq_no)
  local header_args = { cmd = data_types.ZCLCommandId(TUYA_TIME_SYNCHRONISATION)}
  local zclh = zcl_messages.ZclHeader(header_args)
  zclh.frame_ctrl:set_cluster_specific()          -- 01	Command is specific to a cluster.
  zclh.frame_ctrl:set_direction_server()          -- 00 Gateway to Zigbee device.
  zclh.frame_ctrl:set_disable_default_response()  -- No response
  local addrh = messages.AddressHeader(
    constants.HUB.ADDR,
    constants.HUB.ENDPOINT,
    device:get_short_address(),
    device:get_endpoint(TUYA_CLUSTER),
    constants.HA_PROFILE_ID,
    TUYA_CLUSTER
  )
  local payload_body = generic_body.GenericBody(seq .. body)
  local message_body = zcl_messages.ZclMessageBody({
    zcl_header = zclh,
    zcl_body = payload_body
  })
  local send_message = messages.ZigbeeMessageTx({
    NAME = "TUYA_TIME_SYNC",
    address_header = addrh,
    body = message_body
  })
  device:send(send_message)
  seq_no = (seq_no + 1) % 0x10000

end

function commands.read_attributes(device, cluster_id, attr_ids)
  local read_body = read_attribute.ReadAttribute(attr_ids)
  local zclh = zcl_messages.ZclHeader({
    cmd = data_types.ZCLCommandId(TUYA_QUERY)
  })
  local addrh = messages.AddressHeader(
      constants.HUB.ADDR,
      constants.HUB.ENDPOINT,
      device:get_short_address(),
      device:get_endpoint(cluster_id),
      constants.HA_PROFILE_ID,
      cluster_id
  )
  local message_body = zcl_messages.ZclMessageBody({
    zcl_header = zclh,
    zcl_body = read_body
  })
  local send_message = messages.ZigbeeMessageTx({
    address_header = addrh,
    body = message_body
  })
  device:send(send_message)
  seq_no = (seq_no + 1) % 0x10000
end

function commands.switch(device, value)
  local dpId = getDataPointId("switch")
  if value then
    sendCommand(device, dpId, tuyaTypes.bool, "\x01")
  else
    sendCommand(device, dpId, tuyaTypes.bool, "\x00")
  end
end

function commands.setHeatingSetpoint(device, value)
  local dpId = getDataPointId("SetTemp")
  sendCommand(device, dpId, tuyaTypes.value, string.pack(">i", value * 10))
end

function commands.setTempCorrection(device, value)
  local dpId = getDataPointId("TempCorrection")
  sendCommand(device, dpId, tuyaTypes.value, string.pack(">i", value * 10))
end

function commands.setMaxTemperature(device, value)
  local dpId = getDataPointId("MaxTemp")
  sendCommand(device, dpId, tuyaTypes.value, string.pack(">i", value * 10))
end

function commands.setHysteresis(device, value)
  local dpId = getDataPointId("Hysteresis")
  sendCommand(device, dpId, tuyaTypes.value, string.pack(">i", value * 10))
end

function commands.setFrostProtection(device, value)
  local dpId = getDataPointId("FrostProtection")
  if value == "1" then
    sendCommand(device, dpId, tuyaTypes.bool, "\x01")
  elseif value == "0" then
    sendCommand(device, dpId, tuyaTypes.bool, "\x00")
  end
end

function commands.setChildLock(device, value)
  local dpId = getDataPointId("ChildLock")
  if value == true then
    sendCommand(device, dpId, tuyaTypes.bool, "\x01")
  else
    sendCommand(device, dpId, tuyaTypes.bool, "\x00")
  end
end

function commands.setBackplaneBrightness(device, value)
  local dpId = getDataPointId("BackplaneBrightness")
  sendCommand(device, dpId, tuyaTypes.enum, string.pack("B", value))
  -- for value = 0 device does not response state
  if value == 0 then 
    device:emit_event(backlightLevel.level({value = value}, {visibility = {displayed = false}}))
  end

end

function commands.factoryReset(device)
  local dpId = getDataPointId("FactoryReset")
  sendCommand(device, dpId, tuyaTypes.bool, "\x01")
end

function commands.setSensorSelection(device, value)
  local dpId = getDataPointId("SensorSelection")  -- 0 Internal, 1 External, 2 Both
  if value == "0" then
    sendCommand(device, dpId, tuyaTypes.enum, "\x00")
  elseif value == "1" then
    sendCommand(device, dpId, tuyaTypes.enum, "\x01")
  elseif value == "2" then
    sendCommand(device, dpId, tuyaTypes.enum, "\x02")
  end
end

function commands.setThermostatMode(device, mode)
  local dpId = getDataPointId("thermostatMode")
  if mode == "manual" then
    if device:get_manufacturer() == "_TZE200_viy9ihs7" then --invert manual and auto mode
      sendCommand(device, dpId, tuyaTypes.enum, "\x00")
    else
      sendCommand(device, dpId, tuyaTypes.enum, "\x01")
    end
  elseif mode == "auto" then
    if device:get_manufacturer() == "_TZE200_viy9ihs7" then --invert manual and auto mode
      sendCommand(device, dpId, tuyaTypes.enum, "\x01")
    else
      sendCommand(device, dpId, tuyaTypes.enum, "\x00")
    end
  elseif mode == "autowithreset" then
    sendCommand(device, dpId, tuyaTypes.enum, "\x02")
  end
end

function commands.setPrograms(device, programs)
  local dpId = getDataPointId("WeeklyProcedure")
  local raw = ""
  print("<<<< programs",programs)
  local ps = split(programs, ";")
  if ps ~= nil and #ps == 8 then
    for i= 1, 8 do
      ps[i] = ps[i]:match "^%s*(.-)%s*$"  -- trim() each part
      local sp = split(ps[i], " ")
      local time = split(sp[1],":")
      local hour = tonumber(time[1])
      local minute = tonumber(time[2])
      local temp = tonumber(string.format("%.1f", sp[2]))
      if hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 and temp >= 5 and temp <= 35 then
        raw = raw .. string.pack("b", hour * 1) .. string.pack("b", minute * 1) .. string.pack(">I2", temp * 10)
      else
        return nil
      end
    end
  else
    return nil
  end
  sendCommand(device, dpId, tuyaTypes.raw, raw)
  return 0
end

function commands.setSchedule(device, value)
  local dpId = getDataPointId("WorkingDaySetting")
  sendCommand(device, dpId, tuyaTypes.enum, string.pack("B",value))
end

function commands.stringify_command(cmd, multiline)
  local str = "Tuya command >>> \n"
  str = str .. "Seq:" .. string.gsub(utils.get_print_safe_string(cmd.seq), "\\x", " ") .. ", \n" -- in Hex
  str = str .. "Name: " .. cmd.dpName .. ", \n"                                           -- string
  str = str .. "ID: " .. string.format("%X", tostring(cmd.dpid)) .. ", \n"                -- in Hex
  str = str .. "Type: " .. getDataTypeName(cmd.dataType) .. ", \n"                        -- string
  str = str .. "Length: " .. tostring(cmd.len) .. ", \n"                                  -- in decimal
  str = str .. "Data:" .. string.gsub(utils.get_print_safe_string(cmd.data), "\\x", " ")  -- in Hex
  if not multiline then str = string.gsub(str, "\n", "") end                              -- remove newlines
  return str
end

function commands.syncDeviceTime(device, offset)
  if device:get_manufacturer() == "_TZE204_xnbkhhdr" then
    print("=========== Syncing thermostat time ===========")
    local localTime = os.time() + (device.preferences.localTimeOffset * 3600)
    sendSync(device, string.pack(">I", localTime) .. string.pack(">I", os.time() + (offset * 3600)))
  end
end

function commands.getCommand(body)
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

return commands