## NEW RELEASE) Version 3.0 of Edge Beta Driver: Zigbee Temp Humidity Sensor Mc:

Improvements:

Added in preferences new offset settings for Atmospheric Pressure and Illuminance capabilities

Added preference to use a single or multiple tile that shows all the capabilities of the device


## NEW RELEASE) New Version 2.5 of Edge Beta Driver: Zigbee Temp Humidity Sensor Mc:

## Improvements:

- Added new profile with Temperature, RelativeHumidity, Atmospheric Pressure in (kPa & mBar) and Illuminance

- Added report interval settings in preferences for all capabilities

- Note: Not all devices accept configuration changes after pairing

- For some manufacturers added new subdriver to Battery voltage handler @Raimundo

 -New devices added


## (NEW RELEASE) Beta Edge Drive Zigbee Temp Humidity Sensor Mc

At the request of @milandjurovic71, and thanks to his tests, this Driver is shared for temperature, humidity and atmospheric pressure sensors, if it has this capability.

Thanks to @GiacomoF, for suggesting to show atmospheric pressure in mBars to compensate for the low precision shown in kPa (10 mBar), as could be seen in the groovy DTH.

For sensors with capability of measuring atmospheric pressure, a Custom Capability is added to display the information in mBar.

It has been tested with an Aqara Weather sensor and stock edge libraries.

To improve the information on Battery of the Aqara sensors, the xiaomi_utils.lua that @Zach_Varberg shared in github repository has been used. Thanks

In preferences has the options to configure the intervals and precision of the temperature reports, for the sensors that use the default zigbee configuration.

Fingerprints of more sensor models can be added.

The sensor models that are incorporated into this driver will also be added to the Zigbee Temp Sensor with Thermostat Mc driver, in case want to convert it into a sensor with thermostat functions.

As it has a custom capability, in Hubs that do not have firmware version 40.0006, they will have to do a Reboot from the Hub IDE or turn it off, only once after the first installation of a device.

## For supported devices see fingerprints.yml file