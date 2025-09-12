--local MultichannelAssociation = (require "st.zwave.CommandClass.MultiChannelAssociation")({ version = 3 })
local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })

local QUBINO_FLUSH_1D_RELAY_FINGERPRINT = {mfr = 0x0159, prod = 0x0002, model = 0x0053}

local function can_handle_qubino_flush_1d_relay(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  return device:id_match(QUBINO_FLUSH_1D_RELAY_FINGERPRINT.mfr, QUBINO_FLUSH_1D_RELAY_FINGERPRINT.prod, QUBINO_FLUSH_1D_RELAY_FINGERPRINT.model)
end

local function do_configure(self, device)
  --device:send(MultichannelAssociation:Set({grouping_identifier = 2, node_ids = {self.environment_info.hub_zwave_id}}))
  --device:send(MultichannelAssociation:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}})) -- according qubino manual
  device:send(Association:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}})) -- according qubino manual
  device:refresh()
end

local qubino_flush_1d_relay = {
  NAME = "qubino flush 1d relay",
  lifecycle_handlers = {
    doConfigure = do_configure
  },
  can_handle = can_handle_qubino_flush_1d_relay
}

return qubino_flush_1d_relay