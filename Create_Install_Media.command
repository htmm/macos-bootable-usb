#!/usr/bin/osascript
#
# Create Install Media, Copyright (c) 2024 chris1111. All Right Reserved.

Welcome Create Install Media
-------------------------
*Gatekeeper* then *SIP Security* must be disabled 
to create macOS Install drive.
--------------------------
You can create a bootable USB key 
from macOS High Sierra 10.13 to macOS Sonoma 14
		
Format your USB Drive with Disk Utility 
in the format Mac OS Extended (Journaled) 
GUID Partition Map
*****************************
You must quit Disk Utility to continue 
installation !" with icon 2 buttons {"Quit", "Create Install Media"} cancel button "Quit" default button {"Create Install Media"})
To continue, select the volume you want to use, then press the OK button" OK button name "OK" with multiple selections allowed
Choose the location of your Install macOS.app" with icon 2 buttons {"Quit", "10.13 to Sonoma 14"} cancel button "Quit" default button {"10.13 to Sonoma 14"})
Create Install Media from --> " & (InstallOSX as text) & "
Install to --> " & (Diskpath as text) with icon 2 buttons {"Cancel", "OK"} cancel button "Cancel" default button "OK")