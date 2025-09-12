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

-- Subdriver to Device Parameter and association configuration
-- M. Caolmenarejo 2023

local capabilities = require "st.capabilities"
--- @type st.zwave.defaults
--local defaults = require "st.zwave.defaults"
--- @type st.zwave.Driver
--local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.CommandClass.Configuration
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 2 })
--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({ version= 3 })
--- @type st.zwave.CommandClass.MultiChannelAssociation
local MultiChannelAssociation = (require "st.zwave.CommandClass.MultiChannelAssociation")({ version= 4 })
local Version = (require "st.zwave.CommandClass.Version")({ version = 2 })
local zw = require "st.zwave.init"
--local utils = require "st.utils"
--local preferences = require "preferences"
local preferencesMap = require "preferences"
local child_devices = require "child-devices"
--local json = require "st.json"

--- Custom Capabilities
local manufacturer = capabilities["legendabsolute60149.manufacturer"]
local product_Type = capabilities["legendabsolute60149.productType"]
local product_Id = capabilities["legendabsolute60149.productId"]
local command_Class = capabilities["legendabsolute60149.commandClass"]
local device_Parameter = capabilities["legendabsolute60149.deviceParameter"]
local parameter_Size = capabilities["legendabsolute60149.parameterSize"]
local parameter_Value = capabilities["legendabsolute60149.parameterValue"]
local command_Config = capabilities["legendabsolute60149.commandConfig1"]
local action_Button = capabilities["legendabsolute60149.actionbutton2"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]
local parameter_Start = capabilities["legendabsolute60149.parameterStart"]
local parameter_End = capabilities["legendabsolute60149.parameterend"]
local wake_Up_Value = capabilities["legendabsolute60149.wakeUpValue"]
local group_Number_Start = capabilities["legendabsolute60149.groupNumberStart"]
local group_Number_End = capabilities["legendabsolute60149.groupNumberEnd"]
local group_Number = capabilities["legendabsolute60149.groupNumber"]
--local node_To_Write = capabilities["legendabsolute60149.nodeToWrite"]
local node_To_Write_Hex = capabilities["legendabsolute60149.nodeToWriteHex"]
local node_End_Point = capabilities["legendabsolute60149.nodeEndPoint"]
local device_Association_Type = capabilities["legendabsolute60149.deviceAssociationType"]
local group_Command_Option = capabilities["legendabsolute60149.groupCommandOption"]

---Initial variables values
--local parameter_number = 1
--local parameter_value_set = 0
--local parameter_size_set = 1
--local config_action = "Select"
--local wake_up_value_set = 0
--local group_value_start = 1
--local group_value_end = 10
--local group_value = 0
--local group_Command = "Get"
--local node_value_set = 0
--local node_value_Hex_set ="-"
--local node_endpoint_value_set = 0
--local device_Association_Type_value = "Single"
--local parameter_value_start = 1
--local parameter_value_end = 25
local scaned_number = 0
local outputString = " "
local outputString_text = " "
local multi_channel_nodes = {}

-- this driver has the infoChange for preferences for all no child devices and config child device
-- "device.preferences.configChild ~= nil" allow NO child devices infoChange and WakeUp and Version, Configuration, Assiciation command class Handlers
local can_handle = function(opts, driver, device)
    if device.preferences.configChild ~= nil or device.preferences.changeConfigProfile ~= nil then
      return true
    else
      return false
    end
end

--- Return a string representation of device model and supported command class information
local function debug_pretty_print(device, parent_device)

  if device.network_type == "DEVICE_EDGE_CHILD" then
      outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device: ".."</em>".. "<BR>".."<b>Id: </b>" .. parent_device.id .. "<BR>".."<b>DNI: </b>" .. "0x".. parent_device.device_network_id .. "<BR>"
      local firmVersion = " nil * Wake Up-Refresh Device"
    if parent_device:get_field("firmVersion") ~= nil then firmVersion = parent_device:get_field("firmVersion") end
    --if device:get_field("firmVersion") ~= nil then
      --outputString = outputString .."<b>Firmware Ver: </b>" .. device:get_field("firmVersion") .. "<BR>"
      outputString = outputString .."<b>Firmware Ver: </b>" .. firmVersion .. "<BR>"
    --end
    local library = " nil * Wake Up-Refresh Device"
    if parent_device:get_field("library") ~= nil then library = parent_device:get_field("library") end
    --if device:get_field("library") ~= nil then
      --outputString = outputString .."<b>Library Ver: </b>" .. device:get_field("library") .. "<BR>"
      outputString = outputString .."<b>Library Ver: </b>" .. library .. "<BR>"
    --end
    local zwProtocol = " nil * Wake Up-Refresh Device"
    if parent_device:get_field("zwProtocol") ~= nil then zwProtocol = parent_device:get_field("zwProtocol") end
    --if device:get_field("zwProtocol") ~= nil then
      --outputString = outputString .."<b>Zw Protocol Ver: </b>" .. device:get_field("zwProtocol") .. "<BR>"
      outputString = outputString .."<b>Zw Protocol Ver: </b>" .. zwProtocol .. "<BR>"
    --end
      if (parent_device.zwave_manufacturer_id ~= nil and parent_device.zwave_product_type ~= nil and parent_device.zwave_product_id ~= nil) then
        outputString = outputString .. string.format("<b>Manufacturer:</b> 0x%04X <BR> <b>Product Type:</b> 0x%04X <BR> <b>Product ID:</b> 0x%04X",
        parent_device.zwave_manufacturer_id, parent_device.zwave_product_type, parent_device.zwave_product_id) .. "\n"
        if(parent_device.zwave_endpoints ~= nil) then
          for index, endpoint in pairs(parent_device.zwave_endpoints) do
            local command_classes = ""
            for _, c_c in ipairs(endpoint.command_classes) do
              command_classes = command_classes .. string.format("%s, ", zw.cc_to_string(c_c.value))
            end
            --outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> End Point & Command Class:".."</em>".. string.format("\t[%d]: %s",index-1, command_classes:sub(1, -3))
            outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> End Point & Command Class:".."</em>".. string.format("\t[%d]: %s",index, command_classes:sub(1, -3))
          end
        end
      end
      
      --[[
      --local device_mesh = json.decode((parent_device.st_store.data or {}).meshInfo)
      local device_mesh = json.decode(parent_device.st_store.data.meshInfo)
      --print("device_mesh: >>>>>>",utils.stringify_table(device_mesh))
      local device_route = parent_device.label ..' [' .. parent_device.device_network_id .. '] <-> '
      for _, node in ipairs(device_mesh.route) do
        local label = "Device"
        for uuid, dev in pairs(device.driver:get_devices()) do
          if dev.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
            if dev.device_network_id == node.deviceId then
              label = dev.label
            end    
          end
        end
        device_route = device_route .. label .." [".. node.deviceId .. '] <-> '
      end
      local hubnode = parent_device.driver.environment_info.hub_zwave_id or 1
      device_route = device_route .. 'Hub '..' ['.. string.format('%02X',hubnode) .. ']'
      outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> Route: ".."</em>" .. device_route
      outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> Metrics Update: ".."</em>".. device_mesh.updatedTime
      local device_metrics = string.format('Msg Transmitted: %s, Received: %s', device_mesh.metrics.totalTransmittedMessages, device_mesh.metrics.totalReceivedMessages)
      outputString = outputString .. " <BR>".. device_metrics
      device_metrics = string.format('Msg Failed: %s, Duplicate: %s', device_mesh.metrics.transmitFailures, device_mesh.metrics.duplicateMessages)
      outputString = outputString .. " <BR>".. device_metrics ]]

      return outputString
  end
end

---Format row HTML
local function format_row(key, value)
  local str = "<tr> <th align=left>" .. key .. "</th> <td>" .. value .. "</td></tr>"
  return str
end

-- print values in text format
local function print_text_values(device, parent_device)
  print("<< print_values >>")
  if device.network_type == "DEVICE_EDGE_CHILD" then

    -- print data in text format
    local mfr_id = string.format("manufacturerId: 0x%04X",parent_device.zwave_manufacturer_id)
    local prd_type = string.format("productType: 0x%04X",parent_device.zwave_product_type)
    local prd_id = string.format("productId: 0x%04X",parent_device.zwave_product_id)
    device:emit_event(manufacturer.manufacturer(mfr_id))
    device:emit_event(product_Type.productType(prd_type))
    device:emit_event(product_Id.productId(prd_id))

    local dni = "DNI: 0x".. parent_device.device_network_id
    local firmware = "Firmaware: " .. parent_device:get_field("firmVersion")
    local library = "Library: " .. parent_device:get_field("library")
    local protocol = "Zw Protocol: " .. parent_device:get_field("zwProtocol")
    local str = dni .. ", ".. firmware ..", ".. library .. ", " .. protocol
    device:emit_event(command_Class.commandClass({value = str}, { state_change = true }))

    device.thread:call_with_delay(2, function(d)
      local command_classes = ""
      if(parent_device.zwave_endpoints ~= nil) then
        for index, endpoint in pairs(parent_device.zwave_endpoints) do 
          command_classes = command_classes .."(Ep" .. index .."): "
          for _, cc in ipairs(endpoint.command_classes) do
            command_classes = command_classes .. string.format("%s, ", zw.cc_to_string(cc.value))
          end
        end
        command_classes = string.format("%s", command_classes:sub(1, -3))
        device:emit_event(command_Class.commandClass({value = command_classes},{ state_change = true }))
      end
    end)
  end
end

--Emit Manufacturer and model
local function added_handler(self, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then

    ---Initial variables values
    if device:get_field("parameter_number") == nil then device:set_field("parameter_number", 1) end
    if device:get_field("parameter_value_set") == nil then device:set_field("parameter_value_set", 0) end
    if device:get_field("parameter_size_set") == nil then device:set_field("parameter_size_set", 1) end
    if device:get_field("config_action") == nil then device:set_field("config_action", "Select") end
    if device:get_field("group_value_start") == nil then device:set_field("group_value_start", 1) end
    if device:get_field("group_value_end") == nil then device:set_field("group_value_end", 10) end
    if device:get_field("group_value") == nil then device:set_field("group_value", 0) end
    if device:get_field("group_Command") == nil then device:set_field("group_Command", "Get") end
    if device:get_field("node_value_set") == nil then device:set_field("node_value_set", 0) end
    if device:get_field("node_value_Hex_set") == nil then device:set_field("node_value_Hex_set", "-") end
    if device:get_field("node_endpoint_value_set") == nil then device:set_field("node_endpoint_value_set", 0) end
    if device:get_field("device_Association_Type_value") == nil then device:set_field("device_Association_Type_value", "Single") end
    if device:get_field("parameter_value_start") == nil then device:set_field("parameter_value_start", 1) end
    if device:get_field("parameter_value_end") == nil then device:set_field("parameter_value_end", 25) end
    if device:get_field("wake_up_value_set") == nil then device:set_field("wake_up_value_set", 0) end

    local component = device.parent_assigned_child_key
    local parent_device = device:get_parent_device()

    if device.preferences.changeConfigProfile == "Info" then
      --print("<<<<<<<< device:get_field(firmVersion)",parent_device:get_field("firmVersion"))
      --print("<<<<<<<< device:get_field(library)",parent_device:get_field("library"))
      --print("<<<<<<<< device:get_field(zwProtocol)",parent_device:get_field("zwProtocol"))
      if parent_device:get_field("firmVersion") == nil or parent_device:get_field("library") == nil or parent_device:get_field("zwProtocol") == nil then   
        parent_device:send(Version:Get({}))
        return
      end
  
      --print values in text format
      print_text_values(device, parent_device)

      local device_info = debug_pretty_print(device, parent_device)
      print(">>> Device Info:", device_info)
      local str = "<table style='font-size:55%'> <tbody>"
      str = str .. format_row('', device_info)
      str = str .. "</tbody></table>"
      device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))

    elseif device.preferences.changeConfigProfile == "Config" then
      --initial values
      device:emit_event(device_Parameter.deviceParameter({value = device:get_field("parameter_number")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(parameter_Size.parameterSize({value = device:get_field("parameter_size_set")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(parameter_Value.parameterValue({value = device:get_field("parameter_value_set")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(command_Config.commandConfig({value = device:get_field("config_action")}, {visibility = {displayed = false }, state_change = true}))
      -- print instructions
      outputString = ""
      outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device Parameter GET: ".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Parameter Number.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Select GET Command Option.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 3- If device is Asleep: Awake device manually.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 4- Press Action Button.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 5- Parameter Value & Size will be shown".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> Negative Values can represent the 2's Complement of a positive value:".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> Example, value -1 (Size 1) is positive value 255 (-1 + 256)".."</em>"
      outputString = outputString .." <BR>".. "<em style='color:red;font-weight: bold;'> Z-Wave Device Parameter SEND: ".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Parameter Number.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Enter Parameter Size.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> Size 1: 0-255(send -128 to 127)".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> Size 2: 0-65535(send -32768 to 32767)".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> Size 4: 0-4294967295(send -2147483648 to 2147483647)".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 3- Enter Parameter Value.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 4- Select SEND Command Option.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 5- If device is Asleep: Awake device manually.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 6- Press Action Button.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 7- Parameter Value & Size will be shown".."</em>"

      local str = "<table style='font-size:60%'> <tbody>"
      str = str .. format_row('', outputString)
      str = "HTLM Text with instructions: ".. str .. "</tbody></table>" 
      device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))

    elseif device.preferences.changeConfigProfile == "WakeUp" then
      if not parent_device:is_cc_supported(cc.WAKE_UP) then
        outputString = ""
        outputString = "<em style='color:red;font-weight: bold;'> Z-Wave Device C.Class WAKE UP NOT SUPPORTED: ".."</em>"
      else
        device:send(WakeUp:IntervalGet({}))
        device:emit_event(command_Config.commandConfig({value = device:get_field("config_action")}, {visibility = {displayed = false }, state_change = true}))
        -- print instructions
        outputString = ""
        outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device Wake Up Interval GET: ".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Select GET Command Option.".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- If device is Awake: Press Action Button.".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 3- If device is Asleep: Awake device manually.".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 4- Wake Up interval in Sec. will be shown".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> Z-Wave Device Wake Up Interval SET: ".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Wake Up interval in Seconds.".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Select SET Command Option.".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 3- If device is Awake: Press Action Button.".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 4- If device is Asleep: Awake device manually.".."</em>"
        outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 5- Wake Up interval in Sec. will be shown".."</em>"
      end
        local str = "<table style='font-size:60%'> <tbody>"
        str = str .. format_row('', outputString)
        str = "HTLM Text with instructions: ".. str .. "</tbody></table>" 
        device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))
        device:emit_event(wake_Up_Value.wakeUpValue({value = 0}, {visibility = {displayed = false }, state_change = true}))

    elseif device.preferences.changeConfigProfile == "Param" then
      device:emit_event(parameter_Start.parameterStart({value = device:get_field("parameter_value_start")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(parameter_End.parameterEnd({value = device:get_field("parameter_value_end")}, {visibility = {displayed = false }, state_change = true}))
      -- print instructions
      outputString = ""
      outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device Parameters Scan: ".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Parameter Number to Start.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Enter Parameter Number to End.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 3- If device is Asleep: Awake device manually.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 4- Press Action Button.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 5- Parameter Number, Value & Size will be shown".."</em>"

      local str = "<table style='font-size:60%'> <tbody>"
      str = str .. format_row('', outputString)
      str = "HTLM Text with instructions: ".. str .. "</tbody></table>" 
      device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))

    elseif device.preferences.changeConfigProfile == "GroupScan" then
      device:emit_event(group_Number_Start.groupNumberStart({value = device:get_field("group_value_start")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(group_Number_End.groupNumberEnd({value = device:get_field("group_value_end")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(device_Association_Type.deviceAssociationType({value = device:get_field("device_Association_Type_value")}, {visibility = {displayed = false }, state_change = true}))
          -- print instructions
      outputString = ""
      outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device Association Groups Scan: ".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Group Number to Start.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Enter Group Number to End.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 3- Select Single or Multi Channel Device.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 4- If device is Asleep: Awake device manually.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 5- Press Action Button.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 6- Groups Numbers & Nodes will be shown".."</em>"

      local str = "<table style='font-size:60%'> <tbody>"
      str = str .. format_row('', outputString)
      str = "HTLM Text with instructions: ".. str .. "</tbody></table>" 
      device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))
      device:emit_event(command_Class.commandClass("waiting ..."))

    elseif device.preferences.changeConfigProfile == "Group" then
      device:emit_event(group_Number.groupNumber({value = device:get_field("group_value")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(device_Association_Type.deviceAssociationType({value = device:get_field("device_Association_Type_value")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(node_End_Point.nodeEndPoint({value = device:get_field("node_endpoint_value_set")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(node_To_Write_Hex.nodeToWrite({value = device:get_field("node_value_Hex_set")}, {visibility = {displayed = false }, state_change = true}))
      device:emit_event(group_Command_Option.groupCommandOption({value = device:get_field("group_Command")}, {visibility = {displayed = false }, state_change = true}))
      -- print instructions
      outputString = ""
      outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device Assocition Group GET: ".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Group Number.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Select Single or Multi Channel Device.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 3- Select GET Command Option.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 4- If device is Asleep: Awake device manually.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 5- Press Action Button.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 6- Groups Number & Nodes will be shown".."</em>"
      outputString = outputString .." <BR>".. "<em style='color:red;font-weight: bold;'> Z-Wave Device Assocition Group SET:".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Group Number.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Select Single or Multi Channel Device".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 3- Enter Node Number in Hex Format.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 4- Enter End Point for Multi Channel Only.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 5- Select SET Command Option.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 6- If device is Asleep: Awake device manually.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 7- Press Action Button.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 8- Groups Number & Nodes will be shown".."</em>"
      outputString = outputString .. " <BR>".."<em style='color:blue;font-weight: bold;'> Z-Wave Device Assocition Group REMOVE ALL NODES:".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Group Number.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Select Single or Multi Channel Device.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 3- Select Remove All Nodes Option.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 4- If device is Asleep: Awake device manually.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 5- Press Action Button.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 6- Groups Number & Nodes will be shown".."</em>"
      outputString = outputString .. " <BR>".."<em style='color:blue;font-weight: bold;'> Z-Wave Device Assocition Group REMOVE ONE NODE:".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 1- Enter Group Number.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 2- Select Single or Multi Channel Device.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 3- Select Remove One Node Option.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> * 4- If device is Asleep: Awake device manually.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:black;font-weight: bold;'> 5- Press Action Button.".."</em>"
      outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> 6- Groups Number & Nodes will be shown".."</em>"

      local str = "<table style='font-size:60%'> <tbody>"
      str = str .. format_row('', outputString)
      str = "HTLM Text with instructions: ".. str .. "</tbody></table>" 
      device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))
      device:emit_event(command_Class.commandClass("waiting ..."))

    else
      local device_info = debug_pretty_print(device, parent_device)
      print(">>> Device Info:", device_info)
      local str = "<table style='font-size:60%'> <tbody>"
      str = str .. format_row('', device_info)
      str = str .. "</tbody></table>"  
      device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))
    end
  else
    device:default_refresh()
  end
end

-- device init
local function do_init(self, device)
  if device.network_type == "DEVICE_EDGE_CHILD" then
    local parent_device = device:get_parent_device()
    if device.preferences.changeConfigProfile == "Info" then
      device:try_update_metadata({profile = "zwave-device-info"})
    elseif device.preferences.changeConfigProfile == "Config" then
      device:try_update_metadata({profile = "zwave-config"})
    --elseif device.preferences.changeConfigProfile == "WakeUp" then
      --device:try_update_metadata({profile = "zwave-device-wakeup"})
    elseif device.preferences.changeConfigProfile == "Param" then
      device:try_update_metadata({profile = "zwave-parameter-info"})
    elseif device.preferences.changeConfigProfile == "GroupScan" then
      device:try_update_metadata({profile = "zwave-device-groups-scan"})
    elseif device.preferences.changeConfigProfile == "Group" then
      device:try_update_metadata({profile = "zwave-device-groups"})
    else
      device:try_update_metadata({profile = "zwave-device-info"})
      parent_device:send(Version:Get({}))
    end
    added_handler(self, device)
  else
      device:set_update_preferences_fn(preferencesMap.update_preferences)
  end
end

--- device Configuration report to habdler device responses to Parameters anf groups association
local function configuration_report_handler(driver, device, cmd)
  print("<<<< configuration_report in device-config subdriver >>>>")
  --local child_device = device:get_child_by_parent_assigned_key("config")
  --print("<<< Child_device:",child_device)
  --print("<<< child_device.preferences.changeConfigProfile:",child_device.preferences.changeConfigProfile)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then

    local child_device = device:get_child_by_parent_assigned_key("config")

    child_device:set_field("parameter_number", cmd.args.parameter_number)
    child_device:set_field("parameter_value_set", cmd.args.configuration_value)
    child_device:set_field("parameter_size_set", cmd.args.size)

    ---- code for child device Configuration parameters
    --local child_device = device:get_child_by_parent_assigned_key("config")
    if child_device ~= nil then
      --- Parameter configure
      if child_device.preferences.changeConfigProfile == "Config" then
        if child_device:get_field("parameter_number") ~= nil then
          child_device:emit_event(device_Parameter.deviceParameter({value = child_device:get_field("parameter_number")}, {visibility = {displayed = false }, state_change = true}))
          child_device:emit_event(parameter_Value.parameterValue({value = child_device:get_field("parameter_value_set")}, {visibility = {displayed = false }, state_change = true}))
          child_device:emit_event(parameter_Size.parameterSize({value = child_device:get_field("parameter_size_set")}, {visibility = {displayed = false }, state_change = true}))
        end
      --- Parameter Sacan
      elseif child_device.preferences.changeConfigProfile == "Param" then
        
        print("<<< scaned_number_Report",scaned_number)
        print("<<< parameter_value_start_Report",child_device:get_field("parameter_value_start"))

        --if scaned_number == parameter_value_start then
        if outputString == "Waiting for device response" then
          outputString = ""
          outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Scaned Device Parameters: ".."</em>"
          outputString_text = "Z-Wave Scaned Device Parameters: "
        end
        if child_device:get_field("parameter_number") ~= nil then
          outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> Parameter :".."</em>".. child_device:get_field("parameter_number") .. "<em style='color:red;font-weight: bold;'> Size :".."</em>".. child_device:get_field("parameter_size_set") .. "<em style='color:red;font-weight: bold;'> Value: ".."</em>".. child_device:get_field("parameter_value_set")
          outputString_text = "Parameter: ".. child_device:get_field("parameter_number") .. ", Size: ".. child_device:get_field("parameter_size_set") .. ", Value: ".. child_device:get_field("parameter_value_set") ..", "
        end
        local str = "<table style='font-size:60%'> <tbody>"
        str = str .. format_row('', outputString)
        str = str .. "</tbody></table>"
        
        child_device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))
        child_device:emit_event(command_Class.commandClass(outputString_text))

      end
    end
  end
end

-- MultiChannelAssociation_report_handler
local function Association_report_handler(driver, device, cmd)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then
    local child_device = device:get_child_by_parent_assigned_key("config")
    if child_device ~= nil then
      local hubnode = child_device.driver.environment_info.hub_zwave_id
      local is_hub_node = ""
      print("hubnode =", hubnode)
      local group_identifier = cmd.args.grouping_identifier
      local max_nodes_supported= cmd.args.max_nodes_supported
      local node_ids = cmd.args.node_ids
      --print("table node_ids >>>>>>",utils.stringify_table(node_ids))
      print("group_identifier =",group_identifier)
      print("max_nodes_supported =",max_nodes_supported)
      if max_nodes_supported > 0 then
        for node = 1, max_nodes_supported do
            print("<<<<node_ids[node]:", node_ids[node])
        end
      end

      --- Groups Scan Group Get, Set and remove One node
      print("<< Groups Scan Single>>")
      
      if outputString == "Waiting for device response" then
        outputString = ""
        if child_device.preferences.changeConfigProfile == "GroupScan" then
          outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Scanned Single-Channel Association: ".."</em>"
        else
          outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device Single-Channel Association: ".."</em>"
        end
      end
      if group_identifier ~= nil and group_identifier > 0 then
        if max_nodes_supported > 0 then
          outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> Group : ".."</em>".. group_identifier .. "<em style='color:red;font-weight: bold;'>   Max Nodes Supported : ".."</em>".. max_nodes_supported
          outputString_text = "Group : ".. group_identifier .. ", Max Nodes Supported : ".. max_nodes_supported
          for node = 1, max_nodes_supported do
            if node_ids[node] ~= nil then
              print("<<<<node_ids["..node.."]: ".. node_ids[node])
              if node_ids[node] == hubnode then is_hub_node = "* Hub Node *" end

              ---- remove one node ----
              if node_ids[node] == child_device:get_field("node_value_set") and child_device:get_field("group_Command") == "RemoveOne" then
                print("<< Remove one group >>")
                node_ids[node] = nil
                device:send(Association:Remove({grouping_identifier = child_device:get_field("group_value"), node_ids = {}}))

                -- move next node_ids to removed nil position
                for node1 = node, max_nodes_supported do
                  --print("node_ids[node1]",node_ids[node1])
                  node_ids[node1] = node_ids[node1 + 1]
                  --print("node_ids[node1 + 1]",node_ids[node1 + 1])
                  if node1 < max_nodes_supported then node_ids[node1 + 1]= nil end
                end

                -- Set new node_ids values ----
                device:send(Association:Set({grouping_identifier = child_device:get_field("group_value"), node_ids = node_ids}))
                --re-write multichannels nodes
                device:send(MultiChannelAssociation:Set({grouping_identifier = child_device:get_field("group_value"), multi_channel_nodes = multi_channel_nodes}))

                -- Get new nodes values
                device:set_field("group_Command","Get")
                child_device:emit_event(group_Command_Option.groupCommandOption({value = child_device:get_field("group_Command")}, {visibility = {displayed = false }, state_change = true}))
                --outputString =" "
                outputString = "Waiting for device response"
                child_device:emit_event(device_Info.deviceInfo({value = outputString}, {visibility = {displayed = false }}))
                device.thread:call_with_delay(2, 
                  function(d)
                    device:send(Association:Get({grouping_identifier = child_device:get_field("group_value")}))
                  end
                  , "get group") 
                return
              end
              outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> * Node-".. node..":  ".."</em>".. " "..string.format(" (0x%02X)",node_ids[node]) .. "<em style='color:blue;font-weight: bold;'> " .. is_hub_node .."</em>"
              outputString_text = outputString_text.. ", [Node-".. node..":  "..string.format(" (0x%02X)",node_ids[node]) .. is_hub_node .. "]"

            --- detect first nil node_ids value to set a new value
          elseif node_ids[node] == nil and child_device:get_field("group_Command") == "Set" then
            node_ids[node] = child_device:get_field("node_value_set")
            device:send(Association:Set({grouping_identifier = child_device:get_field("group_value"), node_ids = node_ids}))
            device:set_field("group_Command", "Get")
            child_device:emit_event(group_Command_Option.groupCommandOption({value = child_device:get_field("group_Command")}, {visibility = {displayed = false }, state_change = true}))
            --outputString =" "
            outputString = "Waiting for device response"
            child_device:emit_event(device_Info.deviceInfo({value = outputString}, {visibility = {displayed = false }}))
            device.thread:call_with_delay(2, 
              function(d)
                device:send(Association:Get({grouping_identifier = child_device:get_field("group_value")}))
              end
              , "get group") 
            return
          end
        end

          -- HTLM format to outputString
          local str = "<table style='font-size:60%'> <tbody>"
          str = str .. format_row('', outputString)
          str = str .. "</tbody></table>"
          
          child_device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))
          child_device:emit_event(command_Class.commandClass({value = outputString_text},{ state_change = true }))
        end
      end
    end
  end
end


--- MultiChannelAssociation_report_handler
local function MultiChannelAssociation_report_handler(driver, device, cmd)

  if device.network_type ~= "DEVICE_EDGE_CHILD" then

    print("<<<  MultiChannelAssociation_report_handler >>>")

    local child_device = device:get_child_by_parent_assigned_key("config")
    if child_device ~= nil then
      if child_device:get_field("device_Association_Type_value") == "Multi" then
        print("<< Groups Scan Multi>>")
        local hubnode = device.driver.environment_info.hub_zwave_id
        local is_hub_node = ""
        print("hubnode =", hubnode)
        local group_identifier = cmd.args.grouping_identifier
        local max_nodes_supported= cmd.args.max_nodes_supported
        local node_ids_multi = cmd.args.node_ids
        --print("table node_ids >>>>>>",utils.stringify_table(node_ids))
        print("group_identifier =",group_identifier)
        print("max_nodes_supported =",max_nodes_supported)
        if max_nodes_supported > 0 then
          for node = 1, max_nodes_supported do
              print("<<<<node_ids_multi[node]:", node_ids_multi[node])
          end
        end
        multi_channel_nodes = cmd.args.multi_channel_nodes
        --print("Multi-group_identifier:", group_identifier)
        --print("Multi-max_nodes_supported:", max_nodes_supported)
        --print("multi_channel_nodes:",multi_channel_nodes)
        --print("multi-node_ids:",node_ids)
      
        if outputString == "Waiting for device response" then
          outputString = ""
          if device.preferences.changeConfigProfile == "GroupScan" then
            outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Scanned Multi-Channel Association: ".."</em>"
          else
            outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device Multi-Channel Association: ".."</em>"
          end
        end
        if max_nodes_supported > 0 then
          outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> Group : ".."</em>".. group_identifier .. "<em style='color:red;font-weight: bold;'>   Max Nodes Supported : ".."</em>".. max_nodes_supported
          outputString_text = "Group : ".. group_identifier .. ", Max Nodes Supported : ".. max_nodes_supported
            for node = 1, max_nodes_supported do
              if multi_channel_nodes[node] ~= nil then
                --print("<<<<node_ids_multi["..node.."]: ".. node_ids_multi[node])
                if multi_channel_nodes[node].multi_channel_node_id == hubnode then is_hub_node = "* Hub Node *" end

                --print("multi_channel_nodes[node].multi_channel_node_id:",multi_channel_nodes[node].multi_channel_node_id)
                --print("multi_channel_nodes[node].end_point:",multi_channel_nodes[node].end_point)

              ---- remove one node ----
                if multi_channel_nodes[node].multi_channel_node_id == child_device:get_field("node_value_set") and multi_channel_nodes[node].end_point == child_device:get_field("node_endpoint_value_set") and child_device:get_field("group_Command") == "RemoveOne" then
                  print("<< Remove one group >>")
                  multi_channel_nodes[node]= {}
                  print("multi_channel_nodes[node].multi_channel_node_id:",multi_channel_nodes[node].multi_channel_node_id)
                  print("multi_channel_nodes[node].end_point:",multi_channel_nodes[node].end_point)
                    
                  device:send(MultiChannelAssociation:Remove({grouping_identifier = child_device:get_field("group_value"), multi_channel_nodes = {}}))

                  -- move next node_ids to removed nil position
                  for node1 = node, max_nodes_supported do
                    --print("node_ids[node1]",node_ids[node1])
                    multi_channel_nodes[node1]= multi_channel_nodes[node1 + 1]
                    --print("node_ids[node1 + 1]",node_ids[node1 + 1])
                    if node1 < max_nodes_supported then 
                      multi_channel_nodes[node1 +1]= {}
                    end
                  end

                  -- Set new node_ids values ----
                  device:send(MultiChannelAssociation:Set({grouping_identifier = child_device:get_field("group_value"), node_ids = node_ids_multi, multi_channel_nodes = multi_channel_nodes}))

                  -- Get new nodes values
                  device:set_field("group_Command", "Get")
                  child_device:emit_event(group_Command_Option.groupCommandOption({value = child_device:get_field("group_Command")}, {visibility = {displayed = false }, state_change = true}))
                  --outputString =" "
                  outputString = "Waiting for device response"
                  child_device:emit_event(device_Info.deviceInfo({value = outputString}, {visibility = {displayed = false }}))
                  device.thread:call_with_delay(2, 
                    function(d)
                      device:send(MultiChannelAssociation:Get({grouping_identifier = child_device:get_field("group_value")}))
                    end
                      , "get group") 
                  return

                end
                outputString = outputString .. " <BR>".. "<em style='color:green;font-weight: bold;'> * Node-".. node..": ".."</em>".. " "..string.format(" (0x%02X)", multi_channel_nodes[node].multi_channel_node_id) ..",End Point: ".. multi_channel_nodes[node].end_point .. "<em style='color:blue;font-weight: bold;'> " .. is_hub_node .."</em>"
                outputString_text = outputString_text .. ", [Node-".. node..": "..string.format(" (0x%02X)", multi_channel_nodes[node].multi_channel_node_id) ..", End Point: ".. multi_channel_nodes[node].end_point .. is_hub_node .. "]"
                
              elseif multi_channel_nodes[node] == nil and child_device:get_field("group_Command") == "Set" then
                node_ids_multi[node] = child_device:get_field("node_value_set")
                  multi_channel_nodes[node]= {multi_channel_node_id = node_ids_multi[node] , end_point = child_device:get_field("node_endpoint_value_set")}
                device:send(MultiChannelAssociation:Set({grouping_identifier = child_device:get_field("group_value"), multi_channel_nodes = multi_channel_nodes}))
                device:set_field("group_Command", "Get")
                child_device:emit_event(group_Command_Option.groupCommandOption({value = child_device:get_field("group_Command")}, {visibility = {displayed = false }, state_change = true}))
                --outputString =" "
                outputString = "Waiting for device response"
                child_device:emit_event(device_Info.deviceInfo({value = outputString}, {visibility = {displayed = false }}))
                device.thread:call_with_delay(2, 
                  function(d)
                    device:send(MultiChannelAssociation:Get({grouping_identifier = child_device:get_field("group_value")}))
                  end
                  , "get group") 
                return
              end
            end

            -- HTLM format to outputString
            local str = "<table style='font-size:60%'> <tbody>"
            str = str .. format_row('', outputString)
            str = str .. "</tbody></table>"
                
            child_device:emit_event(device_Info.deviceInfo({value = str}, {visibility = {displayed = true }}))
            child_device:emit_event(command_Class.commandClass({value = outputString_text},{ state_change = true }))
          end
      end
    end
  end 
end

--- version_report_handler
local function version_report_handler(driver, device, cmd)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then
    device:set_field("firmVersion",cmd.args.application_version.."."..cmd.args.application_sub_version)
    device:set_field("library",cmd.args.z_wave_library_type)
    device:set_field("zwProtocol",cmd.args.z_wave_protocol_version.."."..cmd.args.z_wave_protocol_sub_version)
    local child_device = device:get_child_by_parent_assigned_key("config")
    added_handler(driver, child_device)
  end
end

-- wakeup_interval_report
local function wakeup_interval_report(driver, device, cmd)
  print("<<<< cmd.args.seconds: ",cmd.args.seconds)
  device:set_field("wake_up_value_set", cmd.args.seconds)
  --local component = device:endpoint_to_component(cmd.src_channel)
  local child_device = device:get_child_by_parent_assigned_key("config")
  if child_device ~= nil then
    child_device:emit_event(wake_Up_Value.wakeUpValue({value = child_device:get_field("wake_up_value_set")}, {visibility = {displayed = false }, state_change = true}))
  end

  device:default_refresh()
end

-- wakeup_notification_handler
local function wakeup_notification_handler(driver, device, cmd)
  --local component = device:endpoint_to_component(cmd.src_channel)
  local child_device = device:get_child_by_parent_assigned_key("config")
  if child_device ~= nil then
    if child_device.preferences.changeConfigProfile == "WakeUp" then
      if child_device:get_field("config_action") == "Send" then
        if child_device.preferences.changeConfigProfile == "WakeUp" then
          if device:is_cc_supported(cc.WAKE_UP) and child_device:get_field("wake_up_value_set") ~= nil then
            local hub_node_id = driver.environment_info.hub_zwave_id
            device:send(WakeUp:IntervalSet({node_id = hub_node_id, seconds = child_device:get_field("wake_up_value_set")}))
          end
          child_device:set_field("config_action", "Get")
          device.thread:call_with_delay(2, function()
            device:send(WakeUp:IntervalGet({}))
          end)
        end
      --- Parameter Get  
      elseif child_device:get_field("config_action") == "Get" then
        if child_device.preferences.changeConfigProfile == "WakeUp" then
          if device:is_cc_supported(cc.WAKE_UP) then
            device:send(WakeUp:IntervalGet({}))
          end
        end
      end
    end
    child_device.thread:call_with_delay(2, function()
      child_device:emit_event(command_Config.commandConfig({value = child_device:get_field("config_action")}, {visibility = {displayed = false }, state_change = true}))
    end)
  end
  device:default_refresh()
end

------ custom capabilities handlers -------------------------------------

--command_Config_handler
local function command_Config_handler(driver, device, command)
  print("<<< Config Command:", command.args.value)
  device:set_field("config_action", command.args.value)

  device:emit_event(command_Config.commandConfig({value = device:get_field("config_action")}, {visibility = {displayed = false }, state_change = true}))

end

--command_command_Action_button_handler
local function command_Action_button_handler(driver, device, command)
  print("<<< Action_button:", command.args.value)
  local parent_device = device:get_parent_device()
  if device.preferences.changeConfigProfile == "Param" or device.preferences.changeConfigProfile == "GroupScan" or device.preferences.changeConfigProfile == "Group" then

    --- handler for parameters sacan
    if device.preferences.changeConfigProfile == "Param" then
      outputString = "Waiting for device response"
      device:emit_event(device_Info.deviceInfo({value = outputString}, {visibility = {displayed = false }}))
      scaned_number = device:get_field("parameter_value_start") - 1
      for scan_number = device:get_field("parameter_value_start"), device:get_field("parameter_value_end") do
        device.thread:call_with_delay(0, function()
          scaned_number = scaned_number + 1
          parent_device:send(Configuration:Get({ parameter_number = scaned_number }))
          print("<<<<  new scaned_number:", scaned_number)
        end)
      end
    --- handler for groups sacan
    elseif device.preferences.changeConfigProfile == "GroupScan" then
      outputString = "Waiting for device response"
      device:emit_event(device_Info.deviceInfo({value = outputString}, {visibility = {displayed = false }}))
      scaned_number = device:get_field("group_value_start") - 1
      for scan_number = device:get_field("group_value_start"), device:get_field("group_value_end") do
        --scaned_number = scan_number
        device.thread:call_with_delay(0, function()
          scaned_number = scaned_number + 1
          if device:get_field("device_Association_Type_value") == "Single" then
            parent_device:send(Association:Get({grouping_identifier = scaned_number}))
          elseif device:get_field("device_Association_Type_value") == "Multi" then
            parent_device:send(MultiChannelAssociation:Get({grouping_identifier = scaned_number}))
          end
          print("<<<<  new Group_number:", scaned_number)
        end)
      end
    -- Group Get, Set, Remove All and remove One
    elseif device.preferences.changeConfigProfile == "Group" then
      if device:get_field("group_Command") == "Get" or device:get_field("group_Command") == "Set" or device:get_field("group_Command") == "RemoveOne" then
        if device:get_field("device_Association_Type_value") == "Single" then
          local delay = 0
          if device:get_field("group_Command") == "RemoveOne" then
            -- get multichannel nodes in order to rewrite them after delete nodes for single channel
            delay = 2
            parent_device:send(MultiChannelAssociation:Get({grouping_identifier = device:get_field("group_value")}))
          end
          device.thread:call_with_delay(delay, 
            function(d)
              parent_device:send(Association:Get({grouping_identifier = device:get_field("group_value")}))
            end
            , "get group")
          --device:send(Association:Get({grouping_identifier = group_value}))
        elseif device:get_field("device_Association_Type_value") == "Multi" then
          parent_device:send(MultiChannelAssociation:Get({grouping_identifier = device:get_field("group_value")}))
        end
        outputString = "Waiting for device response"
        return

      elseif device:get_field("group_Command") == "Remove" then
        if device:get_field("group_value") == 0 then return end
        if device:get_field("device_Association_Type_value") == "Single" then
          parent_device:send(Association:Remove({grouping_identifier = device:get_field("group_value"), node_ids = {}}))
          device.thread:call_with_delay(2, 
            function(d)
              parent_device:send(Association:Get({grouping_identifier = device:get_field("group_value")}))
            end
            , "get group") 
          --return
        elseif device:get_field("device_Association_Type_value") == "Multi" then
          --device:send(MultiChannelAssociation:Remove({grouping_identifier = group_value, node_ids = {}, multi_channel_nodes = {}}))
          --device:send(MultiChannelAssociation:Remove({grouping_identifier = group_value, node_ids = {}}))
          parent_device:send(MultiChannelAssociation:Remove({grouping_identifier = device:get_field("group_value"), multi_channel_nodes = {}}))
          device.thread:call_with_delay(2, 
          function(d)
            device:send(MultiChannelAssociation:Get({grouping_identifier = device:get_field("group_value")}))
          end
          , "get group") 
          --return
        end
          device:set_field("group_Command", "Get")
          device:emit_event(group_Command_Option.groupCommandOption({value = device:get_field("group_Command")}, {visibility = {displayed = false }, state_change = true}))
          outputString ="Waiting for device response"
          device:emit_event(device_Info.deviceInfo({value = outputString}, {visibility = {displayed = false }}))
          return
      end
    end
  else
    --- Parameter send
    if device:get_field("config_action") == "Send" then
      if device.preferences.changeConfigProfile == "Config" then
        --2's complement value if needed
        local parameter_value_send = device:get_field("parameter_value_set")
        if device:get_field("parameter_size_set") == 4 and device:get_field("parameter_value_set") > 2147483647 then
          parameter_value_send = device:get_field("parameter_value_set") - 4294967296
        elseif device:get_field("parameter_size_set") == 2 and device:get_field("parameter_value_set") > 32767 then
          parameter_value_send = device:get_field("parameter_value_set") - 65536
        elseif device:get_field("parameter_size_set") == 1 and device:get_field("parameter_value_set") > 127 then
          parameter_value_send = device:get_field("parameter_value_set") - 256
        end
        print("new_parameter_value Sent >>>>",parameter_value_send)

        -- Sent configuration parameter to device
        parent_device:send(Configuration:Set({parameter_number = device:get_field("parameter_number"), size = device:get_field("parameter_size_set"), configuration_value = parameter_value_send}))
        
        --Get value set
        device:set_field("config_action", "Get")
        device.thread:call_with_delay(2, function()
          parent_device:send(Configuration:Get({ parameter_number = device:get_field("parameter_number") }))
        end)

      elseif device.preferences.changeConfigProfile == "WakeUp" then
        if device:is_cc_supported(cc.WAKE_UP) and device:get_field("wake_up_value_set") ~= nil then
          local hub_node_id = driver.environment_info.hub_zwave_id
          device:send(WakeUp:IntervalSet({node_id = hub_node_id, seconds = device:get_field("wake_up_value_set")}))
          device.thread:call_with_delay(2, function()
            device:send(WakeUp:IntervalGet({}))
          end)
        elseif not device:is_cc_supported(cc.WAKE_UP) then
          device:emit_event(command_Class.commandClass("C.Class WAKE UP NOT SUPPORTED"))
        end
        device:set_field("config_action", "Get")
      end

    --- Parameter Get 
    elseif device:get_field("config_action") == "Get" then
      if device.preferences.changeConfigProfile == "Config" then
        parent_device:send(Configuration:Get({ parameter_number = device:get_field("parameter_number")}))
      elseif device.preferences.changeConfigProfile == "WakeUp" then
        if device:is_cc_supported(cc.WAKE_UP) then
          device:send(WakeUp:IntervalGet({}))
        elseif not device:is_cc_supported(cc.WAKE_UP) then
          device:emit_event(command_Class.commandClass("C.Class WAKE UP NOT SUPPORTED"))
        end
      end

    --[[elseif device:get_field("config_action") == "Select" then
      if device.preferences.changeConfigProfile == "Config" then

        device:set_field("parameter_number",1)
        device:set_field("parameter_value_set",0)
        device:set_field("parameter_size_set",1)

        device:emit_event(device_Parameter.deviceParameter({value = device:get_field("parameter_number")}, {visibility = {displayed = false }, state_change = true}))
        device:emit_event(parameter_Value.parameterValue({value = device:get_field("parameter_value_set")}, {visibility = {displayed = false }, state_change = true}))
        device:emit_event(parameter_Size.parameterSize({value = device:get_field("parameter_size_set")}, {visibility = {displayed = false }, state_change = true}))
        return
      end]]
    end

    device.thread:call_with_delay(2, function()
      device:emit_event(command_Config.commandConfig({value = device:get_field("config_action")}, {visibility = {displayed = false }, state_change = true}))
    end)
  end
end

---device_Parameter_handler
local function device_Parameter_handler(driver, device, command)
  print("<<< device_Parameter:", command.args.value)
  device:set_field("parameter_number",command.args.value)

  device:emit_event(device_Parameter.deviceParameter({value = device:get_field("parameter_number")}, {visibility = {displayed = false }, state_change = true}))
end

--- parameter_Size_handler
local function parameter_Size_handler(driver, device, command)
  print("<<< parameter_Size:", command.args.value)
  device:set_field("parameter_size_set",command.args.value)

  device:emit_event(parameter_Size.parameterSize({value = device:get_field("parameter_size_set")}, {visibility = {displayed = false }, state_change = true}))
end

---parameter_Value_handler
local function parameter_Value_handler(driver, device, command)
  print("<<< parameter_Value:", command.args.value)
  device:set_field("parameter_value_set",command.args.value)

  device:emit_event(parameter_Value.parameterValue({value = device:get_field("parameter_value_set")}, {visibility = {displayed = false }, state_change = true}))
end

---wake up_Value_handler
local function wake_Up_Value_handler(driver, device, command)
  print("<<< wake_Up_Value:", command.args.value)
  device:set_field("wake_up_value_set", command.args.value)
  device:emit_event(wake_Up_Value.wakeUpValue({value = device:get_field("wake_up_value_set")}, {visibility = {displayed = false }, state_change = true}))
end

---parameter_End_handler
local function parameter_End_handler(driver, device, command)
  print("<<< parameter_value_End:", command.args.value)
  device:set_field("parameter_value_end",command.args.value)

  device:emit_event(parameter_End.parameterEnd({value = device:get_field("parameter_value_end")}, {visibility = {displayed = false }, state_change = true}))
end

---parameter_Start_handler
local function parameter_Start_handler(driver, device, command)
  print("<<< parameter_value_Start:", command.args.value)
  device:set_field("parameter_value_start",command.args.value)

  device:emit_event(parameter_Start.parameterStart({value = device:get_field("parameter_value_start")}, {visibility = {displayed = false }, state_change = true}))
end

---GroupNumber_End_handler
local function groupNumber_End_handler(driver, device, command)
  print("<<< GroupNumber_value_End:", command.args.value)
  device:set_field("group_value_end",command.args.value)

  device:emit_event(group_Number_End.groupNumberEnd({value = device:get_field("group_value_end")}, {visibility = {displayed = false }, state_change = true}))
end

---GroupNumber_Start_handler
local function groupNumber_Start_handler(driver, device, command)
  print("<<< GroupNumber_value_Start:", command.args.value)
  device:set_field("group_value_start",command.args.value)

  device:emit_event(group_Number_Start.groupNumberStart({value = device:get_field("group_value_start")}, {visibility = {displayed = false }, state_change = true}))
end

---GroupNumber_handler
local function groupNumber_handler(driver, device, command)
  print("<<< GroupNumber_value:", command.args.value)
  device:set_field("group_value",command.args.value)

  device:emit_event(group_Number.groupNumber({value = device:get_field("group_value")}, {visibility = {displayed = false }, state_change = true}))
end

--- node_End_Point_handler
local function node_End_Point_handler(driver, device, command)
  print("<<< node_End_Point:", command.args.value)
  device:set_field("node_endpoint_value_set",command.args.value)

  device:emit_event(node_End_Point.nodeEndPoint({value = device:get_field("node_endpoint_value_set")}, {visibility = {displayed = false }, state_change = true}))
end

--- device_Association_Type_handler
local function device_Association_Type_handler(driver, device, command)
  print("<<< device_Association_Type_value:", command.args.value)
  device:set_field("device_Association_Type_value",command.args.value)

  device:emit_event(device_Association_Type.deviceAssociationType({value = device:get_field("device_Association_Type_value")}, {visibility = {displayed = false }, state_change = true}))
end

---node_To_Write_Hex handler
local function node_To_Write_Hex_handler(driver, device, command)
  print("<<< node_To_Write_Hex:", command.args.value)
  local node_value_Hex_set = command.args.value
  --print("<<< node_To_Write_Hex:", node_value_Hex_set)
  local node_value_set = tonumber(node_value_Hex_set, 16)
  device:set_field("node_value_set",node_value_set)
  print("node_value_set_Dec",node_value_set)

  device:emit_event(node_To_Write_Hex.nodeToWrite({value = node_value_Hex_set}, {visibility = {displayed = false }, state_change = true}))
  --device:emit_event(node_To_Write.nodeToWrite({value = node_value_set}, {visibility = {displayed = false }}))
end

--group_Command_Option_handler
local function group_Command_Option_handler(driver, device, command)
  print("<<< group_Command:", command.args.value)
  device:set_field("group_Command",command.args.value)

  device:emit_event(group_Command_Option.groupCommandOption({value = device:get_field("group_Command")}, {visibility = {displayed = false }, state_change = true}))

end

--- peferences infoChanged handler -------------------------------------

local function info_Changed(self, device, event, args)
  local parent_device = device:get_parent_device()
  if device.network_type == "DEVICE_EDGE_CHILD" then
    for id, value in pairs(device.preferences) do
      print("device.preferences[infoChanged]=", device.preferences[id], "preferences: ", id)
      --local oldPreferenceValue = device:get_field(id)
      local oldPreferenceValue = args.old_st_store.preferences[id]
      local newParameterValue = device.preferences[id]
      if oldPreferenceValue ~= newParameterValue then
        --device:set_field(id, newParameterValue, {persist = true})
        print("<< Preference changed name:", id, "old value:", oldPreferenceValue, "new value:", newParameterValue)
        --change profile tile
        if id == "changeConfigProfile" then
          if device.preferences.changeConfigProfile == "Info" then
            device:try_update_metadata({profile = "zwave-device-info"})
            device.thread:call_with_delay(3, function() -- from 1 sec
              parent_device:send(Version:Get({}))
              added_handler(self, device)
            end)
          elseif device.preferences.changeConfigProfile == "Config" then
            device:try_update_metadata({profile = "zwave-config"})
            device:set_field("parameter_number",1)
            device:set_field("parameter_value_set",0)
            device:set_field("parameter_size_set",1)
            parent_device.thread:call_with_delay(3, function()
              added_handler(self, device)
            end)

          elseif device.preferences.changeConfigProfile == "WakeUp" then
            device:try_update_metadata({profile = "zwave-device-wakeup"})
            if parent_device:is_cc_supported(cc.WAKE_UP) then
              parent_device:send(WakeUp:IntervalGet({}))
            end
            device.thread:call_with_delay(3, function()-- from 1 sec
              added_handler(self, device)
            end)
            
          elseif device.preferences.changeConfigProfile == "Param" then
            device:try_update_metadata({profile = "zwave-parameter-info"})
            local parameter_value_start = device:get_latest_state("main", parameter_Start.ID, parameter_Start.parameterStart.NAME)
            --parameter_value_start = 2
            if parameter_value_start == nil then parameter_value_start = 1 end
            device:set_field("parameter_value_start",parameter_value_start)
            local parameter_value_end = device:get_latest_state("main", parameter_End.ID, parameter_End.parameterEnd.NAME)
            if parameter_value_end == nil then parameter_value_end = 25 end
            device:set_field("parameter_value_end",parameter_value_end)
            parent_device.thread:call_with_delay(3, function()
              added_handler(self, device)
            end)
            
          elseif device.preferences.changeConfigProfile == "GroupScan" then
            device:try_update_metadata({profile = "zwave-device-groups-scan"})
            local group_value_start = device:get_latest_state("main", group_Number_Start.ID, group_Number_Start.groupNumberStart.NAME)
            if group_value_start == nil then group_value_start = 1 end
            device:set_field("group_value_start",group_value_start)
            local group_value_end = device:get_latest_state("main", group_Number_End.ID, group_Number_End.groupNumberEnd.NAME)
            if group_value_end == nil then group_value_end = 10 end
            device:set_field("group_value_end",group_value_end)
            parent_device.thread:call_with_delay(3, function()
              added_handler(self, device)
            end)

          elseif device.preferences.changeConfigProfile == "Group" then
            device:try_update_metadata({profile = "zwave-device-groups"})
            local group_value = device:get_latest_state("main", group_Number.ID, group_Number.groupNumber.NAME)
            if group_value == nil then group_value = 1 end
            device:set_field("group_value",group_value)
            local node_value_Hex_set = device:get_latest_state("main", node_To_Write_Hex.ID, node_To_Write_Hex.nodeToWrite.NAME)
            if node_value_Hex_set == nil then node_value_Hex_set = "-" end
            device:set_field("node_value_Hex_set",node_value_Hex_set)

            parent_device.thread:call_with_delay(3, function()
              added_handler(self, device)
            end)
            
          else
            device:try_update_metadata({profile = "zwave-device-info"})
            device.thread:call_with_delay(3, function()-- from 1 sec
              added_handler(self, device)
            end)
          end
        end
      end
    end
  else ------------------- Preferences for parent devices except for fibaro fibaro_door_window_sensor

    local FIBARO_DOOR_WINDOW_SENSOR_FINGERPRINTS = {
      { manufacturerId = 0x010F, prod = 0x0700, productId = 0x1000 }, -- Fibaro Open/Closed Sensor (FGK-10x) / Europe
      { manufacturerId = 0x010F, prod = 0x0700, productId = 0x2000 }, -- Fibaro Open/Closed Sensor (FGK-10x) / NA
      { manufacturerId = 0x010F, prod = 0x0702, productId = 0x1000 }, -- Fibaro Open/Closed Sensor 2 (FGDW-002) / Europe
      { manufacturerId = 0x010F, prod = 0x0702, productId = 0x2000 }, -- Fibaro Open/Closed Sensor 2 (FGDW-002) / NA
      { manufacturerId = 0x010F, prod = 0x0702, productId = 0x3000 }, -- Fibaro Open/Closed Sensor 2 (FGDW-002) / ANZ
      { manufacturerId = 0x010F, prod = 0x0701, productId = 0x2001 }, -- Fibaro Open/Closed Sensor with temperature (FGK-10X) / NA
      { manufacturerId = 0x010F, prod = 0x0701, productId = 0x1001 }, -- Fibaro Open/Closed Sensor
      { manufacturerId = 0x010F, prod = 0x0501, productId = 0x1002 }  -- Fibaro Open/Closed Sensor
    }
    
    --detect if is a fibaro_door_window_sensor to do not perform preferences
    local do_prefrerences = true
    for _, fingerprint in ipairs(FIBARO_DOOR_WINDOW_SENSOR_FINGERPRINTS) do
      if device:id_match(fingerprint.manufacturerId, fingerprint.prod, fingerprint.productId) then
        do_prefrerences = false
      end
    end

    if  do_prefrerences == true then
      if not device:is_cc_supported(cc.WAKE_UP) then
        preferencesMap.update_preferences(self, device, args)
      else
        if device.preferences.parameterSendDelay == "NoDelay" or device.preferences.parameterSendDelay == nil then
          preferencesMap.update_preferences(self, device, args)
        end
      end

      --create child devices and battery type
      for id, value in pairs(device.preferences) do
        local oldPreferenceValue = device:get_field(id)
        local newParameterValue = device.preferences[id]

        if oldPreferenceValue ~= newParameterValue then
          print("<<< Preference Changed:", id, "Old preference value:", oldPreferenceValue, "New preference vaule:", newParameterValue)
          device:set_field(id, newParameterValue, {persist = true})
          if id == "childThermostat" and device.preferences.childThermostat == true then
            child_devices.create_new(self, device, "main", "child-thermostat")
          elseif id == "childThermostat1" and newParameterValue == true then
            print("<< Create child thermostat-1")
            child_devices.create_new(self, device, "externalTemp1", "child-thermostat")
          elseif id == "childThermostat2" and newParameterValue == true then
            child_devices.create_new(self, device, "externalTemp2", "child-thermostat")
          elseif id == "childThermostat3" and newParameterValue == true then
            child_devices.create_new(self, device, "externalTemp3", "child-thermostat")
          elseif id == "childThermostat4" and newParameterValue == true then
            child_devices.create_new(self, device, "externalTemp4", "child-thermostat")
          elseif id == "configChild" and newParameterValue == true then
            child_devices.create_new(self, device, "config", "zwave-device-info")
          elseif id == "changeProfileExtTemp" and newParameterValue == "0" then
            device:try_update_metadata({profile = "secure-humidity-temperature-battery"})
          elseif id == "changeProfileExtTemp" and newParameterValue == "1" then
            device:try_update_metadata({profile = "secure-humidity-temperature-battery-1"})
          elseif id == "changeProfileExtTemp" and newParameterValue == "2" then
            device:try_update_metadata({profile = "secure-humidity-temperature-battery-2"})
          elseif id == "changeProfileExtTemp" and newParameterValue == "3" then
            device:try_update_metadata({profile = "secure-humidity-temperature-battery-3"})
          elseif id == "changeProfileExtTemp" and newParameterValue == "4" then
            device:try_update_metadata({profile = "secure-humidity-temperature-battery-4"})
          elseif id == "batteryType" and newParameterValue ~= nil then
            device:emit_event(capabilities.battery.type(newParameterValue))
          elseif id == "batteryQuantity" and newParameterValue ~= nil then
            device:emit_event(capabilities.battery.quantity(newParameterValue))
          end
        end
      end
    end
  end
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

--------------------------------------------------------------------------------------------
-- Register message handlers and run driver
--------------------------------------------------------------------------------------------

local device_config_subdriver = {
  NAME = "Device Config subdriver",
  supported_capabilities = {
    device_Parameter,
    parameter_Size,
    parameter_Value,
    command_Config,
    action_Button,
    parameter_Start,
    parameter_End,
    group_Number,
    group_Number_Start,
    group_Number_End,
    node_To_Write_Hex,
    group_Command_Option,
    wake_Up_Value,
    capabilities.refresh,
  },
  lifecycle_handlers = {
    added = added_handler,
    infoChanged = info_Changed,
    --init = do_init,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = added_handler,
    },
    [command_Config.ID] = {
      [command_Config.commands.setCommandConfig.NAME] = command_Config_handler,
    },
    [action_Button.ID] = {
      [action_Button.commands.push.NAME] = command_Action_button_handler,
    },
    [device_Parameter.ID] = {
      [device_Parameter.commands.setDeviceParameter.NAME] = device_Parameter_handler,
    },
    [parameter_Size.ID] = {
      [parameter_Size.commands.setParameterSize.NAME] = parameter_Size_handler,
    },
    [parameter_Value.ID] = {
      [parameter_Value.commands.setParameterValue.NAME] = parameter_Value_handler,
    },
    [wake_Up_Value.ID] = {
      [wake_Up_Value.commands.setWakeUpValue.NAME] = wake_Up_Value_handler,
    },
    [parameter_Start.ID] = {
      [parameter_Start.commands.setParameterStart.NAME] = parameter_Start_handler,
    },
    [parameter_End.ID] = {
      [parameter_End.commands.setParameterEnd.NAME] = parameter_End_handler,
    },
    [group_Number_Start.ID] = {
      [group_Number_Start.commands.setGroupNumberStart.NAME] = groupNumber_Start_handler,
    },
    [group_Number_End.ID] = {
      [group_Number_End.commands.setGroupNumberEnd.NAME] = groupNumber_End_handler,
    },
    [group_Number.ID] = {
      [group_Number.commands.setGroupNumber.NAME] = groupNumber_handler,
    },
    [node_End_Point.ID] = {
      [node_End_Point.commands.setNodeEndPoint.NAME] = node_End_Point_handler,
    },
    [device_Association_Type.ID] = {
      [device_Association_Type.commands.setDeviceAssociationType.NAME] = device_Association_Type_handler,
    },
    [node_To_Write_Hex.ID] = {
      [node_To_Write_Hex.commands.setNodeToWrite.NAME] = node_To_Write_Hex_handler,
    },
    [group_Command_Option.ID] = {
      [group_Command_Option.commands.setGroupCommandOption.NAME] = group_Command_Option_handler,
    },
  },
  zwave_handlers = {
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report_handler
    },
    [cc.ASSOCIATION] = {
      [Association.REPORT] = Association_report_handler
    },
    [cc.MULTI_CHANNEL_ASSOCIATION] = {
      [MultiChannelAssociation.REPORT] = MultiChannelAssociation_report_handler
    },
    [cc.VERSION] = {
      [Version.REPORT] = version_report_handler
    },
    [cc.WAKE_UP] = {
      [WakeUp.INTERVAL_REPORT] = wakeup_interval_report,
      [WakeUp.NOTIFICATION] = wakeup_notification_handler
    }
  },
  can_handle = can_handle
}

return device_config_subdriver
