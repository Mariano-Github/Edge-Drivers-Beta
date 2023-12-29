------- Write attribute Module----
local data_types = require "st.zigbee.data_types"
local write_attribute = require "st.zigbee.zcl.global_commands.write_attribute"
local zcl_messages = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local zb_const = require "st.zigbee.constants"

local cluster_base = require "st.zigbee.cluster_base"

local write ={}

function write.write_attribute_function(device, cluster_id, attr_id, data_value)
    local write_body = write_attribute.WriteAttribute({
     write_attribute.WriteAttribute.AttributeRecord(attr_id, data_types.ZigbeeDataType(data_value.ID), data_value.value)})
  
     local zclh = zcl_messages.ZclHeader({
       cmd = data_types.ZCLCommandId(write_attribute.WriteAttribute.ID)
     })
     local addrh = messages.AddressHeader(
         zb_const.HUB.ADDR,
         zb_const.HUB.ENDPOINT,
         device:get_short_address(),
         device:get_endpoint(cluster_id.value),
         zb_const.HA_PROFILE_ID,
         cluster_id.value
     )
     local message_body = zcl_messages.ZclMessageBody({
       zcl_header = zclh,
       zcl_body = write_body
     })
     device:send(messages.ZigbeeMessageTx({
       address_header = addrh,
       body = message_body
     }))
  end

  local custom_write_attribute = function(device, cluster, attribute, data_type, value, mfg_code)
    local data = data_types.validate_or_build_type(value, data_type)
    local message = cluster_base.write_attribute(device, data_types.ClusterId(cluster), attribute, data)
    if mfg_code ~= nil then
      message.body.zcl_header.frame_ctrl:set_mfg_specific()
      message.body.zcl_header.mfg_code = data_types.validate_or_build_type(mfg_code, data_types.Uint16, "mfg_code")
    end
    return message
  end
  write.custom_write_attribute = custom_write_attribute

return write