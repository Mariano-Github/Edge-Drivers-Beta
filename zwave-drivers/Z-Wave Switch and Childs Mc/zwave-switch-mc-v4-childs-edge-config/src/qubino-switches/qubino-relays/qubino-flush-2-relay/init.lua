local QUBINO_FLUSH_2_RELAY_FINGERPRINT = {mfr = 0x0159, prod = 0x0002, model = 0x0051}

local function can_handle_qubino_flush_2_relay(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
    if device:id_match(QUBINO_FLUSH_2_RELAY_FINGERPRINT.mfr, QUBINO_FLUSH_2_RELAY_FINGERPRINT.prod, QUBINO_FLUSH_2_RELAY_FINGERPRINT.model) then
      return true
    end
  return false
end

local function component_to_endpoint(device, component_id)
    if component_id == "main" then
      return { 1 }
    elseif component_id == "extraTemperatureSensor" then
      return { 3 }
    else
      local ep_num = math.floor(component_id:match("switch(%d)"))
      return { ep_num and tonumber(ep_num)}
    end
end
  
local function endpoint_to_component(device, ep)
    if ep == 2 then
      return string.format("switch%d", ep)
    elseif ep == 3 then
      return "extraTemperatureSensor"
    else
      return "main"
    end
end

local function map_components(self, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then  ---- device (is NO Child device)
    device:set_endpoint_to_component_fn(endpoint_to_component)
    device:set_component_to_endpoint_fn(component_to_endpoint)
  end
end

local qubino_flush_2_relay = {
  NAME = "qubino flush 2 relay",
  lifecycle_handlers = {
    init = map_components
  },
  can_handle = can_handle_qubino_flush_2_relay
}

return qubino_flush_2_relay