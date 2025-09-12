-- Mariano Colmenarejo 2022
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
local ZigbeeDriver = require "st.zigbee"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local zcl_commands = require "st.zigbee.zcl.global_commands"
local json = require "st.json"
local utils = require "st.utils"
local Status = require "st.zigbee.generated.types.ZclStatus"
local data_types = require "st.zigbee.data_types"
local device_management = require "st.zigbee.device_management"
local attribute_utils = require"attribute_utils"

local zigbee_utils = require "zigbee_utils"
local OnOff = zcl_clusters.OnOff
local Level = zcl_clusters.Level
local Scenes = zcl_clusters.Scenes

local app_version = nil
local zcl_version = nil
local lqi = nil
local rssi = nil
--local CLUSTER = 0x0000

--local cluster_number_set = "0"
--local attribute_number_set = "0"
--local attribute_data_type_set = "00"
--local attribute_value_set = 0
--local manufacturer_code_set = "-"
--local config_action = "Select"
local outputString = " "

local zclStatus = {
  [0] = "SUCCESS",
  [1] = "FAILURE",
  [126] = "NOT_AUTHORIZED",
  [128] = "MALFORMED_COMMAND",
  [129] = "UNSUP_CLUSTER_COMMAND",
  [130] = "UNSUP_GENERAL_COMMAND",
  [131] = "UNSUP_MANUF_CLUSTER_COMMAND",
  [132] = "UNSUP_MANUF_GENERAL_COMMAND",
  [133] = "INVALID_FIELD",
  [134] = "UNSUPPORTED_ATTRIBUTE",
  [135] = "INVALID_VALUE", 
  [136] = "READ_ONLY",
  [137] = "INSUFFICIENT_SPACE",
  [138] = "DUPLICATE_EXISTS",
  [139] = "NOT_FOUND", 
  [140] = "UNREPORTABLE_ATTRIBUTE", 
  [141] = "INVALID_DATA_TYPE",
  [142] = "INVALID_SELECTOR",
  [143] = "WRITE_ONLY",
  [144] = "INCONSISTENT_STARTUP_STATE",
  [145] = "DEFINED_OUT_OF_BAND",
  [146] = "INCONSISTENT",
  [147] = "ACTION_DENIED",
  [148] = "TIMEOUT",
  [149] = "ABORT", 
  [150] = "INVALID_IMAGE",
  [151] = "WAIT_FOR_DATA", 
  [152] = "NO_IMAGE_AVAILABLE",
  [153] = "REQUIRE_MORE_IMAGE",
  [154] = "NOTIFICATION_PENDING", 
  [192] = "HARDWARE_FAILURE", 
  [193] = "SOFTWARE_FAILURE", 
  [194] = "CALIBRATION_ERROR",
  [195] = "UNSUPPORTED_CLUSTER", 
  [196] = "LIMIT_REACHED"
}
--- Custom Capabilities
local manufacturer = capabilities["legendabsolute60149.manufacturer"]
local model = capabilities["legendabsolute60149.model"]
local clusters = capabilities["legendabsolute60149.clustersInfo"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]
local cluster_Number_Hex = capabilities["legendabsolute60149.clusterNumberHex"]
local attribute_Number_Hex = capabilities["legendabsolute60149.attributeNumberHex"]
local attribute_Data_Type = capabilities["legendabsolute60149.attributeDataType"]
local attribute_Value = capabilities["legendabsolute60149.attributeValue"]
local min_Interval = capabilities["legendabsolute60149.minInterval"]
local max_Interval = capabilities["legendabsolute60149.maxInterval"]
local reportable_Change = capabilities["legendabsolute60149.reportableChange"]
local manufacturer_Number_Hex = capabilities["legendabsolute60149.manufacturerNumberHex"]
local command_Config = capabilities["legendabsolute60149.commandConfig"]
local action_Button = capabilities["legendabsolute60149.actionbutton2"]

local function format_hex_array(arr)
  local str =""
  for i, num in ipairs(arr) do
      if str ~= "" then
          str = str .. ","
      end
      if i % 8 == 0 then
          str = str .. " <BR>"
      end
      str = str .. string.format("%04X", num)
  end
  return str
end

-- get server clusters
local function get_server_clusters(device) 
  local server_clusters = ""
  for _, ep in pairs(device.zigbee_endpoints) do
      local row = format_hex_array(ep.server_clusters)
      if row ~= "" then
          server_clusters = server_clusters .. string.format("<b>Ep: ".."</b>".."0x%02X={ %s }<BR>", ep.id, row)
      end
  end
  return server_clusters
end

-- get server clusters no HTLM
local function get_server_clusters_text(device) 
  local server_clusters = ""
  for _, ep in pairs(device.zigbee_endpoints) do
      local row = format_hex_array(ep.server_clusters)
      if row ~= "" then
          server_clusters = server_clusters .. string.format("-Ep:".."0x%02X=(%s)", ep.id, row)
      end
  end
  return server_clusters
end

-- get client clusters
local function get_client_clusters(device) 
  local client_clusters = ""
  for _, ep in pairs(device.zigbee_endpoints) do
      local row = format_hex_array(ep.client_clusters)
      if row ~= "" then
          client_clusters = client_clusters .. string.format("<b>Ep: ".."</b>".."0x%02X={ %s }<BR>", ep.id, row)
      end
  end
  return client_clusters
end

-- get EIU
local function get_zigbee_eui(device)
  local s = device.zigbee_eui
  return string.format(string.rep("%02X", #s), string.byte(s, 1, #s))
end

---Format row HTML
local function format_row(key, value)
  local str = "<tr> <th align=left>" .. key .. "</th> <td>" .. value .. "</td></tr>"
  return str
end

--applicationVersion_handler
local function applicationVersion_handler(self, device, value, zb_rx)
  print("Firmware >>>>>>>>>",value.value)
  app_version = value.value
  lqi = zb_rx.lqi.value
  rssi = zb_rx.rssi.value
end

--applicationVersion_handler
local function ZCLVersion_handler(self, device, value, zb_rx)
  print("ZCLVersion >>>>>>>>>",value.value)
  zcl_version = value.value
  lqi = zb_rx.lqi.value
  rssi = zb_rx.rssi.value
end

--set_Cluster_Number_Hex
local function set_Cluster_Number_Hex(driver, device, command)
  print("<<< set_Cluster_Number_Hex:", command.args.value)
  if string.len(command.args.value) > 4 then
    device:emit_event(cluster_Number_Hex.clusterNumberHex({value = "Max 4 characters"}, {visibility = {displayed = false }, state_change = true}))
    device.thread:call_with_delay(3, function()
      device:emit_event(cluster_Number_Hex.clusterNumberHex({value = device:get_field("cluster_number_set")}, {visibility = {displayed = false }, state_change = true}))
    end)
    return
  end

  local cluster_number_value = tonumber("0x"..string.upper(command.args.value))
  print("<<cluster_number_value:",cluster_number_value)
  if cluster_number_value == nil then
    device:emit_event(cluster_Number_Hex.clusterNumberHex({value = "Invalid value"}, {visibility = {displayed = false }, state_change = true}))
    device.thread:call_with_delay(3, function()
      device:emit_event(cluster_Number_Hex.clusterNumberHex({value = device:get_field("cluster_number_set")}, {visibility = {displayed = false }, state_change = true}))
    end)
    return
  else
    local value_hex = string.format("%04X",cluster_number_value)
    device:set_field("cluster_number_set", string.upper(value_hex))
    device:set_field("cluster_number_value",cluster_number_value)

  end
  device:emit_event(cluster_Number_Hex.clusterNumberHex({value = device:get_field("cluster_number_set")}, {visibility = {displayed = false }, state_change = true }))
end

--set_Attribute_Number_Hex
local function set_Attribute_Number_Hex(driver, device, command)
  print("<<< set_Attribute_Number_Hex:", command.args.value)
  if string.len(command.args.value) > 4 then
    device:emit_event(attribute_Number_Hex.attributeNumberHex({value = "Max 4 characters"}, {visibility = {displayed = false }, state_change = true}))
    device.thread:call_with_delay(3, function()
      device:emit_event(attribute_Number_Hex.attributeNumberHex({value = device:get_field("attribute_number_set")}, {visibility = {displayed = false }, state_change = true}))
    end)
    return
  end

  local attribute_number_value = tonumber("0x"..string.upper(command.args.value))
  print("<<< attribute_number_value:", attribute_number_value)
  if attribute_number_value == nil then
    device:emit_event(attribute_Number_Hex.attributeNumberHex({value = "Invalid value"}, {visibility = {displayed = false }, state_change = true}))
    device.thread:call_with_delay(3, function()
      device:emit_event(attribute_Number_Hex.attributeNumberHex({value = device:get_field("attribute_number_set")}, {visibility = {displayed = false }, state_change = true}))
    end)
    return
  else
    local value_hex = string.format("%04X",attribute_number_value)
    device:set_field("attribute_number_set", string.upper(value_hex))
    device:set_field("attribute_number_value",attribute_number_value)
  end
  device:emit_event(attribute_Number_Hex.attributeNumberHex({value = device:get_field("attribute_number_set")}, {visibility = {displayed = false }, state_change = true }))
end

--set_Attribute_Value
local function set_Attribute_Value(driver, device, command)
  print("<<< set_Attribute_Value:", command.args.value)
  if device:get_field("attribute_data_type_value") > 0x00 and device:get_field("attribute_data_type_value") <= 0x3A then
    local value = tostring(command.args.value)
    device:set_field("attribute_value_set", value)
    device:set_field("attribute_value", tonumber(value))
  elseif (device:get_field("attribute_data_type_value") > 0x3A and device:get_field("attribute_data_type_value") <= 0x44) or --string type
  (device:get_field("attribute_data_type_value") >= 0xE0 and device:get_field("attribute_data_type_value") <= 0xE2) then
    device:set_field("attribute_value_set",command.args.value)
    device:set_field("attribute_value",command.args.value)
  end

  device:emit_event(attribute_Value.attributeValue({value = device:get_field("attribute_value_set")}, {visibility = {displayed = false }, state_change = true}))
end

--set_Attribute_Data_Type
local function set_Attribute_Data_Type(driver, device, command)
  print("<<< set_Attribute_Data_Type:", command.args.value)
  
  local attribute_data_type_value = tonumber("0x"..string.upper(command.args.value))
  print("<<attribute_data_type_value:",attribute_data_type_value)
  device:set_field("attribute_data_type_value",attribute_data_type_value)
  device:set_field("attribute_data_type_set",command.args.value)
  device:emit_event(attribute_Data_Type.attributeDataType({value = device:get_field("attribute_data_type_set")}, {visibility = {displayed = false }, state_change = true}))
end

--set_Manufacturer_Number_Hex
local function set_Manufacturer_Number_Hex(driver, device, command)
  print("<<< set_Manufacturer_Number_Hex:", command.args.value)
  if string.len(command.args.value) > 4 then
    device:emit_event(manufacturer_Number_Hex.manufacturerNumberHex({value = "Max 4 characters"}, {visibility = {displayed = false }, state_change = true}))
    device.thread:call_with_delay(3, function()
      device:emit_event(manufacturer_Number_Hex.manufacturerNumberHex({value = device:get_field("manufacturer_code_set")}, {visibility = {displayed = false }, state_change = true}))
    end)
    return
  end
  
  local manufacturer_code_value = nil
  if command.args.value ~= "" then
    manufacturer_code_value = tonumber("0x"..string.upper(command.args.value))
    print("<<manufacturer_code_value:",manufacturer_code_value)
  end
  --if manufacturer_code_value == nil then
    --device:emit_event(manufacturer_Number_Hex.manufacturerNumberHex({value = "Invalid value"}, {visibility = {displayed = false }, state_change = true}))
    --device:emit_event(manufacturer_Number_Hex.manufacturerNumberHex({value = ""}, {visibility = {displayed = false }, state_change = true}))
    --device.thread:call_with_delay(3, function()
      --device:emit_event(manufacturer_Number_Hex.manufacturerNumberHex({value = device:get_field("manufacturer_code_set")}, {visibility = {displayed = false }, state_change = true}))
    --end)
    --return
  --else
    if manufacturer_code_value == nil or manufacturer_code_value == 0 then
      manufacturer_code_value = nil
      device:set_field("manufacturer_code_set","")
    else
      local value_hex = string.format("%04X",manufacturer_code_value)
      --print("<< value_hex:",value_hex)
      device:set_field("manufacturer_code_set",string.upper(value_hex))
    end
    device:set_field("manufacturer_code_value", manufacturer_code_value)
  --end
  device:emit_event(manufacturer_Number_Hex.manufacturerNumberHex({value = device:get_field("manufacturer_code_set")}, {visibility = {displayed = false }, state_change = true}))
end

--set_Min_Interval
local function set_Min_Interval(driver, device, command)
  print("<<< set_Min_Interval:", command.args.value)
  device:set_field("min_interval_set",command.args.value)

  device:emit_event(min_Interval.minInterval({value = device:get_field("min_interval_set")}, {visibility = {displayed = false }, state_change = true}))
end

--set_Max_Interval
local function set_Max_Interval(driver, device, command)
  print("<<< set_Max_Interval:", command.args.value)
  device:set_field("max_interval_set",command.args.value)

  device:emit_event(max_Interval.maxInterval({value = device:get_field("max_interval_set")}, {visibility = {displayed = false }, state_change = true}))
end

--set_Reportable_Change
local function set_Reportable_Change(driver, device, command)
  print("<<< set_Reportable_Change:", command.args.value)
  device:set_field("reportable_change_set",command.args.value)

  device:emit_event(reportable_Change.reportableChange({value = device:get_field("reportable_change_set")}, {visibility = {displayed = false }, state_change = true}))
end

--command_Config_handler
local function command_Config_handler(driver, device, command)
  print("<<< Config Command:", command.args.value)
  device:set_field("config_action",command.args.value)

  device:emit_event(command_Config.commandConfig({value = device:get_field("config_action")}, {visibility = {displayed = false }, state_change = true}))
end

--command_command_Action_button_handler
local function command_Action_button_handler(driver, device, command)
  print("<<< Action_button:", command.args.value)

  local str= "Waiting ...info"
  device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }}))
  --device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = false }}))

  if device.preferences.changeConfigProfile == "Config" then
    if device:get_field("config_action") == "Read" then

      local cluster_id = device:get_field("cluster_number_value")
      local attr_id = device:get_field("attribute_number_value")
      local mfg_code = device:get_field("manufacturer_code_value")
      device:send(attribute_utils.custom_read_attribute(device, cluster_id, attr_id, mfg_code))

    elseif device:get_field("config_action") == "Write" then

      local cluster_id = device:get_field("cluster_number_value")
      local attr_id = device:get_field("attribute_number_value")
      local value_send =  device:get_field("attribute_value")
      if device:get_field("attribute_data_type_value") == 0x10 then -- boolean
        if device:get_field("attribute_value") == 1 then
          value_send = true
        else 
          value_send = false
        end
      end
      local data_type =data_types.get_data_type_by_id(device:get_field("attribute_data_type_value"))
      local mfg_code = device:get_field("manufacturer_code_value")
    --print("<<< data_type",utils.stringify_table(data_type))
      device:send(attribute_utils.custom_write_attribute(device, cluster_id, attr_id, data_type, value_send, mfg_code))

    end

  elseif device.preferences.changeConfigProfile == "ConfigReport" then
    if device:get_field("config_action") == "Read" then
      print("<<< Configure Reporting Read")
      local cluster =  device:get_field("cluster_number_value")
      local attribute = device:get_field("attribute_number_value")
      local mfg_code = device:get_field("manufacturer_code_value")

      device:send(attribute_utils.ReadReportingConfiguration(device, cluster, attribute, mfg_code))

    elseif device:get_field("config_action") == "Write" then
      print("<<< Configure Reporting Write")

      local config = {
        cluster =  device:get_field("cluster_number_value"),
        attribute = device:get_field("attribute_number_value"),
        minimum_interval = device:get_field("min_interval_set"),
        maximum_interval = device:get_field("max_interval_set"),
        reportable_change = device:get_field("reportable_change_set"),
        data_type = data_types.get_data_type_by_id(device:get_field("attribute_data_type_value")),
        mfg_code = device:get_field("manufacturer_code_value")
      }
      
      local sign = 0
      local exponent
      local mantissa
      if device:get_field("attribute_data_type_value") == 0x38 or device:get_field("attribute_data_type_value") == 0x39 or device:get_field("attribute_data_type_value") == 0x3A then
        if device:get_field("reportable_change_set") == 0 then
          if device:get_field("attribute_data_type_value") == 0x38 then
            exponent = -15
            mantissa = 0
          elseif device:get_field("attribute_data_type_value") == 0x39 then
            exponent = -127
            mantissa = 0
          elseif device:get_field("attribute_data_type_value") == 0x3A then
              exponent = -1023
              mantissa = 0
          end
        else
          exponent = math.floor(math.log(device:get_field("reportable_change_set"),10) / math.log(2,10))
          if device:get_field("attribute_data_type_value") == 0x38 and exponent > 16 then
            exponent = 16
          elseif device:get_field("attribute_data_type_value") == 0x39 and exponent > 128 then
            exponent = 128
          elseif device:get_field("attribute_data_type_value") == 0x3A and exponent > 1024 then
              exponent = 1024
          end
          mantissa = (device:get_field("reportable_change_set") / 2^(exponent)) -1
          if mantissa > 1 then mantissa = 1 end
        end
      end

      if device:get_field("attribute_data_type_value") == 0x38 then
        config.reportable_change =  data_types.SemiPrecisionFloat(sign, exponent, mantissa)
      elseif device:get_field("attribute_data_type_value") == 0x39 then
        config.reportable_change =  data_types.SinglePrecisionFloat(sign, exponent, mantissa)
      elseif device:get_field("attribute_data_type_value") == 0x3A then
        config.reportable_change =  data_types.DoublePrecisionFloat(sign, exponent, mantissa)
        --print("<<<< report_value:", report_value_float)
      end
      print("<<<<exponent:",exponent)
      print("<<<<mantissa:",mantissa)
      print("<<<< report_value:", device:get_field("reportable_change_set"))
      print("<<<<config.reportable_change:", config.reportable_change)

      --device:add_configured_attribute(config)
      --device:configure()
      for _, ep in pairs(device.zigbee_endpoints) do
        if device:supports_server_cluster(config.cluster, ep.id) then
          device:send(device_management.build_bind_request(device, config.cluster, driver.environment_info.hub_zigbee_eui, ep.id):to_endpoint(ep.id))
          device:send(device_management.attr_config(device, config):to_endpoint(ep.id))
        end
      end
    end

  end
end

--Emit Manufacturer and model
local function added_handler(driver, device)

  if device.preferences.changeConfigProfile == "Info" then

    device:emit_event(manufacturer.manufacturer(device:get_manufacturer()))
    device:emit_event(model.model(device:get_model()))

    -- read app and zcl version
    device:send(zcl_clusters.Basic.attributes.ApplicationVersion:read(device))
    device:send(zcl_clusters.Basic.attributes.ZCLVersion:read(device))

    device.thread:call_with_delay(3, function(d)
      local server_clusters = get_server_clusters(device)
      local client_clusters = get_client_clusters(device)
      --print("Server Clusters >>>",server_clusters)
      --print("Client Clusters >>>",client_clusters)

      local str = "<em style= 'font-weight: bold;'> Manufacturer: ".."</em>" .. device:get_manufacturer() .. "<BR>"
      str = str .. "<em style= 'font-weight: bold;'> Model: ".."</em>" .. device:get_model() .. "<BR>"
      str = str .. "<em style= 'font-weight: bold;'> FingerPrinted_EndPoint.Id: ".."</em>" .. string.format("0x%02X",device.fingerprinted_endpoint_id) .. "<BR>"
      if app_version ~= nil then
      str = str .. "<em style= 'font-weight: bold;'> App Version: ".."</em>" .. string.format("0x%02X",app_version) .. "<BR>"
      else
        str = str .. "<em style= 'font-weight: bold;'> App Version: ".."</em>" .. "Unknown" .. "<BR>"
      end
      if zcl_version ~= nil then
        str = str .. "<em style= 'font-weight: bold;'> ZCL Version: ".."</em>" .. string.format("0x%02X",zcl_version) .. "<BR>"
      else
        str = str .. "<em style= 'font-weight: bold;'> ZCL Version: ".."</em>" .. "Unknown" .. "<BR>"
      end
      str = str .. "<em style= 'font-weight: bold;'> Network ID: ".."</em>" .. "0x"..device.device_network_id .. "<BR>"
      str = str .. "<em style= 'font-weight: bold;'> Zigbee EUI: ".."</em>" .. get_zigbee_eui(device) .. "<BR>"
      str = str .. "<em style= 'font-weight: bold;'> Device ID: ".."</em>" .. device.id .. "<BR>"
      str = str .. "<BR>".."<em style='color:Red;font-weight: bold;'> Server Cluster: ".."</em>" .. "<BR>"
      str = str ..  server_clusters
      str = str .. "<BR>".."<em style='color:Green;font-weight: bold;'> Client Clusters: ".."</em>" .. "<BR>"
      str = str .. client_clusters
      str = str .. "<BR>".."<em style='color:Blue;font-weight: bold;'> Signal Metrics: ".."</em>" .. "<BR>"
      if lqi ~= nil and rssi ~= nil then
        str = str .. "<em style= 'font-weight: bold;'> LQI: ".."</em>" .. lqi .. " .... " .."<em>".. "<b>RSSI: ".."</em>".."</b>".. rssi .." dbm" .. "<BR>"
      end

      str = "<table style='font-size:65%'> <tbody>".. format_row('', str)

      str = str .. "</tbody></table>"
      
      device:emit_event(device_Info.deviceInfo(str))

      --emit values in text format
      str = "FingerPrinted_EndPoint.Id: ".. string.format("0x%02X",device.fingerprinted_endpoint_id)
      device:emit_event(clusters.clustersInfo({value = str}, { state_change = true }))

      device.thread:call_with_delay(2, function(d)
        if app_version ~= nil then
          str = "App Version: ".. string.format("0x%02X",app_version)
        else
          str =  "App Version: Unknown"
        end
        if zcl_version ~= nil then
          str = str .. ", ".."ZCL Version: ".. string.format("0x%02X",zcl_version)
        else
          str = str .. ", ".."ZCL Version: Unknown"
        end
        device:emit_event(clusters.clustersInfo({value = str}, { state_change = true }))
      end)

      device.thread:call_with_delay(3, function(d)
        server_clusters = get_server_clusters_text(device)
        device:emit_event(clusters.clustersInfo({value = server_clusters}, { state_change = true }))
      end)

      device.thread:call_with_delay(5, function(d)
          str= "See device history to check all info"
          device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = true }}))
        end)
      end)

  elseif device.preferences.changeConfigProfile == "Config" then
    local cap_status = device:get_latest_state("main", cluster_Number_Hex.ID, cluster_Number_Hex.clusterNumberHex.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "0" end
      device:set_field("cluster_number_set", cap_status)
      local commands ={}
      commands = {args = {value = cap_status}}
      set_Cluster_Number_Hex(driver, device, commands)
 
    cap_status = device:get_latest_state("main", attribute_Number_Hex.ID, attribute_Number_Hex.attributeNumberHex.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "0" end
      device:set_field("attribute_number_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Attribute_Number_Hex(driver, device, commands)

    cap_status = device:get_latest_state("main", attribute_Data_Type.ID, attribute_Data_Type.attributeDataType.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "00" end
      device:set_field("attribute_data_type_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Attribute_Data_Type(driver, device, commands)

    cap_status = device:get_latest_state("main", attribute_Value.ID, attribute_Value.attributeValue.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "0" end
      device:set_field("attribute_value_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Attribute_Value(driver, device, commands)

    cap_status = device:get_latest_state("main", manufacturer_Number_Hex.ID, manufacturer_Number_Hex.manufacturerNumberHex.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "" end
      device:set_field("manufacturer_code_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Manufacturer_Number_Hex(driver, device, commands)

    local str= "Waiting ...info"
    device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }}))
    --device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = false }}))
    cap_status = device:get_latest_state("main", command_Config.ID, command_Config.commandConfig.NAME)
    if cap_status == nil then cap_status = "Read" end
    device:set_field("config_action", cap_status)
    device:emit_event(command_Config.commandConfig({value = cap_status}, {visibility = {displayed = false }, state_change = true}))

  elseif device.preferences.changeConfigProfile == "ConfigReport" then
    local cap_status = device:get_latest_state("main", cluster_Number_Hex.ID, cluster_Number_Hex.clusterNumberHex.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "0" end
      device:set_field("cluster_number_set", cap_status)
      local commands ={}
      commands = {args = {value = cap_status}}
      set_Cluster_Number_Hex(driver, device, commands)
 
    cap_status = device:get_latest_state("main", attribute_Number_Hex.ID, attribute_Number_Hex.attributeNumberHex.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "0" end
      device:set_field("attribute_number_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Attribute_Number_Hex(driver, device, commands)

    cap_status = device:get_latest_state("main", attribute_Data_Type.ID, attribute_Data_Type.attributeDataType.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "00" end
      device:set_field("attribute_data_type_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Attribute_Data_Type(driver, device, commands)

    cap_status = device:get_latest_state("main", min_Interval.ID, min_Interval.minInterval.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = 0 end
      device:set_field("min_interval_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Min_Interval(driver, device, commands)

    cap_status = device:get_latest_state("main", max_Interval.ID, max_Interval.maxInterval.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = 0 end
      device:set_field("max_interval_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Max_Interval(driver, device, commands)
    
    cap_status = device:get_latest_state("main", reportable_Change.ID, reportable_Change.reportableChange.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = 0 end
      device:set_field("reportable_change_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Reportable_Change(driver, device, commands)

    cap_status = device:get_latest_state("main", manufacturer_Number_Hex.ID, manufacturer_Number_Hex.manufacturerNumberHex.NAME)
    print("<<cap_status =",cap_status)
    if cap_status == nil then cap_status = "" end
      device:set_field("manufacturer_code_set", cap_status)
      commands = {args = {value = cap_status}}
      set_Manufacturer_Number_Hex(driver, device, commands)

    local str= "Waiting ...info"
    device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }}))
    --device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = false }}))
    cap_status = device:get_latest_state("main", command_Config.ID, command_Config.commandConfig.NAME)
    if cap_status == nil then cap_status = "Read" end
    device:set_field("config_action", cap_status)
    device:emit_event(command_Config.commandConfig({value = cap_status}, {visibility = {displayed = false }, state_change = true}))
  end
end

--- Preference and infoChanged handler
local function info_Changed(self,device)
  for id, value in pairs(device.preferences) do
    print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
    local oldPreferenceValue = device:get_field(id)
    local newParameterValue = device.preferences[id]
    if oldPreferenceValue ~= newParameterValue then
      device:set_field(id, newParameterValue, {persist = true})
      print("<< Preference changed name:", id, "old value:", oldPreferenceValue, "new value:", newParameterValue)
       --change profile tile
      if id == "changeConfigProfile" then
        if device.preferences.changeConfigProfile == "Info" then
          device:try_update_metadata({profile = "zigbee-thing"})
          device.thread:call_with_delay(3, function()-- from 1 sec
            added_handler(self, device)
          end)
        elseif device.preferences.changeConfigProfile == "Config" then
          device:try_update_metadata({profile = "zigbee-configure"})
          device.thread:call_with_delay(3, function()-- from 1 sec
            added_handler(self, device)
          end)
        elseif device.preferences.changeConfigProfile == "ConfigReport" then
          device:try_update_metadata({profile = "zigbee-configure-report"})
          device.thread:call_with_delay(3, function()-- from 1 sec
            added_handler(self, device)
          end)
        end
      --[[elseif id == "group" then
        local group = device.preferences.group
        if oldPreferenceValue == nil then oldPreferenceValue = 0 end
        for groups = 0 , 10  do
          for scena = 1 , 5 do
        zigbee_utils.send_unbind_request(device, OnOff.ID, oldPreferenceValue)
        zigbee_utils.send_unbind_request(device, Scenes.ID, oldPreferenceValue)
        zigbee_utils.send_unbind_request(device, Level.ID, oldPreferenceValue)
        device:send(Scenes.commands.ViewScene(device, groups, scena))
         --device:send(Scenes.commands.RemoveAllScenes(device, groups))
          --device:send(Scenes.commands.RemoveAllScenes(device, 0x0001))
          ---device:send(Scenes.commands.RemoveScene(device, groups, scena))
          --device:send(Scenes.commands.RemoveScene(device, 0x0001, 0x02))
          --device:send(Scenes.commands.RemoveScene(device, 0x0002, 0x02))
          end
        end
        if(group > 0) then
          zigbee_utils.send_bind_request(device, OnOff.ID, group)
          zigbee_utils.send_bind_request(device, Scenes.ID, group)
          zigbee_utils.send_bind_request(device, Level.ID, group)

          local extension_field_sets = {}
          extension_field_sets ={cluster_id = {field_name = 0x0006}, extension_field_set = {field_name = 0x0000}}
          --extension_field_sets ={cluster_id = 0x0006, extension_field_set = {field_name = 0x0000}}

          device:send(Scenes.commands.AddScene(device, group, 1, 0, "on-Off", extension_field_sets))
        else
        end]]
      end
    end
  end
end

--reportAttribute_handler
local function writeAttributeResponse_handler(driver, device, zb_rx, value)
  print("<< writeAttributeResponse_handler >>")

  if zb_rx.body.zcl_body.global_status ~= nil then
    local status_value = zclStatus[zb_rx.body.zcl_body.global_status.value]
    print("<< status_value:", status_value)
    local str= "Write Attr: " .. device:get_field("attribute_number_set") .. ", ZCL Status: " .. status_value
    device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }, state_change = true}))
  else
    local status_value = zclStatus[zb_rx.body.zcl_body.attr_records[1].status.value]
    print("<< status_value:", status_value)
    local str= "Write Attr: " .. device:get_field("attribute_number_set") .. ", ZCL Status: " .. status_value
    device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }, state_change = true}))
  end
end

--readAttributeResponse_handler
local function readAttributeResponse_handler(driver, device, zb_rx, value)
  print("<< readAttributeResponse_handler >>")
  --local status = zb_rx.body.zcl_body.status.value
  --local cmd = zb_rx.body.zcl_body.cmd.value
  --print("zb_rx >>>>>>",utils.stringify_table(zb_rx))
  --print("<<<<<<<< body", zb_rx.body)
  local status_value = zclStatus[zb_rx.body.zcl_body.attr_records[1].status.value]
  print("<<< zclStatus:", status_value)
  local str = "ZCL Status: " .. status_value
  device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }, state_change = true}))

  if status_value == "SUCCESS" and device.preferences.changeConfigProfile == "Config" then

    if device.preferences.logDebugPrint == true then
      print("zb_rx.body.zcl_body.attr_records[1] >>>>>>",utils.stringify_table(zb_rx.body.zcl_body.attr_records[1].attr_id.value))
      print("zb_rx.body.zcl_body.attr_records.data.field_name >>>>>>",utils.stringify_table(zb_rx.body.zcl_body.attr_records[1].data.field_name))
      print("zb_rx.body.zcl_body.attr_id >>>>>>",utils.stringify_table(zb_rx.body.zcl_body.attr_records[1].data.value))
      print("zb_rx.body.zcl_body.attr_records.data_type >>>>>>",utils.stringify_table(zb_rx.body.zcl_body.attr_records[1].data_type.value))
      print("zb_rx.body.zcl_body.attr_records.status >>>>>>",utils.stringify_table(zb_rx.body.zcl_body.attr_records[1].status.value))
      if device:get_field("manufacturer_code_value") ~= nil then
      print("zb_rx.body.zcl_body.zcl_header.mfg_code >>>>>>",utils.stringify_table(zb_rx.body.zcl_header.mfg_code.value))
      end
    end

    --set_Attribute_Data_Type
    local cap_status = string.format("%02X", zb_rx.body.zcl_body.attr_records[1].data_type.value)
    print("<< data types:", cap_status)
    local commands ={}
    commands = {args = {value = cap_status}}
    set_Attribute_Data_Type(driver, device, commands)

    --set_Manufacturer_Number_Hex
    cap_status = ""
    if device:get_field("manufacturer_code_value") ~= nil then
      cap_status = string.format("%04X", zb_rx.body.zcl_header. mfg_code.value)
    end
    print("<< manufacturer_code:", cap_status)
    commands ={}
    commands = {args = {value = cap_status}}
    set_Manufacturer_Number_Hex(driver, device, commands)

    --set_Attribute_Number_Hex
    cap_status = string.format("%04X", zb_rx.body.zcl_body.attr_records[1].attr_id.value)
    print("<< attribute id:", cap_status)
    commands ={}
    commands = {args = {value = cap_status}}
    set_Attribute_Number_Hex(driver, device, commands)
    
    --set_Attribute_Value
    cap_status = zb_rx.body.zcl_body.attr_records[1].data.value
    if cap_status == false then
      cap_status = 0
    elseif cap_status == true then
      cap_status = 1
    end
    print("<< attribute value:", cap_status)
    commands = {args = {value = cap_status}}
    set_Attribute_Value(driver, device, commands)

    local data =data_types.get_data_type_by_id(0x20)
    print("<< data:", data)
  end

  --pruebas de verificacion de tablas del mensaje
    --print("<<<<<<<< ZCL Command Id:", zb_rx.body.zcl_header.cmd.value)
    --print("<<<<<<<< body.zcl_body.attr_records.status.value", zb_rx.body.zcl_body.attr_records.status.valuee)
    --print("<<<<<<<< body.zcl_body.attr_records.data.field_name", zb_rx.body.zcl_body.attr_records.data.field_name)
    --print("<<<<<<<< body.zcl_body.attr_records.data.value", zb_rx.body.zcl_body.attr_records.data.value)
    --print("zb_rx >>>>>>",utils.stringify_table(zb_rx.body.zcl_body.attr_records))
end

--ConfigureReportingResponse_handler
local function ConfigureReportingResponse_handler(driver, device, zb_rx)
  print("<< ConfigureReportingResponse_handler >>")

  --print("<<<<<<< zb_rx.body.zcl_header.cmd.value:", zb_rx.body.zcl_header.cmd.value)
  if (zb_rx.body.zcl_header.cmd.value == zcl_commands.CONFIGURE_REPORTING_RESPONSE_ID) then
    --print("<<<<  zb_rx.body.zcl_body.global_status",  utils.stringify_table(zb_rx.body.zcl_body.global_status))

    local status_value = zclStatus[0]
    if zb_rx.body.zcl_body.global_status == nil then
      status_value = zclStatus[zb_rx.body.zcl_body.config_records[1].status.value]
    else
      --print("<<<< zb_rx.body.zcl_body.global_status.value:", zb_rx.body.zcl_body.global_status.value)
      status_value = zclStatus[zb_rx.body.zcl_body.global_status.value]
    end
    local str = "ZCL Status: " .. status_value
    device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }, state_change = true}))
  end
end

--ReadReportingConfigurationResponse_handler
local function ReadReportingConfigurationResponse_handler(driver, device, zb_rx)
  print("<< ReadReportingConfigurationResponse_handler >>")

  print("<<<< zb_rx.body.zcl_body:",  utils.stringify_table(zb_rx.body.zcl_body.read_reporting_records))
  for _, conf_record in ipairs(zb_rx.body.zcl_body.read_reporting_records) do

    local attr_id = conf_record.attr_id.value

    --set_Attribute_Data_Type
    local data_type = string.format("%02X", conf_record.data_type.value)
    print("<< data types:", data_type)
    local commands ={}
    commands = {args = {value = data_type}}
    set_Attribute_Data_Type(driver, device, commands)

    --set_Max_Interval
    local maximum_reporting_interval = conf_record.maximum_reporting_interval.value
    commands ={}
    commands = {args = {value = maximum_reporting_interval}}
    set_Max_Interval(driver, device, commands)

    --set_Min_Interval
    local minimum_reporting_interval = conf_record.minimum_reporting_interval.value
    commands ={}
    commands = {args = {value = minimum_reporting_interval}}
    set_Min_Interval(driver, device, commands)

    local status_value = zclStatus[conf_record.status.value]
    local str = "ZCL Status: " .. status_value
    device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }, state_change = true}))

    if device.preferences.logDebugPrint == true then
      print("<<< conf_record.attr_id.value:", attr_id)
      print("<<< conf_record.data_type.value:", data_type)
      print("<<< conf_record.maximum_reporting_interval.value:", maximum_reporting_interval)
      print("<<< conf_record.minimum_reporting_interval.value:", minimum_reporting_interval)
      print("<<< conf_record.status.value:", status_value)
    end

    if not data_types.get_data_type_by_id(conf_record.data_type.value).is_discrete then
      local reportable_change = conf_record.reportable_change.value
      commands ={}
      commands = {args = {value = reportable_change}}
      set_Reportable_Change(driver, device, commands)
      print("<<< conf_record.reportable_change.value:", reportable_change)
    end
  end

end

--defaultResponse_handler
local function defaultResponse_handler(driver, device, zb_rx)
  print("<< defaultResponse_handler >>")

  local status_value = zclStatus[zb_rx.body.zcl_body.status.value]
  print("<< status_value:", status_value)
  local str= status_value .. ": " .. string.format("%04X", device:get_field("cluster_number_set"))
  device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }, state_change = true}))
end

--reportAttribute_handler
local function reportAttribute_handler(driver, device, zb_rx)
  print("<< reportAttribute_handler >>")
  print("<<<< reportAtribute command message:",  utils.stringify_table(zb_rx))
end

-- device_init
local function device_init(driver, device)
  print("<< device init >>")
  --change profile tile
    if device.preferences.changeConfigProfile == "Info" then
      device:try_update_metadata({profile = "zigbee-thing"})   
    elseif device.preferences.changeConfigProfile == "Config" then
      device:try_update_metadata({profile = "zigbee-configure"})
    elseif device.preferences.changeConfigProfile == "ConfigReport" then
      device:try_update_metadata({profile = "zigbee-configure-report"})
    end
    device.thread:call_with_delay(3, function()-- from 1 sec
      added_handler(driver, device)
    end)
end

local zigbee_thing_template = {
  lifecycle_handlers = {
    init = device_init,
    infoChanged = info_Changed,
  },
  supported_capabilities = {
    capabilities.refresh,
  },
  capability_handlers = {
    [cluster_Number_Hex.ID] = {
      [cluster_Number_Hex.commands.setClusterNumberHex.NAME] = set_Cluster_Number_Hex,
    },
    [attribute_Number_Hex.ID] = {
      [attribute_Number_Hex.commands.setAttributeNumberHex.NAME] = set_Attribute_Number_Hex,
    },
    [attribute_Data_Type.ID] = {
      [attribute_Data_Type.commands.setAttributeDataType.NAME] = set_Attribute_Data_Type,
    },
    [attribute_Value.ID] = {
      [attribute_Value.commands.setAttributeValue.NAME] = set_Attribute_Value,
    },
    [manufacturer_Number_Hex.ID] = {
      [manufacturer_Number_Hex.commands.setManufacturerNumberHex.NAME] = set_Manufacturer_Number_Hex,
    },
    [min_Interval.ID] = {
      [min_Interval.commands.setMinInterval.NAME] = set_Min_Interval,
    },
    [max_Interval.ID] = {
      [max_Interval.commands.setMaxInterval.NAME] = set_Max_Interval,
    },
    [reportable_Change.ID] = {
      [reportable_Change.commands.setReportableChange.NAME] = set_Reportable_Change,
    },
    [command_Config.ID] = {
      [command_Config.commands.setCommandConfig.NAME] = command_Config_handler,
    },
    [action_Button.ID] = {
      [action_Button.commands.push.NAME] = command_Action_button_handler,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = added_handler,
    }
  },
  zigbee_handlers = {
    global = {
      [0x0000] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0001] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0002] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0003] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0004] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0005] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0006] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0008] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0009] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x000A] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x000C] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x000D] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x000F] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0100] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,

      },
      [0x0101] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0102] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0103] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0200] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0201] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0202] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0203] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0204] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0300] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0301] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0400] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0401] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0402] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0403] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0404] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0405] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0406] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0409] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x040A] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x040B] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x040C] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x042A] = { --pm25Measurement
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x042B] = { --msFormaldehyde
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x042C] = { --pm1Measurement
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x042D] = { --pm10Measurement
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0500] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler,
        [zcl_commands.ReportAttribute.ID] = reportAttribute_handler,
      },
      [0x0501] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0502] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0702] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x0B04] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0x1000] = {
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xE000] = { --TUYA_COMMON_PRIVATE
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xE001] = { --TUYA ELECTRICITY
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFC01] = { -- LEDVANCE & SMARTSENSE_MULTI_SENSOR_CUSTOM_PROFILE 
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFC02] = { --SAMJIN ACCEL
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFC03] = { -- SMARTSENSE_MULTI_CLUSTER
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFC0F] = { --OSRAM
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFC57] = { --IKEA WWAH_CLUSTER_ID
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFC7D] = { --IKEA AIR PURIFIER
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFC7E] = { --IKEA TVOC_CLUSTER_ID
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFCC0] = { --LUMI
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
      [0xFF01] = { --SINOPE_CUSTOM_CLUSTER
        [zcl_commands.WriteAttributeResponse.ID] = writeAttributeResponse_handler,
        [zcl_commands.ReadAttributeResponse.ID] = readAttributeResponse_handler,
        [zcl_commands.DefaultResponse.ID] = defaultResponse_handler,
        [zcl_commands.ConfigureReportingResponse.ID] = ConfigureReportingResponse_handler,
        [zcl_commands.ReadReportingConfigurationResponse.ID] = ReadReportingConfigurationResponse_handler
      },
    },
    attr = {
      [zcl_clusters.Basic.ID] = {
        [zcl_clusters.Basic.attributes.ZCLVersion.ID] = ZCLVersion_handler,
        [zcl_clusters.Basic.attributes.ApplicationVersion.ID] = applicationVersion_handler
      },
    },
  }
}

local zigbee_thing = ZigbeeDriver("zigbee_thing", zigbee_thing_template)
zigbee_thing:run()
