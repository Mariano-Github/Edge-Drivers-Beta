-- Mock out globals
local test = require "integration_test"
local clusters = require "st.zigbee.zcl.clusters"
local IASZone = clusters.IASZone
local TemperatureMeasurement = clusters.TemperatureMeasurement
local PowerConfiguration = clusters.PowerConfiguration
local cluster_base = require "st.zigbee.cluster_base"
local data_types = require "st.zigbee.data_types"
local capabilities = require "st.capabilities"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"
local IasEnrollResponseCode = require "st.zigbee.generated.zcl_clusters.IASZone.types.EnrollResponseCode"
local base64 = require "st.base64"
local t_utils = require "integration_test.utils"

local ZoneStatusAttribute = IASZone.attributes.ZoneStatus

local MFG_CLUSTER = 0xFC02 --for Acceleration and Three axis
local MFG_CODE = 0x110A
local ACCELERATION_ATTR_ID = 0x0010
local X_AXIS_ATTR_ID = 0x0012
local Y_AXIS_ATTR_ID = 0x0013
local Z_AXIS_ATTR_ID = 0x0014

local mock_device = test.mock_device.build_test_zigbee_device(
    { 
      profile = t_utils.get_profile_definition("multipurpose-profile.yml"),
      zigbee_endpoints = {
        [1] = {
          id = 1,
          manufacturer = "SmartThings",
          model = "multiv4",
          server_clusters = {0x0000,0x0001,0x0003,0x000F,0x0020,0x0402,0x0500,0xFC02}
        }
      } 
    }
)
zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device)
  zigbee_test_utils.init_noop_health_check_timer()
end
test.set_test_init_function(test_init)

test.register_message_test(
    "ThreeAxis report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device.id, zigbee_test_utils.build_attribute_report(mock_device, MFG_CLUSTER, {{X_AXIS_ATTR_ID, data_types.Int16.ID, -90}}, MFG_CODE) }
      },
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device.id, zigbee_test_utils.build_attribute_report(mock_device, MFG_CLUSTER, {{Y_AXIS_ATTR_ID, data_types.Int16.ID, 90}}, MFG_CODE) }
      },
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device.id, zigbee_test_utils.build_attribute_report(mock_device, MFG_CLUSTER, {{Z_AXIS_ATTR_ID, data_types.Int16.ID, 45}}, MFG_CODE) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device:generate_test_message("main", capabilities.threeAxis.threeAxis({45,90,90}))
      }
    }
)

test.register_message_test(
    "Acceleration report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device.id, zigbee_test_utils.build_attribute_report(mock_device, MFG_CLUSTER, {{ACCELERATION_ATTR_ID, data_types.Bitmap8.ID, 0x1}}, MFG_CODE) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device:generate_test_message("main", capabilities.accelerationSensor.acceleration.active())
      }
    }
)

test.register_coroutine_test(
    "Configure should configure all necessary attributes",
    function ()
      test.socket.zigbee:__set_channel_ordering("relaxed")
      test.socket.device_lifecycle:__queue_receive({ mock_device.id, "added"})
      test.socket.device_lifecycle:__queue_receive({ mock_device.id, "doConfigure"})
      test.socket.zigbee:__expect_send({ mock_device.id, PowerConfiguration.attributes.BatteryVoltage:read(mock_device) })
      test.socket.zigbee:__expect_send({ mock_device.id, PowerConfiguration.attributes.BatteryPercentageRemaining:read(mock_device) })
      test.socket.zigbee:__expect_send({ mock_device.id, TemperatureMeasurement.attributes.MeasuredValue:read(mock_device) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attribute_read(mock_device, MFG_CLUSTER, {ACCELERATION_ATTR_ID}, MFG_CODE) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attribute_read(mock_device, MFG_CLUSTER, {X_AXIS_ATTR_ID}, MFG_CODE) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attribute_read(mock_device, MFG_CLUSTER, {Y_AXIS_ATTR_ID}, MFG_CODE) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attribute_read(mock_device, MFG_CLUSTER, {Z_AXIS_ATTR_ID}, MFG_CODE) })                                                                                                                     
      test.socket.zigbee:__expect_send({ mock_device.id, IASZone.attributes.ZoneStatus:read(mock_device) })
      test.socket.zigbee:__expect_send({ mock_device.id, TemperatureMeasurement.attributes.MeasuredValue:configure_reporting(mock_device, 30, 300, 0x10) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_bind_request(mock_device, zigbee_test_utils.mock_hub_eui, TemperatureMeasurement.ID) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attr_config(mock_device, MFG_CLUSTER, ACCELERATION_ATTR_ID, 0, 300, data_types.Bitmap8, 1, MFG_CODE) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attr_config(mock_device, MFG_CLUSTER, X_AXIS_ATTR_ID, 0, 300, data_types.Int16, 1, MFG_CODE) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attr_config(mock_device, MFG_CLUSTER, Y_AXIS_ATTR_ID, 0, 300, data_types.Int16, 1, MFG_CODE) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_attr_config(mock_device, MFG_CLUSTER, Z_AXIS_ATTR_ID, 0, 300, data_types.Int16, 1, MFG_CODE) })                                                                                                                     
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_bind_request(mock_device, zigbee_test_utils.mock_hub_eui, MFG_CLUSTER) })
      test.socket.zigbee:__expect_send({ mock_device.id, PowerConfiguration.attributes.BatteryVoltage:configure_reporting(mock_device, 30, 21600, 1) })
      test.socket.zigbee:__expect_send({ mock_device.id, PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(mock_device, 30, 21600, 1) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_bind_request(mock_device, zigbee_test_utils.mock_hub_eui, PowerConfiguration.ID) })
      test.socket.zigbee:__expect_send({ mock_device.id, IASZone.attributes.IASCIEAddress:write(mock_device, zigbee_test_utils.mock_hub_eui) })
      test.socket.zigbee:__expect_send({ mock_device.id, IASZone.server.commands.ZoneEnrollResponse(mock_device, IasEnrollResponseCode.SUCCESS, 0x00) })
      test.socket.zigbee:__expect_send({ mock_device.id, IASZone.attributes.ZoneStatus:configure_reporting(mock_device, 30, 300, 0) })
      test.socket.zigbee:__expect_send({ mock_device.id, zigbee_test_utils.build_bind_request(mock_device, zigbee_test_utils.mock_hub_eui, IASZone.ID) })

      mock_device:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_message_test(
    "Refresh should read all necessary attributes",
    {
      {
        channel = "device_lifecycle",
        direction = "receive",
        message = {mock_device.id, "added"}
      },
      {
        channel = "capability",
        direction = "receive",
        message = {
          mock_device.id,
          { capability = "refresh", component = "main", command = "refresh", args = {} }
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          PowerConfiguration.attributes.BatteryVoltage:read(mock_device)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          PowerConfiguration.attributes.BatteryPercentageRemaining:read(mock_device)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          TemperatureMeasurement.attributes.MeasuredValue:read(mock_device)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          zigbee_test_utils.build_attribute_read(mock_device, MFG_CLUSTER, {Z_AXIS_ATTR_ID}, MFG_CODE)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          zigbee_test_utils.build_attribute_read(mock_device, MFG_CLUSTER, {X_AXIS_ATTR_ID}, MFG_CODE)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          zigbee_test_utils.build_attribute_read(mock_device, MFG_CLUSTER, {Y_AXIS_ATTR_ID}, MFG_CODE)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          zigbee_test_utils.build_attribute_read(mock_device, MFG_CLUSTER, {ACCELERATION_ATTR_ID}, MFG_CODE)
        }
      },
      {
        channel = "zigbee",
        direction = "send",
        message = {
          mock_device.id,
          IASZone.attributes.ZoneStatus:read(mock_device)
        }
      },
    },
    {
      inner_block_ordering = "relaxed"
    }
)

test.register_message_test(
    "Battery voltage report should be handled",
    {
      {
        channel = "zigbee",
        direction = "receive",
        message = { mock_device.id, PowerConfiguration.attributes.BatteryVoltage:build_test_attr_report(mock_device,
                                                                                                        25) }
      },
      {
        channel = "capability",
        direction = "send",
        message = mock_device:generate_test_message("main", capabilities.battery.battery(90))
      }
    }
)

test.run_registered_tests()