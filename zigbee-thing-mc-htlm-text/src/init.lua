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
--local json = require "st.json"
--local utils = require "st.utils"

local app_version = nil
local zcl_version = nil
local lqi = nil
local rssi = nil

--- Custom Capabilities
local manufacturer = capabilities["legendabsolute60149.manufacturer"]
local model = capabilities["legendabsolute60149.model"]
local clusters = capabilities["legendabsolute60149.clustersInfo"]
local device_Info = capabilities["legendabsolute60149.deviceInfo"]
local signal_Metrics = capabilities["legendabsolute60149.signalMetrics"]

-- preferences update
local function do_preferences(self, device, event, args)
  print("***** infoChanged *********")
  
   for id, value in pairs(device.preferences) do
    local oldPreferenceValue = args.old_st_store.preferences[id]
    local newParameterValue = device.preferences[id]

    if oldPreferenceValue ~= newParameterValue then
      print("<< Preference changed Name:", id, "old Value", oldPreferenceValue, "new Value>>", newParameterValue)
      if id == "changeProfile" then
        if newParameterValue == "Range" then
          device:try_update_metadata({profile = "range-extender"})
        else --if newParameterValue == "Thing"
          device:try_update_metadata({profile = "zigbee-thing"})
        end
      end
    end
  end

  --- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")

  local firmware_full_version = device.data.firmwareFullVersion
  if firmware_full_version == nil then firmware_full_version = "Unknown" end
  print("<<<<< Firmware Version >>>>>",firmware_full_version)
end

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
          server_clusters = server_clusters .. string.format("-Ep:".."0x%02X={ %s }", ep.id, row)
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

--Emit Manufacturer and model
local function added_handler(driver, device)

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
      device:emit_event(clusters.clustersInfo({value = str}, {visibility = {displayed = false }}))
    end)
  end)
end

--applicationVersion_handler
local function applicationVersion_handler(self, device, value, zb_rx)
  --print("Firmware >>>>>>>>>",value.value)
  app_version = value.value
  lqi = zb_rx.lqi.value
  rssi = zb_rx.rssi.value
end

--ZCLVersion_handler
local function ZCLVersion_handler(self, device, value, zb_rx)
  --print("ZCLVersion >>>>>>>>>",value.value)
  zcl_version = value.value
  lqi = zb_rx.lqi.value
  rssi = zb_rx.rssi.value

  local visible_satate = false
  if device.preferences.signalMetricsVisibles == "Yes" then
    visible_satate = true
  end

  local gmt = os.date("%Y/%m/%d GMT: %H:%M",os.time())
  local metrics = "LQI: ".. zb_rx.lqi.value .."...rssi: ".. zb_rx.rssi.value .. ", " .. gmt
  device:emit_event(signal_Metrics.signalMetrics({value = metrics}, {visibility = {displayed = visible_satate }}))

end

local zigbee_thing_template = {
  lifecycle_handlers = {
    init = added_handler,
    infoChanged = do_preferences
  },
  supported_capabilities = {
    capabilities.refresh,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = added_handler,
    }
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.Basic.ID] = {
        [zcl_clusters.Basic.attributes.ZCLVersion.ID] = ZCLVersion_handler,
        [zcl_clusters.Basic.attributes.ApplicationVersion.ID] = applicationVersion_handler
      },
    },
  }
}

local zigbee_thing = ZigbeeDriver("zigbee_thing", zigbee_thing_template)

function zigbee_thing:device_health_check() 
  local device_list = self.device_api.get_device_list()
  for _, device_id in ipairs(device_list) do
    local device = self:get_device_info(device_id, false)
    device:send(zcl_clusters.Basic.attributes.ZCLVersion:read(device))
  end
end
zigbee_thing.device_health_timer = zigbee_thing.call_on_schedule(zigbee_thing, 900, zigbee_thing.device_health_check)

zigbee_thing:run()
