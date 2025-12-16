-- subdriver for ST Button
-- M. Colmenarejo 2023
local capabilities = require "st.capabilities"
local constants = require "st.zigbee.constants"
local IASZone = (require "st.zigbee.zcl.clusters").IASZone

local can_handle = function(opts, driver, device)
    if device:get_manufacturer() == "Samjin" and device:get_model() == "button" then
      local subdriver = require("button")
      return true, subdriver
    end
    return false
end

local generate_event_from_zone_status = function(driver, device, zone_status, zb_rx)
  print("zone_status >>>>>>>>>",zone_status)
  local event
  local additional_fields = {
    state_change = true
  }
  if zone_status:is_alarm1_set() and zone_status:is_alarm2_set() then
    event = capabilities.button.button.held(additional_fields)
  elseif zone_status:is_alarm1_set() then
    event = capabilities.button.button.pushed(additional_fields)
  elseif zone_status:is_alarm2_set() then
    event = capabilities.button.button.double(additional_fields)
  end
  if event ~= nil then
    device:emit_event_for_endpoint(
      zb_rx.address_header.src_endpoint.value,
      event)
  end
end

--- Default handler for zoneStatus attribute on the IAS Zone cluster
---
--- This converts the 2 byte bitmap value to motionSensor.motion."active" or motionSensor.motion."inactive"
---
--- @param driver Driver The current driver running containing necessary context for execution
--- @param device ZigbeeDevice The device this message was received from containing identifying information
--- @param zone_status 2 byte bitmap zoneStatus attribute value of the IAS Zone cluster
--- @param zb_rx ZigbeeMessageRx the full message this report came in

local ias_zone_status_attr_handler = function(driver, device, zone_status, zb_rx)
  generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

--- Default handler for zoneStatus change handler
---
--- This converts the 2 byte bitmap value to motionSensor.motion."active" or motionSensor.motion."inactive"
---
--- @param driver Driver The current driver running containing necessary context for execution
--- @param device ZigbeeDevice The device this message was received from containing identifying information
--- @param zb_rx containing zoneStatus attribute value of the IAS Zone cluster

local ias_zone_status_change_handler = function(driver, device, zb_rx)
  generate_event_from_zone_status(driver, device, zb_rx.body.zcl_body.zone_status, zb_rx)
end

local function added_handler(self, device)
  device:emit_event(capabilities.button.supportedButtonValues({"pushed","held","double"}))
  device:emit_event(capabilities.button.numberOfButtons({value = 1}))
end


local st_button = {
	NAME = "ST button",
  zigbee_handlers = {
    attr = {
      [IASZone.ID] = {
        [IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
      }
    },
    cluster = {
        [IASZone.ID] = {
          [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
        }
      }
    },
    lifecycle_handlers = {
      added = added_handler,
    },
    ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
	  can_handle = require("button.can_handle"),
}

return st_button
