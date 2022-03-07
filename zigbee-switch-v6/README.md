## (NEW RELEASE) Version 6 of the Edge Beta Driver: Zigbee Switch Mc

## Improvements:

To improve the functions of Timer, which cannot be easily done with the app, I have changed the Random Off-On function to a Timer Mode function, which has the options:

- Inactive: Disables the timer and turns off the device, starting to function as a manual switch

- Random: Alternate on and off randomly, between the maximum and minimum times chosen in Preferences

- Program: Turn on and off with fixed times for On and Off chosen in Preferences

## (NEW RELEASE) Version 5 of the Edge Beta Driver: Zigbee Switch Mc

## Improvements:

At the request of @milandjurovic71 , one of his many good ideas, Add to devices a simulated meter of power and energy consumption.

(I will implement it in a few days in Zigbee Light Multifunction Mc too)

Added Capability PowerMeter:

Displays the rated power entered in preferences, when device is On

The standard graph shows the consumption in each hour or day

Added Capability EnergyMeter:

Displays the energy consumption accumulated during the device’s operating time (On)

The Standard Graph shows the accumulated Energy meter by hour or days of the last month

Added Custom Capability to Reset Energy Meter Accumulated Value:

The switch always gets into On state (blue)

When device is first installed, it displays the installation date.

when you run a Energy reset it displays the current date as the last reset

Added in Preference the setting to enter the Rated Power in W of the load connected to the device:

Power range between 0 w and 4000 w

If 0 w is entered , the power calculation and power and Energy consumption function is disabled. The accumulated values are not deleted.

## (NEW RELEASE) Version 4.0 of Edge Driver Zigbee Switch Mc.

The new version adds:

- Categories set to SmartPlug in all profiles in order to mor option for change Icon from App tool

- Added more Icons in preferences: Tv, Washer, Refrigerator, Air Conditioner, Oven

## (NEW RELEASE) Version 3.0 of Edge Driver Zigbee Switch Mc.

The new version adds:

- Version Info in Device Preferences

## Randon ON-OFF Function so that they can be used in automations to turn on and off randomly together with the Bulbs that already have it.

- Made with a Custom Capability it can be activated and deactivated with automations and scenes.

- The Minimum and Maximum times between which the bulb will randomly turn on and off is set in Preferences and can be set between 0.5 minutes and 25 minutes, depending on the needs of each one.

## How does it work?:

- When the Random On Off functions is activated, a random interval is calculated between the values ​​chosen in preferences.

- When the calculated interval is met, it will turn off or on.

- When the Random function is deactivated, the light also turns off.

- You can create scenes and automations to activate and deactivate the function.

## Preferences for Profile Icon Change Light, Plug, Switch, fan, Camera, Humidifier

## For devices supported see Fingerprints.yml file: