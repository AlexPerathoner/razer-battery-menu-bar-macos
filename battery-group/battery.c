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
 returns 0 if device is wired, 1 if wireless
 */
int is_device_wireless(UInt16 productId) {
    return (productId == USB_DEVICE_ID_RAZER_MAMBA_2012_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_MAMBA_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_NAGA_PRO_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_MAMBA_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_MAMBA_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS) ||
        (productId == USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS);
}


int get_battery_level(void) {
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;

    for (int i = 0; i < allDevices.size; i++)
    {
        RazerDevice device = razerDevices[i];

        if (is_device_wireless(device.productId))
        {
            printf("%#06x\n", device.productId);
            char battery_level[10] = {0};                                                  // Buffer to hold raw battery level
            ssize_t result = razer_attr_read_get_battery(device.usbDevice, battery_level); // Assuming usbDevice is accessible
            if (result > 0)
            {
                int battery_level_percent = atoi(battery_level);
                printf("Battery level: %d%%\n", battery_level_percent);
                closeAllRazerDevices(allDevices);
                return battery_level_percent;
            }
            else
            {
                printf("Failed to read battery level.\n");
            }
        }
    }

    closeAllRazerDevices(allDevices);
    return -1;
}

int is_charging(void) {
    RazerDevices allDevices = getAllRazerDevices();
    RazerDevice *razerDevices = allDevices.devices;

    for (int i = 0; i < allDevices.size; i++)
    {
        RazerDevice device = razerDevices[i];

        if (is_device_wireless(device.productId))
        {
            printf("%#06x\n", device.productId);
            char charging_buf[10] = {0};
            ssize_t result = razer_attr_read_is_charging(device.usbDevice, charging_buf); // Assuming usbDevice is accessible
            if (result > 0)
            {
                
                printf("Device %d charging status: %s", device.internalDeviceId, charging_buf);
                /**
                 * Read device file "is_charging"
                 *
                 * Returns 0 when not charging, 1 when charging
                 */
                closeAllRazerDevices(allDevices);
                return atoi(charging_buf);
            }
            else
            {
                printf("Failed to read battery level.\n");
            }
        }
    }
    
    closeAllRazerDevices(allDevices);
    return -1;
}
