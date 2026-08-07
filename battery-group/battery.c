//
//  battery.c
//  razer-battery-menu-bar
//
//  Created by Alex Perathoner on 26/11/24.
//

#include <stdio.h>
#include <stdlib.h>
#include "battery.h"
#include "razerdevice.h"
#include "razermouse_driver.h"


/**
 returns 1 if the device reports a battery, 0 otherwise.

 A wireless mouse enumerates under a different productId depending on how it is
 connected (dongle, dock or cable), so every variant has to be listed here or the
 battery silently disappears the moment the mouse is plugged in.
 */
int is_battery_device(UInt16 productId) {
    switch (productId)
    {
        case USB_DEVICE_ID_RAZER_MAMBA_2012_WIRELESS:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_ATHERIS_RECEIVER:
        case USB_DEVICE_ID_RAZER_OROCHI_V2_RECEIVER:
        case USB_DEVICE_ID_RAZER_OROCHI_V2_BLUETOOTH:
            return 1;
        default:
            return 0;
    }
}

/**
 Both values come from the same open USB handle: opening and closing the device
 twice in a row makes the second command far more likely to come back BUSY.

 See battery.h for the contract.
 */
int get_battery_status(int *charging) {
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;
    int level = -1;

    if (charging != NULL) {
        *charging = -1;
    }

    for (int i = 0; i < allDevices.size; i++)
    {
        RazerDevice device = razerDevices[i];

        if (!is_battery_device(device.productId))
        {
            continue;
        }

        printf("Reading battery from device %#06x\n", device.productId);

        char battery_level[16] = {0};
        razer_attr_read_get_battery(device.usbDevice, battery_level);

        // The driver writes response_report.arguments[1] verbatim, on a 0-255 scale,
        // and its return value is sprintf's character count - never an error code.
        // A failed transfer yields a zeroed report, i.e. exactly "0", so a raw 0 is
        // treated as a failed read rather than reported as a confident 0%.
        int battery_level_raw = atoi(battery_level);
        if (battery_level_raw <= 0)
        {
            printf("Failed to read battery level (raw buffer: \"%s\").\n", battery_level);
            continue;
        }

        level = (battery_level_raw * 100) / 255;
        if (level > 100) {
            level = 100;
        }
        printf("Battery level raw: %d -> %d%%\n", battery_level_raw, level);

        /**
         * Read device file "is_charging"
         *
         * Returns 0 when not charging, 1 when charging
         */
        char charging_buf[16] = {0};
        razer_attr_read_is_charging(device.usbDevice, charging_buf);
        if (charging != NULL)
        {
            *charging = atoi(charging_buf) != 0;
            printf("Device %d charging status: %s", device.internalDeviceId, charging_buf);
        }

        break;
    }

    if (level == -1)
    {
        printf("No Razer battery device found (%d Razer device(s) enumerated).\n", allDevices.size);
    }

    closeAllRazerDevices(allDevices);
    return level;
}
