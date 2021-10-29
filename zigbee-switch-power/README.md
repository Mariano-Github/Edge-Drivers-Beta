## (NEW RELEASE) Version 1.0 of Edge Driver Zigbee Switch Power Mc.

The new version adds:

- Version Info in Device Preferences

## Randon ON-OFF Function so that they can be used in automations to turn on and off randomly together with the Bulbs that already have it.

- Made with a Custom Capability it can be activated and deactivated with automations and scenes.

- The Minimum and Maximum times between which the bulb will randomly turn on and off is set in Preferences and can be set between 0.5 minutes and 25 minutes, depending on the needs of each one.

## How does it work?:

- When the Random On Off functions is activated, a random interval is calculated between the values ​​chosen in preferences.

- When the calculated interval is met, it is chosen randomly if the light turns On or Off. This means that not whenever it is on it will turn off or vice versa.

- When the Random function is deactivated, the light also turns off.

- You can create scenes and automations to activate and deactivate the function.

## Preferences for Profile Icon Change Light, Plug, Switch

## Devices 29-Oct-2021:
zigbeeManufacturer:
  - id: "SAMOTECH/MS-104Z
    deviceLabel: Samotech Switch
    manufacturer: _TYZB01_iuepbmpv
    model: TS0121
    deviceProfileName: switch-power
  - id: "Computime/SLP2b"
    deviceLabel: Computime Plug SLP2b
    manufacturer: Computime
    model: SLP2b
    deviceProfileName: switch-power-plug
