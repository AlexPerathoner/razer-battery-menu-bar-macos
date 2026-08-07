//
//  battery.h
//  razer-battery-menu-bar
//
//  Created by Alex Perathoner on 26/11/24.
//

// battery.h
#ifndef BATTERY_H
#define BATTERY_H

// Reads battery percentage (0-100) and charging state in one device enumeration.
// Returns -1 if no battery device was found or the read failed.
// *charging is set to 0/1, or left at -1 if it could not be read.
int get_battery_status(int *charging);

#endif
