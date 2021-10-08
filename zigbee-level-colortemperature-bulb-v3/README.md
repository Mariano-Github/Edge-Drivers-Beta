## New version 3.0 for Driver Zigbee Level ColorTemperature Bulb:

## Thanks to @nayelyz, for help with the custom submissions.

## New functions:

## The Progressive Turn ON & Turn OFF Functions have been modified and I have created two Custom Capabilities to can activate and deactivate them from Automations and Scenes
Activation has been removed from device preferences.

## Added new Random ON-OFF function:

Made with a Custom Capability it can be activated and deactivated with automations and scenes.

The Minimum and Maximum times between which the bulb will randomly turn on and off is set in Preferences and can be set between 0.5 minutes and 25 minutes, depending on the needs of each one.

## How does it work?:

When the Random On Off functions is activated, a random interval is calculated between the values ​​chosen in preferences.

When the calculated interval is met, it is chosen randomly if the light turns On or Off. This means that not whenever it is on it will turn off or vice versa.

When the Random function is deactivated, the light also turns off.

When the Random function is activated, the progressive ON and OFF functions are automatically deactivated, since it could be the case, depending on the settings, that the light does not turn off or turn on.

You can create scenes and automations to activate and deactivate the function.

When deactivating the function you can select in the automation how the progressive ON and OFF in each bulb to be configured again.

I will include this function in the zigbee switch driver to be able to use controlled lights with switches and plugs.

I have tested it with 3 bulbs simultaneously, and it works fine.
If you see that something does not work as expected, tell me.

## Note for installing the new version and applying the new capabilities presentation without having to uninstall your devices or lose settings, automations and scenes:

- Install in the Hub, from the channel, the driver "Zigbee Level ColorTemperature Light"
- Open the Hub device in the App
- In the 3-point menu select “driver”
- Click on “Select another driver”
- Choose "Zigbee Level ColorTemperature Light"
- Click on Use this driver
- Although network error, ignore and go back. Wait half a minute or so
- Close App and reopen it
- Open the device and repeat the steps to install the new "Zigbee Level Color Temperature Bulb"
- Go back, and reopen the device waiting half a minute or so.
- Close the app and clear the App cache in phone settings.
- Reopen the app and the device will appear with the new presentation of functions.

If you notice that the color temperature setting is left thinking, it is that the configuration of the presentation has not been installed correctly, it is possible that repeating the installation it will be fixed.

## As a general rule with driver changes, especially when they require changing profiles or presentation, you have to go slowly, let all the processes run in the hub even though the app seems to have already finished, if you look at the logcat You will see that the installation continues.


## Devices 08-oct-2021:

zigbeeManufacturer:
  - id: "LIDL/TS0502A"
    deviceLabel: Lidl Bulb
    manufacturer: _TZ3000_49qchf10
    model: TS0502A
    deviceProfileName: level-colortemperature
  - id: "OSRAM/Classic"
    deviceLabel: OSRAM Classic
    manufacturer: OSRAM
    model: Classic A60 W clear - LIGHTIFY
    deviceProfileName: switch-level
  - id: "OSRAM/LIGHTIFY BR"
    deviceLabel: OSRAM LIGHTIFY BR
    manufacturer: OSRAM
    model: LIGHTIFY BR Tunable White
    deviceProfileName: level-colortemp-2700-6500
  - id: "Ecosmart-ZBT-A19-CCT"
    deviceLabel: Ecosmart-ZBT
    manufacturer: The Home Depot
    model: Ecosmart-ZBT-A19-CCT-Bulb
    deviceProfileName: level-colortemp-2700-6500
  - id: "Sengled/E11-G13"
    deviceLabel: Sengled E11-G13
    manufacturer: sengled
    model: E11-G13
    deviceProfileName: switch-level
