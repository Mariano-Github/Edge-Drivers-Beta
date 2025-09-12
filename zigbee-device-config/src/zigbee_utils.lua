local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local json = require "dkjson"
local log = require "log"
local zigbee_utils = require "st.zigbee.utils"

local messages = require "st.zigbee.messages"
local bind_request = require "st.zigbee.zdo.bind_request"
local zdo_messages = require "st.zigbee.zdo"
  

local zutils = {}

zutils.supports_client_cluster = function(device, cluster_id)
    for ep_id, ep in pairs(device.zigbee_endpoints) do
      for _, cluster in ipairs(ep.client_clusters) do
        if cluster == cluster_id then
          return true
        end
      end
    end
    return false
  end

local function to_hex(value)
  return string.format("0x%04X", value)
end

local id_to_name_map = utils.deep_copy(zcl_clusters.id_to_name_map)
id_to_name_map[0x000C] = "AnalogInput"
id_to_name_map[0x0010] = "BinaryOutput"
id_to_name_map[0x0012] = "MultistateInput"
id_to_name_map[0xFCC0] = "AqaraOpple"


local function clusters_to_string(name, cluster_table)
  local res = name.."["
  for _, cluster in ipairs(cluster_table) do
    local name = id_to_name_map[cluster] or to_hex(cluster)
    res = res .. name .. ", "
  end
  return res .. "]"
end
  
zutils.print_clusters = function(device)
  for ep_id, ep in pairs(device.zigbee_endpoints) do
    local msg = "Ep#" .. ep.id .. 
                " device_id:" .. to_hex(ep.device_id) ..
                " profile_id:" .. to_hex(ep.profile_id)
    
    if ep.model then
      msg = msg .. " model:'" .. ep.model .. "'"
    end
    
    if ep.manufacturer then
      msg = msg .. " manufacturer:'" .. ep.manufacturer .. "'"
    end

    log.info( msg .. 
              clusters_to_string(" Client clusters:", ep.client_clusters) ..
              clusters_to_string(" Server clusters:", ep.server_clusters) )
  end
end

zutils.build_bind_request = function(device, cluster, group)
  local addr_header = messages.AddressHeader(
    constants.HUB.ADDR, 
    constants.HUB.ENDPOINT, 
    device:get_short_address(), 
    device.fingerprinted_endpoint_id, 
    constants.ZDO_PROFILE_ID, 
    bind_request.BindRequest.ID)
    
  local bind_req = bind_request.BindRequest(
    device.zigbee_eui, 
    device:get_endpoint(cluster), 
    cluster, 
    bind_request.ADDRESS_MODE_16_BIT, 
    group)

  return messages.ZigbeeMessageTx({
    address_header = addr_header,
    body = zdo_messages.ZdoMessageBody({zdo_body = bind_req})
  })
end

zutils.send_bind_request = function(device, cluster, group)
  return device:send( zutils.build_bind_request(device, cluster, group) )
end

zutils.send_unbind_request = function(device, cluster, group)
  -- not tested
  local addr_header = messages.AddressHeader(
    constants.HUB.ADDR, 
    constants.HUB.ENDPOINT, 
    device:get_short_address(), 
    device.fingerprinted_endpoint_id, 
    constants.ZDO_PROFILE_ID, 
    0x0022)
    
  local bind_req = bind_request.BindRequest(
    device.zigbee_eui, 
    device:get_endpoint(cluster), 
    cluster, 
    bind_request.ADDRESS_MODE_16_BIT, 
    group)

  return device:send( messages.ZigbeeMessageTx({
    address_header = addr_header,
    body = zdo_messages.ZdoMessageBody({zdo_body = bind_req})
  }) )
end


zutils.send_read_binding_table = function(device)
  local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"

  local addr_header = messages.AddressHeader(
    constants.HUB.ADDR,
    constants.HUB.ENDPOINT,
    device:get_short_address(),
    device.fingerprinted_endpoint_id,
    constants.ZDO_PROFILE_ID,
    mgmt_bind_req.BINDING_TABLE_REQUEST_CLUSTER_ID
  )
  return device:send( messages.ZigbeeMessageTx({
    address_header = addr_header,
    body = zdo_messages.ZdoMessageBody({zdo_body = mgmt_bind_req.MgmtBindRequest(0)})
  }) )
end

return zutils