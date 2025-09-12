--local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
--local cc = require "st.zwave.CommandClass"

local FIBARO_WALL_PLUG_FINGERPRINTS = {
  {mfr = 0x010F, prod = 0x1401, model = 0x1001}, -- Fibaro Outlet
  {mfr = 0x010F, prod = 0x1401, model = 0x2000}, -- Fibaro Outlet
}

local function can_handle_fibaro_wall_plug(opts, driver, device, ...)
  if device.network_type == "DEVICE_EDGE_CHILD" then return false end --is child device
  for _, fingerprint in ipairs(FIBARO_WALL_PLUG_FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      local subdriver = require("fibaro-wall-plug-us")
      return true, subdriver
    end
  end
  return false
end

local function component_to_endpoint(device, component_id)
  if component_id == "main" then
    return {1}
  else
    return {2}
  end
end

local function endpoint_to_component(device, ep)
  local switch_comp = string.format("smartplug%d", ep - 1)
  if device.profile.components[switch_comp] ~= nil then
    return switch_comp
  else
    return "main"
  end
end

local function device_init(self, device)
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)
end

local fibaro_wall_plug = {
  NAME = "fibaro wall plug us",
  lifecycle_handlers = {
    init = device_init
  },
  can_handle = can_handle_fibaro_wall_plug,
}

return fibaro_wall_plug
