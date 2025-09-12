local MultichannelAssociation = (require "st.zwave.CommandClass.MultiChannelAssociation")({ version = 3 })

local QUBINO_DIMMER_FINGERPRINTS = {
  {mfr = 0x0159, prod = 0x0001, model = 0x0051}, -- Qubino Flush Dimmer
  {mfr = 0x0159, prod = 0x0001, model = 0x0052}, -- Qubino DIN Dimmer
  {mfr = 0x0159, prod = 0x0001, model = 0x0053}, -- Qubino Flush Dimmer 0-10V
  {mfr = 0x0159, prod = 0x0001, model = 0x0055}  -- Qubino Mini Dimmer
}

local function can_handle_qubino_dimmer(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(QUBINO_DIMMER_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return true
    end
  end
  return false
end

local function do_configure(self, device)
  device:send(MultichannelAssociation:Remove({grouping_identifier = 1, node_ids = {}}))
  device:send(MultichannelAssociation:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}}))
end

local qubino_dimmer = {
  NAME = "qubino dimmer",
  lifecycle_handlers = {
    doConfigure = do_configure
  },
  can_handle = can_handle_qubino_dimmer,
  sub_drivers = {
    require("qubino-switches/qubino-dimmer/qubino-din-dimmer")
  }
}

return qubino_dimmer