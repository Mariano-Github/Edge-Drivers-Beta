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

--[[tuyaDatapoints: [
  [113, (x71)'ac_frequency', tuya.valueConverter.raw],
  [108, (x6C)'power_a', tuya.valueConverter.raw],
  [111, (x6F)'power_b', tuya.valueConverter.raw],
  [009, (x09)'power', tuya.valueConverter.raw],
  [106, (x6A)'voltage', tuya.valueConverter.divideBy10],
  [107, (x6B)'current_a', tuya.valueConverter.divideBy1000],
  [110, (x6E)'current_b', tuya.valueConverter.divideBy1000],
  [105, (x69)'current', tuya.valueConverter.divideBy1000],
  [109, (x60)'power_factor_a', tuya.valueConverter.raw],% , for 0 to 1 range divide by 100
  [112, (x70)'power_factor_b', tuya.valueConverter.raw],% , for 0 to 1 range divide by 100
  [001, (x01)'energy', tuya.valueConverter.divideBy100],
  [101, (x65)'energy_a', tuya.valueConverter.divideBy100],
  [103, (x67)'energy_b', tuya.valueConverter.divideBy100],
  [102, (x66)'energy_produced_a', tuya.valueConverter.divideBy100],
  [104, (x68)'energy_produced_b', tuya.valueConverter.divideBy100],
  [002, (x02)'energy_produced', tuya.valueConverter.divideBy100],
],]]

local constants = require "st.zigbee.constants"
local capabilities = require "st.capabilities"
local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"
local zdo_messages = require "st.zigbee.zdo"

local ZigbeeZcl = require "st.zigbee.zcl"
local ZigbeeConstants = require "st.zigbee.constants"
local data_types = require "st.zigbee.data_types"
local generic_body = require "st.zigbee.generic_body"
--local utils = require"st.utils"

local TUYA_CLUSTER = 0xEF00
local DP_TYPE_RAW = "\x00"
local DP_TYPE_VALUE = "\x02"
local DP_TYPE_ENUM = "\x04"
local SeqNum = 0

local power_Factor = capabilities["legendabsolute60149.powerFactor"]
local ac_Frequency = capabilities["legendabsolute60149.acFrequency"]


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

local function device_init(self, device)

  if device.preferences.intallationType ==  "independetTwoClamp" then
    device:try_update_metadata({profile = "power-meter-energy-solar-dual-2-clamp"})
  elseif device.preferences.intallationType ==  "exportProduct" then
    device:try_update_metadata({profile = "power-meter-energy-solar-dual-exp-prod"})
  elseif device.preferences.intallationType ==  "exportConsumption" then
    device:try_update_metadata({profile = "power-meter-energy-solar-dual-exp-cons"})
  else
    device:try_update_metadata({profile = "power-meter-energy-solar-dual"})
  end
  local cap_status = device:get_latest_state("main", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)
  if cap_status == nil then
    cap_status = 0
    device:emit_event(capabilities.energyMeter.energy({value = 0, unit = "kWh" }))
  end
  device:set_field("energy_0x65", cap_status)

  cap_status = device:get_latest_state("energyConsumption", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)
  if cap_status == nil then
    cap_status = 0
    device.profile.components["energyConsumption"]:emit_event(capabilities.energyMeter.energy({value = 0, unit = "kWh" }))
  end
  device:set_field("energy_0x66", cap_status)

  cap_status = device:get_latest_state("energyProductionTotal", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)
  if cap_status == nil then
    cap_status = 0
    device.profile.components["energyProductionTotal"]:emit_event(capabilities.energyMeter.energy({value = 0, unit = "kWh" }))
  end
  device:set_field("energy_0x67", cap_status)

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
  -- DP  (0x09) power TOTAL byte 7, len 4 real value in w
  -- DP  (0x6C) power A: byte 7, len 4 and real value in w
  -- DP  (0x6F) power B: byte 7, len 4 and real value in w

  -- example:
  --GenericBody:  00 0B 6F 02 00 04 FF FF FF F8 > >
  --byte(3) = dp = 6F
  --byte(6) = len data = 4 byte
  --byte(7) = data len 4 byte = FF FF FF F8 is a negative value

  local dp = zb_rx.body.zcl_body.body_bytes:byte(3)

    local body_len = zb_rx.body_length.value
    -- power value
    local power
    power = string.unpack(">I4", zb_rx.body.zcl_body.body_bytes, 7)
    -- 2 complemat for negative values 4 bytes values
    if power > 2147483647 then
      power = power - 4294967296
    end
    if device.preferences.logDebugPrint == true then
      print("<<< Power = ", power)
    end
    
    if dp == 0x09 then --algebraic sum of clamp A+B
      device:set_field("power_0x09", power)
      if device.preferences.intallationType == "exportProduct" or device.preferences.intallationType == nil then
        -- This case power comsuption is algebraic subtract of clamp B (0x6F)- clamp A (0x6C)
        --calculate power consumption
        if device:get_field("power_0x09") == nil then device:set_field("power_0x09", 0) end
        if device:get_field("power_0x6F") == nil then device:set_field("power_0x6F", 0) end
        if device:get_field("power_0x6C") == nil then device:set_field("power_0x6C", 0) end
        power =  device:get_field("power_0x6F") - device:get_field("power_0x6C")
        local cap_status = device:get_latest_state("energyConsumption", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
        if cap_status ~= power then
          --device:emit_component_event({id = "energyConsumption"}, capabilities.powerMeter.power({value = math.abs(power), unit = "W" }))
          device:emit_component_event({id = "energyConsumption"}, capabilities.powerMeter.power({value =power, unit = "W" }))
        end
      elseif device.preferences.intallationType == "exportConsumption" or device.preferences.intallationType == "independetTwoClamp" then
        -- This case solar power procution is algebraic sum of clamp B (0x6F)+ clamp A (0x6C) = dp(0x09)
        if device.preferences.intallationType == "independetTwoClamp" then
          local cap_status = device:get_latest_state("energyConsumptionTotal", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
          if cap_status ~= power then
            device:emit_component_event({id = "energyConsumptionTotal"}, capabilities.powerMeter.power({value = power, unit = "W" }))
          end
        else
          local cap_status = device:get_latest_state("energyProductionTotal", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
          if cap_status ~= power then
            device:emit_component_event({id = "energyProductionTotal"}, capabilities.powerMeter.power({value = power, unit = "W" }))
          end
        end
      end

    elseif dp == 0x6C then -- Power A
      device:set_field("power_0x6C", power)
      -- This case alwais power export is value clamp A = dp(0x6C)
      local cap_status = device:get_latest_state("main", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
      if cap_status ~= power then
        device:emit_component_event({id = "main"}, capabilities.powerMeter.power({value = power, unit = "W" }))
      end

    elseif dp == 0x6F then -- Power B
      device:set_field("power_0x6F", power)
      if device.preferences.intallationType == "exportConsumption" or device.preferences.intallationType == "independetTwoClamp" then 
        -- This case power comsuption is value of clamp B = dp(0x6F)
        local cap_status = device:get_latest_state("energyConsumption", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
        if cap_status ~= power then
          device:emit_component_event({id = "energyConsumption"}, capabilities.powerMeter.power({value = power, unit = "W" }))
        end

      elseif device.preferences.intallationType == "exportProduct" or device.preferences.intallationType == nil then 
        -- This case the total solar production is value of clamp B = dp(0x6F)
        if device.preferences.intallationType == "independetTwoClamp" then
          local cap_status = device:get_latest_state("energyConsumptionTotal", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
          if cap_status ~= power then
            device:emit_component_event({id = "energyConsumptionTotal"}, capabilities.powerMeter.power({value = power, unit = "W" }))
          end
        else
          local cap_status = device:get_latest_state("energyProductionTotal", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
          if cap_status ~= power then
            device:emit_component_event({id = "energyProductionTotal"}, capabilities.powerMeter.power({value = power, unit = "W" }))
          end
        end
      end
    end
end

-- tuya energy handler
local function tuya_handler_energy(self, device, zb_rx)
  -- DP 1 (0x01) Energy consumption TOTAL byte 7, len 4 and divided by 100 for real value in kwh
  -- DP 101 (0x65) Energy consumption A: byte 7, len 4 and divided by 100 for real value in kwh
  -- DP 103 (0x67) Energy consumption B: byte 7, len 4 and divided by 100 for real value in kwh

  -- DP 2 (0x02) energy_produced TOTAL, byte 7, len 4 and divided by 100 for real value in kwh
  -- DP 102 (0x66) energy_produced A, byte 7, len 4 and divided by 100 for real value in kwh
  -- DP 104 (0x08) energy_produced B, byte 7, len 4 and divided by 100 for real value in kwh

  -- Example:
  --GenericBody:  00 05 66 02 00 04 00 01 4C 99 > >
  --byte(3) = dp = 66
  --byte(6) = len data = 4 byte
  --byte(7) = data len 4 byte = 00 01 4C 99 value = 0x14C99 = 85145 /100 kwh = 851.45 kwh

  local dp = zb_rx.body.zcl_body.body_bytes:byte(3)

  local energy = string.unpack(">I4", zb_rx.body.zcl_body.body_bytes, 7) /100
  if device.preferences.logDebugPrint == true then
    print("<<<<<<<<<<<<<<< tuya_handler_energy", energy)
  end

  if device.preferences.intallationType == "exportConsumption" then
    local offset = 0
    if dp == 0x67 then -- my (production solar 0x65 + 0x67 - 0x66)(component == "energyProductionTotal")
      offset = device:get_field("offset_energyProductionTotal_exportConsumption") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyProductionTotal_exportConsumption", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x67", energy) -- my total conpsumtion circuit B (+) (consumo total casa solar + red)
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      -- calculat total energy surplus
      if device:get_field("energy_0x65") == nil then device:set_field("energy_0x65", 0) end
      if device:get_field("energy_0x66") == nil then device:set_field("energy_0x66", 0) end
      if device:get_field("energy_0x67") == nil then device:set_field("energy_0x67", 0) end
      local total_energy_surplus =  device:get_field("energy_0x67") + device:get_field("energy_0x65") - device:get_field("energy_0x66")
      device.profile.components["energyProductionTotal"]:emit_event(capabilities.energyMeter.energy({value = total_energy_surplus, unit = "kWh" }))

    elseif dp == 0x65 then -- my production solar excedentes (+) circuit A
      offset = device:get_field("offset_main_exportConsumption") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_main_exportConsumption", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x65", energy) -- my production solar excedentes (+) circuit A
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["main"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))

    elseif dp == 0x66 then -- my consumption circuit A (+) (consumo casa de la red)
      offset = device:get_field("offset_energyConsumption_exportConsumption") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyConsumption_exportConsumption", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x66", energy) -- my consumption circuit A (+) (consumo casa de la red)
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["energyConsumption"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))
    end

  elseif device.preferences.intallationType == "exportProduct" then
    local offset = 0
    if dp == 0x67 then -- my comsuption value circuit B (+) (procution solar total)
      offset = device:get_field("offset_energyProductionTotal_exportProduct") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyProductionTotal_exportProduct", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x67", energy) -- my comsuption value circuit B (+) (procution solar total))
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["energyProductionTotal"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))

    elseif dp == 0x65 then -- my production solar excedentes (+) circuit A
      offset = device:get_field("offset_main_exportProduct") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_main_exportProduct", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x65", energy) -- my production solar excedentes (+) circuit A
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["main"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))

    elseif dp == 0x66 then -- my consumption circuit A (+) (consumo casa de la red)
      offset = device:get_field("offset_energyConsumption_exportProduct") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyConsumption_exportProduct", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x66", energy) -- my consumption circuit A (+) (consumo casa de la red)
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["energyConsumption"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))
    end
  elseif device.preferences.intallationType == "independetTwoClamp" then
    local offset = 0
    if dp == 0x67 then -- my comsuption value circuit B (+) (comsuption value clamp B)
      offset = device:get_field("offset_energyConsumption_independetTwoClamp") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyConsumption_independetTwoClamp", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x67", energy) -- my comsuption value circuit B (+) (comsuption value clamp B)
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["energyConsumption"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))

    elseif dp == 0x65 then -- my production solar excedentes (+) circuit A
      offset = device:get_field("offset_main_independetTwoClamp") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_main_independetTwoClamp", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x65", energy) -- my production solar excedentes (+) circuit A
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["main"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))

    elseif dp == 0x01 then -- my consumption circuit clamp A + clamp B
      offset = device:get_field("offset_energyConsumptionTotal_independetTwoClamp") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyConsumptionTotal_independetTwoClamp", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x01", energy) -- my consumption circuit clamp A + clamp B
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["energyConsumptionTotal"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))

    elseif dp == 0x66 then -- my production value circuit A (+)
      offset = device:get_field("offset_energyProductionA_independetTwoClamp") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyProductionA_independetTwoClamp", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x66", energy) -- my production value circuit A (+)
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["energyProductionA"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))

    elseif dp == 0x68 then -- my production value (+) circuit B
      offset = device:get_field("offset_energyProductionB_independetTwoClamp") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyProductionB_independetTwoClamp", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x68", energy) -- my production (+) circuit B
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["energyProductionB"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))

    elseif dp == 0x02 then -- my production circuit clamp A + clamp B
      offset = device:get_field("offset_energyProductionTotal_independetTwoClamp") or 0
      if energy < offset then
        --- somehow our value has gone below the offset, so we'll reset the offset, since the device seems to have
        offset = 0
        device:set_field("offset_energyProductionTotal_independetTwoClamp", offset, {persist = true})
      end
      energy = energy - offset
      device:set_field("energy_0x02", energy) -- my production circuit clamp A + clamp B
      if device.preferences.logDebugPrint == true then
        print("<<<<<<<<<<<<<<< energy-offset", energy)
      end
      device.profile.components["energyProductionTotal"]:emit_event(capabilities.energyMeter.energy({value = energy, unit = "kWh" }))
    end
  end
end

--voltage_handler
local function voltage_handler(self, device, zb_rx)
  -- DP 106 (0x6A) voltage, byte 7, len 4 and divided by 10 for real value in V
 --voltage value
 local voltage = string.unpack(">I4", zb_rx.body.zcl_body.body_bytes, 7) / 10
 device:emit_event(capabilities.voltageMeasurement.voltage({value = voltage, unit = "V" }))
end

--freq_handler
local function freq_handler(self, device, zb_rx)
  -- DP 113 (0x71) frequency, byte 7, len 4 a for real value in value 0 to 1
 --frequency value
 local frequency = string.unpack(">I4", zb_rx.body.zcl_body.body_bytes, 7)
 device:emit_event(ac_Frequency.acFrequency({value = frequency, unit = "Hz" }))

end

--current_handler
local function current_handler(self, device, zb_rx)
  -- DP 105 (0x69) current TOTAL, byte 7, len 4 and divided by 1000 for real value in A
  -- DP 107 (0x6B) current A, byte 7, len 4 and divided by 1000 for real value in A
  -- DP 110 (0x6E) current B, byte 7, len 4 and divided by 1000 for real value in A

  --current value
  local dp = zb_rx.body.zcl_body.body_bytes:byte(3)
  local current = (string.unpack(">I4", zb_rx.body.zcl_body.body_bytes, 7) / 1000)
  if dp == 0x69 then -- current total
    if device.preferences.intallationType == "independetTwoClamp" then
      device:emit_component_event({id = "energyConsumptionTotal"},capabilities.currentMeasurement.current({value = current, unit = "A" }))
    else
      device:emit_component_event({id = "energyProductionTotal"},capabilities.currentMeasurement.current({value = current, unit = "A" }))
    end
  elseif dp == 0x6B then -- current A
    device:emit_event(capabilities.currentMeasurement.current({value = current, unit = "A" }))
  elseif dp == 0x6E then -- current B
    device:emit_component_event({id = "energyConsumption"},capabilities.currentMeasurement.current({value = current, unit = "A" }))
  end
end

--pw_factor_handler
local function pw_factor_handler(self, device, zb_rx)
  -- DP 109 (0x6D) current A, byte 7, len 4  and divided by 100 for real value in A
  -- DP 112 (0x70) current B, byte 7, len 4  and divided by 100 for real value in A

  --current value
  local dp = zb_rx.body.zcl_body.body_bytes:byte(3)
  local p_factor = string.unpack(">I4", zb_rx.body.zcl_body.body_bytes, 7) /100
  if dp == 0x6D then -- p.factor A
    device:emit_event(power_Factor.powerFactor(p_factor))
  elseif dp == 0x70 then -- p.factor B
    device:emit_component_event({id = "energyConsumption"},power_Factor.powerFactor(p_factor))
  end
end

-- Tuya report handler
local function tuya_handler(self, device, zb_rx)
  if device.preferences.logDebugPrint == true then
    print("<<<< Tuya handler >>>>")
  end

  local dp_table = {
    [0x02] = tuya_handler_energy, --ENERGY PROD TOTAL
    [0x66] = tuya_handler_energy, --ENERGY  PROD A,
    [0x68] = tuya_handler_energy, --ENERGY  PROD B,
    [0x01] = tuya_handler_energy, -- ENERGY CONSUM TOTAL
    [0x65] = tuya_handler_energy, --ENERGY  CONSUM A
    [0x67] = tuya_handler_energy, -- ENERGY CONSUM B
    [0x6C] = tuya_handler_power, --POWER A
    [0x6F] = tuya_handler_power, --POWER B
    [0x09] = tuya_handler_power, --POWER TOTAL
    [0x71] = freq_handler, --FREQ
    [0x6A] = voltage_handler, --VOLT
    [0x6B] = current_handler, --CURRENT A
    [0x6E] = current_handler, --CURRENT B
    [0x69] = current_handler, --CURRENT TOTAL
    [0x6D] = pw_factor_handler, --POWER FACTOR A
    [0x70] = pw_factor_handler, --POWER FACTOR B
  }

  -- cluster: 0xEF00 in this device:
  -- Examples:
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

  -- call do function handler
  local dp_handler = dp_table[dp]
  if dp_handler then
    dp_handler(self, device, zb_rx)
  end

end

-- Reset energy values
local function resetEnergyMeter_handler(driver, device, command)
  local _,last_reading = device:get_latest_state(command.component, capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME, 0, {value = 0, unit = "kWh"})
  if device.preferences.intallationType == "exportConsumption" then
    if command.component == "main" then
      if last_reading.value ~= 0 then -- dp 0x65
        local offset = device:get_field("offset_main_exportConsumption") or 0
        device:set_field("offset_main_exportConsumption", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyConsumption" then -- dp 0x66
      if last_reading.value ~= 0 then
        local offset = device:get_field("offset_energyConsumption_exportConsumption") or 0
        device:set_field("offset_energyConsumption_exportConsumption", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyProductionTotal" then --0x65 + 0x67 - 0x66
      if last_reading.value ~= 0 then
        local offset = device:get_field("offset_energyProductionTotal_exportConsumption") or 0
        device:set_field("offset_energyProductionTotal_exportConsumption", last_reading.value+offset, {persist = true})
        device:set_field("energy_0x65", 0)
        device:set_field("energy_0x66", 0)
        device:set_field("energy_0x67", 0)
      end
    end

  elseif device.preferences.intallationType == "exportProduct" then
    if command.component == "main" then
      if last_reading.value ~= 0 then -- dp 0x65
        local offset = device:get_field("offset_main_exportProduct") or 0
        device:set_field("offset_main_exportProduct", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyConsumption" then --dp(66)
      if last_reading.value ~= 0 then
        local offset = device:get_field("offset_energyConsumption_exportProduct") or 0
        device:set_field("offset_energyConsumption_exportProduct", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyProductionTotal" then --dp 0x67
      if last_reading.value ~= 0 then
        local offset = device:get_field("offset_energyProductionTotal_exportProduct") or 0
        device:set_field("offset_energyProductionTotal_exportProduct", last_reading.value+offset, {persist = true})
      end
    end

  elseif device.preferences.intallationType == "independetTwoClamp" then
    if command.component == "main" then
      if last_reading.value ~= 0 then 
        local offset = device:get_field("offset_main_independetTwoClamp") or 0
        device:set_field("offset_main_independetTwoClamp", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyConsumption" then --dp(67)
      if last_reading.value ~= 0 then
        local offset = device:get_field("offset_energyConsumption_independetTwoClamp") or 0
        device:set_field("offset_energyConsumption_independetTwoClamp", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyConsumptionTotal" then 
      if last_reading.value ~= 0 then
        local offset = device:get_field("offset_energyConsumptionTotal_independetTwoClamp") or 0
        device:set_field("offset_energyConsumptionTotal_independetTwoClamp", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyProductionA" then --dp(0x66)
      if last_reading.value ~= 0 then 
        local offset = device:get_field("offset_energyProductionA_independetTwoClamp") or 0
        device:set_field("offset_energyProductionA_independetTwoClamp", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyProductionB" then --dp(0x68)
      if last_reading.value ~= 0 then
        local offset = device:get_field("offset_energyProductionB_independetTwoClamp") or 0
        device:set_field("offset_energyProductionB_independetTwoClamp", last_reading.value+offset, {persist = true})
      end
    elseif command.component == "energyProductionTotal" then --dp(0x02)
      if last_reading.value ~= 0 then
        local offset = device:get_field("offset_energyProductionTotal_independetTwoClamp") or 0
        device:set_field("offset_energyProductionTotal_independetTwoClamp", last_reading.value+offset, {persist = true})
      end
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

local tuya_meter_dual = {
  NAME = "Tuya meter dual bidirectional",
  capability_handlers = {
    [capabilities.energyMeter.ID] = {
      [capabilities.energyMeter.commands.resetEnergyMeter.NAME] = resetEnergyMeter_handler,
    },
  },
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
    init = device_init,
    driverSwitched = do_driverSwitched,
    doConfigure = do_configure
  },
  can_handle =  require("tuya-meter-dual.can_handle"),
}

return tuya_meter_dual