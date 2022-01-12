## Added groups configuration in preferences
-- not tested

## (New RELEASE) New Edge Drive Zigbee Light Multifunction Mc:

- This Driver has all the functions of the Zigbee Level ColorTemp Bulb Mc driver, which it replaces and will not be updated any more.

## Added Color Control Capability with profiles for RGB and RGBW with 2700k-6500k Color temperature.

Thanks to the suggestion and collaboration to do the tests for @milandjurovic71

## (NEW RELEASE) Version 2.0 of the Edge Driver Zigbee Light Multifunction Mc

## Improvements and bug fixes:

At the request of @milandjurovic71, preferences have been added for Minimum and Maximum Level settings of the Circadian Lighting function. In this way they are independent of the Llevel settings for progressive ON

The code has been corrected to prevent the “ Active " selections of the Progressive ON-OFF and Circadian Lighting functions from being reset to " Inactive " when a Reboot Hub or Driver update happens.

## (NEW RELEASE) Version 3.0 of the Edge Driver Zigbee Light Multifunction Mc

## Improvements and bug fixes:

My Thanks to @milandjurovic71 for test the driver with his bulbs.

As a request, @eric182 , the Continuous Color Change function has been added:

-Has a Custom Capability to turn the function Active and Inactive.

-Has a Custom Capability to modify the Timer between 1 and 20 sec for Color Changes

-Has a Custom Capability to select Color Change Mode

-Continuous Mode : The initial color is adjusted randomly and changes continuously with the rhythm of the timer chosen between 1 and 20 Sec.

-Random Mode : Color is adjusted randomly continuously with each timer interval

-All Modes : Both modes run randomly for a time between 50 sec to 300 sec each random cycle. Color change with random timer between 1 and 3 seconds.

-All three capabilities are accessible for use with routines and scenes
Color change timer and color change mode can be modified dynamically.

IMPORTANT: As Driver have new custom Capabiliies you may have to do a HUB reboot when you install it for the first time.
You do not need to uninstall the device, just clear the app cache and when the hub is online it will work

## (NEW RELEASE) Version 4.0 of the Edge Driver Zigbee Light Multifunction Mc

## Improvements and bug fixes:

-Added new Color Profile Temperature from 2200k to 4000k

-Modified in preferences the setting of Maximum Color Temperature value, since smartthings have fixed those values greater than 999 can be entered.

-Modified the execution Timer loops for progressive On and Off to achieve smoother changes in times less than 2 minutes.

-Modified the Random On-Off function so that a device state change is always executed at the end of the random period. Before the on-off state was randomly chosen, this seem confused with the Random Next change time information.

This modification was also made in the zigbee switch Mc and zigbee Switch Power Mc drivers.

-Modification that prevents the Random On-Off function stopping if it is active when a hub reboot or driver version update occurs.
-Added manufacturer impression, model and length of strings in logcat, when running lifecycle Handler infoChanged

## Works with lights, led strips with profiles:

Switch & Level
Switch, Level & ColorTemperature
Switch, Level, RGB, RGBW, RGBCCT, CCT
Could work with zigbee single dimmers, but not tested

## Included Devices :

See fingerprints.yml file
