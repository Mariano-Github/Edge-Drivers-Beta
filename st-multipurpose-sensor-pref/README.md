## SmartThings Multipurpose Sensor-Pref: Modified fron original Driver to add settings with preferences for custom Temperature Reports
  ## Modified by Mariano Colmenarejo with help of Nayely Zarazua (SmartThings)
Model: IM6001-MPP04

Protocol: Zigbee

## Prerequisites

1. Set up the SmartThings CLI according to the [configuration document](https://github.com/SmartThingsCommunity/smartthings-cli/blob/master/packages/cli/doc/configuration.md).
2. Add the [Edge Driver plugin](https://github.com/SmartThingsCommunity/edge-alpha-cli-plugin#set-up) to the CLI.
3. Configure your development environment for the [SmartThingsEdgeDrivers](https://github.com/SmartThingsCommunity/SmartThingsEdgeDriversBeta)
4. A SmartThings hub with firmware version 000.038.000XX or greater and a SmartThings Multipurpose sensor (Zigbee).

## Uploading Your Driver to SmartThings

_Note: Review the installation tutorial in our [Developer's Community](https://community.smartthings.com/t/creating-drivers-for-zigbee-devices-with-smartthings-edge/229502)._

1. Compile the driver:

```
       smartthings edge:drivers:package driver/
```

2. Next, create a channel for your driver

```
smartthings edge:channels:create
```

3. Enroll your driver into the channel

```
smartthings edge:channels:enroll
```

4. Publish your driver to the channel

```
smartthings edge:drivers:publish
```

5. If the package was successfully created, you can call the command below and follow the on-screen prompts to install the Driver in your Hub:

```
       smartthings edge:drivers:install
```

You should see the confirmation message: "Driver {driver-id} installed to Hub {hub-id}"

6. Use your WiFi router or the [SmartThings IDE](https://account.smartthings.com/login) > My Hubs to locate and copy the IP Address for your Hub.

7. From a computer on the same local network as your Hub, open a new terminal window and run the command to get the logs from all the installed drivers.

```
       smartthings edge:drivers:logcat --hub-address=x.x.x.x -a
```

## Onboarding your New Device

1. Open the SmartThings App and go to the location where the hub is installed.
2. Go to Add (+) > Device or select _Scan Nearby_ (If you have more than one, select the corresponding Hub as well)

3. Put your device in pairing mode; the specifications will vary by manufacturer (for the SmartThings Multipurpose sensor, press the device’s reset button once).
4. Keep the terminal view open until you see only reporting values messages in the logs.

Example Output

```text
<ZigbeeDevice: device-id [source-id] (Multipurpose Sensor f1)> emitting event: {"attribute_id":"temperature","component_id":"main","state":{"unit":"C","value":28.66},"capability_id":"temperatureMeasurement"}
```

If your Device paired correctly and the Driver was applied, you should not see any errors in the logs (including "UNSUPPORTED" responses to any Zigbee TX message). You can validate this by opening the SmartThings app and controlling and/or viewing all of the devices Capabilities (e.g., open/close or change the temperature).
