local Configuration = (require "st.zwave.CommandClass.Configuration")({ version=4 })
local MultichannelAssociation = (require "st.zwave.CommandClass.MultiChannelAssociation")({ version = 3 })

local function can_handle_qubino_din_dimmer(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  -- Qubino Din Dimmer: mfr = 0x0159, prod = 0x0001, model = 0x0052
  if device:id_match(0x0159, 0x0001, 0x0052) then
    return true
  end
  return false
end

local function do_configure(self, device)
  device:send(MultichannelAssociation:Remove({grouping_identifier = 1, node_ids = {}}))
  device:send(MultichannelAssociation:Set({grouping_identifier = 1, node_ids = {self.environment_info.hub_zwave_id}}))
  device:send(Configuration:Set({parameter_number=42, size=2, configuration_value=1920}))
end

local qubino_din_dimmer = {
  NAME = "qubino DIN dimmer",
  lifecycle_handlers = {
    doConfigure = do_configure
  },
  can_handle = can_handle_qubino_din_dimmer
}

return qubino_din_dimmer