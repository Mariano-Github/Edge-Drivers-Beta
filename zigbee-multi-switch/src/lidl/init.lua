local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local data_types = require "st.zigbee.data_types"
local capabilities = require "st.capabilities"

local is_supported = function(opts, driver, device)
    return device:get_manufacturer() == "_TZ3000_1obwwnmq"
end

local function do_configure(driver, device)
    local device_mgmt = require 'st.zigbee.device_management'
  
    device:refresh()
    device:send(device_mgmt.build_bind_request(
      device,
      OnOff.ID,
      driver.environment_info.hub_zigbee_eui))
  
    -- configure
    device:configure()
  end
-- switch (OnOff) report config
local onoff_cluster_config = {
    cluster=OnOff.ID,
    attribute=OnOff.attributes.OnOff.ID,
    minimum_interval=0,
    maximum_interval=300,
    data_type=data_types.Boolean,
    monitored=true
  }
-- subdriver template
local lidl_subdriver = {
    NAME = 'controller',
    lifecycle_handlers = {
        doConfigure = do_configure
      },    
    cluster_configuration = {
      [capabilities.switch.ID] = onoff_cluster_config
    },
    can_handle = is_supported,
    }
return lidl_subdriver  
