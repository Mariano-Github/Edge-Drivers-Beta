-- subdriver for ST Button
-- M. Colmenarejo 2023
local capabilities = require "st.capabilities"
local constants = require "st.zigbee.constants"
local IASZone = (require "st.zigbee.zcl.clusters").IASZone
local zcl_clusters = require "st.zigbee.zcl.clusters"
local device_management = require "st.zigbee.device_management"

local xiaomi_utils = require "xiaomi_utils"
local signal = require "signal-metrics"


-- on-off handle to open close events
local function on_off_attr_handler(driver, device, value, zb_rx)

  local event = capabilities.contactSensor.contact.open()
  if value.value == false or value.value == 0 then
    event = capabilities.contactSensor.contact.closed()
  end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, event)

  -- emit signal metrics
  signal.metrics(device, zb_rx)
end


local function do_configure(driver, device)
  device:send(device_management.build_bind_request(device, zcl_clusters.OnOff.ID, driver.environment_info.hub_zigbee_eui))
  device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, 300))
end

local lumi_switch_cluster = {
	NAME = "lumi_switch_cluster",
  zigbee_handlers = {
      attr = {
        [zcl_clusters.basic_id] = {
          [0xFF02] = xiaomi_utils.battery_handler,
          [0xFF01] = xiaomi_utils.battery_handler
        },
        [zcl_clusters.OnOff.ID] = {
          [zcl_clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler
        },
      },
    },
    lifecycle_handlers = {
      doConfigure = do_configure,
      driverSwitched = do_configure
    },
	  can_handle =  require("lumi-switch-cluster.can_handle"),
}

return lumi_switch_cluster
