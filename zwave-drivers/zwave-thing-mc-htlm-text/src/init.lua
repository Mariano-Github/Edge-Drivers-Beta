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

local capabilities = require "st.capabilities"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
local Version = (require "st.zwave.CommandClass.Version")({ version = 2 })
local zw = require "st.zwave"
--local utils = require "st.utils"
--local json = require "st.json"

--- Custom Capabilities
local manufacturer = capabilities["legendabsolute60149.manufacturer"]
local product_Type = capabilities["legendabsolute60149.productType"]
local product_Id = capabilities["legendabsolute60149.productId"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]
local command_Class = capabilities["legendabsolute60149.commandClass"]

--- Return a string representation of device model and supported command class information
---
local function debug_pretty_print(device)
  local outputString = "<em style='color:blue;font-weight: bold;'> Z-Wave Device: ".."</em>".. "<BR>".."<b>Id: </b>" .. device.id .. "<BR>".."<b>DNI: </b>" .. "0x".. device.device_network_id .. "<BR>"
  local firmVersion = " nil * Wake Up-Refresh Device"
  if device:get_field("firmVersion") ~= nil then firmVersion = device:get_field("firmVersion") end
    outputString = outputString .."<b>Firmware Ver: </b>" .. firmVersion .. "<BR>"
  local library = " nil * Wake Up-Refresh Device"
  if device:get_field("library") ~= nil then library = device:get_field("library") end
    outputString = outputString .."<b>Library Ver: </b>" .. library .. "<BR>"
  local zwProtocol = " nil * Wake Up-Refresh Device"
  if device:get_field("zwProtocol") ~= nil then library = device:get_field("zwProtocol") end
    outputString = outputString .."<b>Zw Protocol Ver: </b>" .. zwProtocol .. "<BR>"
  if (device.zwave_manufacturer_id ~= nil and device.zwave_product_type ~= nil and device.zwave_product_id ~= nil) then
    outputString = outputString .. string.format("<b>Manufacturer:</b> 0x%04X <BR> <b>Product Type:</b> 0x%04X <BR> <b>Product ID:</b> 0x%04X",
    device.zwave_manufacturer_id, device.zwave_product_type, device.zwave_product_id) .. "\n"
    if(device.zwave_endpoints ~= nil) then
      for index, endpoint in pairs(device.zwave_endpoints) do
        local command_classes = ""
        for _, cc in ipairs(endpoint.command_classes) do
          command_classes = command_classes .. string.format("%s, ", zw.cc_to_string(cc.value))
        end
        --outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> End Point & Command Class:".."</em>".. string.format("\t[%d]: %s",index-1, command_classes:sub(1, -3))
        outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> End Point & Command Class:".."</em>".. string.format("\t[%d]: %s",index, command_classes:sub(1, -3))
      end
    end
  end
  
  --[[
  --local device_mesh = json.decode((parent_device.st_store.data or {}).meshInfo)
  local device_mesh = json.decode(device.st_store.data.meshInfo)
  --print("device_mesh: >>>>>>",utils.stringify_table(device_mesh))
  local device_route = device.label ..' [' .. device.device_network_id .. '] <-> '
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
  local hubnode = device.driver.environment_info.hub_zwave_id or 1
  device_route = device_route .. 'Hub '..' ['.. string.format('%02X',hubnode) .. ']'
  outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> Route: ".."</em>" .. device_route
  outputString = outputString .. " <BR>".. "<em style='color:red;font-weight: bold;'> Metrics Update: ".."</em>".. device_mesh.updatedTime
  local device_metrics = string.format('Msg Transmitted: %s, Received: %s', device_mesh.metrics.totalTransmittedMessages, device_mesh.metrics.totalReceivedMessages)
  outputString = outputString .. " <BR>".. device_metrics
  device_metrics = string.format('Msg Failed: %s, Duplicate: %s', device_mesh.metrics.transmitFailures, device_mesh.metrics.duplicateMessages)
  outputString = outputString .. " <BR>".. device_metrics ]]

  return outputString
end

---Format row HTML
local function format_row(key, value)
  local str = "<tr> <th align=left>" .. key .. "</th> <td>" .. value .. "</td></tr>"
  return str
end

local function print_values(driver, device)
  print("<< print_values >>")

  local dni = string.format("DNI: 0x%02X", device.device_network_id)
  local firmware = "Firmaware: " .. device:get_field("version")
  local library = "Library: " .. device:get_field("library")
  local protocol = "Zw Protocol: " .. device:get_field("zwProtocol")
  local str = dni .. ", ".. firmware ..", ".. library .. ", " .. protocol
  --device:emit_event(device_Info.deviceInfo(str, { state_change = true }))
  device:emit_event(command_Class.commandClass(str, { state_change = true }))

  device.thread:call_with_delay(2, function(d)
    local command_classes = ""
    if(device.zwave_endpoints ~= nil) then
      for index, endpoint in pairs(device.zwave_endpoints) do 
        command_classes = command_classes .."(Ep" .. index .."): "
        for _, cc in ipairs(endpoint.command_classes) do
          command_classes = command_classes .. string.format("%s, ", zw.cc_to_string(cc.value))
        end
      end
      command_classes = string.format("%s", command_classes:sub(1, -3))
      --device:emit_event(device_Info.deviceInfo(command_classes,{ state_change = true }))
      device:emit_event(command_Class.commandClass(command_classes,{ state_change = true }))
    end
  end)

  device.thread:call_with_delay(5, function(d)
    local device_info = debug_pretty_print(device)
    print(">>> Device Info:", device_info)
    local str = "<table style='font-size:55%'> <tbody>"
    str = str .. format_row('', device_info)
    str = str .. "</tbody></table>"
    
    device:emit_event(device_Info.deviceInfo(str,{ state_change = true }))
  end)
end

--Emit Manufacturer and model
local function added_handler(driver, device)
  local mfr_id = string.format("manufacturerId: 0x%04X",device.zwave_manufacturer_id)
  local prd_type = string.format("productType: 0x%04X",device.zwave_product_type)
  local prd_id = string.format("productId: 0x%04X",device.zwave_product_id)
  
  --print(string.format("ManufacturerId: 0x%04X",device.zwave_manufacturer_id))
  --print(string.format("ProductType: 0x%04X",device.zwave_product_type))
  --print(string.format("ProductId: 0x%04X",device.zwave_product_id))

  device:emit_event(manufacturer.manufacturer(mfr_id))
  device:emit_event(product_Type.productType(prd_type))
  device:emit_event(product_Id.productId(prd_id))
  if device:get_field("version") == nil then   
    device:send(Version:Get({}))
  else
    print_values(driver, device)
  end
end

local function version_report_handler(driver, device, cmd)
  -- print("Version cmd >>>>>>", utils.stringify_table(cmd))
   --print("<<< cmd.args.application_version >>>", cmd.args.application_version)
   --print("<<< cmd.args.application_sub_version >>>", cmd.args.application_sub_version)
   device:set_field("version",cmd.args.application_version.."."..cmd.args.application_sub_version)
   device:set_field("library",cmd.args.z_wave_library_type)
   device:set_field("zwProtocol",cmd.args.z_wave_protocol_version.."."..cmd.args.z_wave_protocol_sub_version)

   --added_handler(driver, device)
   print_values(driver, device)
end

--------------------------------------------------------------------------------------------
-- Register message handlers and run driver
--------------------------------------------------------------------------------------------

local driver_template = {
  supported_capabilities = {
    capabilities.refresh,
    manufacturer,
    product_Type,
    product_Id,
    command_Class,
    device_Info
  },
  lifecycle_handlers = {
    --added = added_handler,
    init = added_handler
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = added_handler,
    }
  },
  zwave_handlers = {
    [cc.VERSION] = {
      [Version.REPORT] = version_report_handler
    },
  },
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local thing = ZwaveDriver("zwave_thing", driver_template)
thing:run()
