--local zw = require "st.zwave"
local Association = (require "st.zwave.CommandClass.Association")({ version = 2 })
--- @type st.zwave.CommandClass.MultiChannelAssociation
--local MultiChannelAssociation = (require "st.zwave.CommandClass.MultiChannelAssociation")({ version= 3 })

local QUBINO_FLUSH_RELAY_FINGERPRINT = {
  {mfr = 0x0159, prod = 0x0002, model = 0x0051}, -- Qubino Flush 2 Relay
  {mfr = 0x0159, prod = 0x0002, model = 0x0052}, -- Qubino Flush 1 Relay
  {mfr = 0x0159, prod = 0x0002, model = 0x0053}  -- Qubino Flush 1D Relay
}

local function can_handle_qubino_flush_relay(opts, driver, device, cmd, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(QUBINO_FLUSH_RELAY_FINGERPRINT) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return true
    end
  end
  return false
end

local function do_configure(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    local association_cmd = Association:Set({grouping_identifier = 2, node_ids = {self.environment_info.hub_zwave_id}})
    -- This command needs to be sent before creating component
    -- That's why MultiChannel is forced here
    association_cmd.dst_channels = {3}
    device:send(association_cmd)
    device:refresh()
  end
end

local qubino_relays = {
  NAME = "Qubino Relays",
  can_handle = can_handle_qubino_flush_relay,
  sub_drivers = {
    require("qubino-switches/qubino-relays/qubino-flush-2-relay"),
    require("qubino-switches/qubino-relays/qubino-flush-1-relay"),
    require("qubino-switches/qubino-relays/qubino-flush-1d-relay")
  },
  lifecycle_handlers = {
    doConfigure = do_configure
  },
}

return qubino_relays