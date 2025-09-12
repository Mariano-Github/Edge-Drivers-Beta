--- @type st.zwave.CommandClass.Association
local Association = (require "st.zwave.CommandClass.Association")({version=2})
--- @type st.zwave.CommandClass.MultiChannelAssociation
local MultiChannelAssociation = (require "st.zwave.CommandClass.MultiChannelAssociation")({version=3})

local QUBINO_FLUSH_1_RELAY_FINGERPRINT = {mfr = 0x0159, prod = 0x0002, model = 0x0052} 

local function can_handle_qubino_flush_1_relay(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  return device:id_match(QUBINO_FLUSH_1_RELAY_FINGERPRINT.mfr, QUBINO_FLUSH_1_RELAY_FINGERPRINT.prod, QUBINO_FLUSH_1_RELAY_FINGERPRINT.model) 
end

local function do_configure(self, device)
  -- Hub automatically adds device to multiChannelAssosciationGroup and this needs to be removed
  --device:send(MultiChannelAssociation:Remove({grouping_identifier = 1, node_ids = {}}))
  device:send(MultiChannelAssociation:Remove({grouping_identifier = 1, multi_channel_nodes = {}}))
  device:send(Association:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}}))

  local association_cmd = Association:Set({grouping_identifier = 2, node_ids = {self.environment_info.hub_zwave_id}})
  -- This command needs to be sent before creating component
  -- That's why MultiChannel is forced here
  association_cmd.dst_channels = {4}
  device:send(association_cmd)
end

local qubino_flush_1_relay = {
  NAME = "qubino flush 1 relay",
  lifecycle_handlers = {
    --init = map_components,
    doConfigure = do_configure
  },
  can_handle = can_handle_qubino_flush_1_relay
}

return qubino_flush_1_relay