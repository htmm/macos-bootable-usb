#!/usr/bin/osascript
#
# Create Install Media, Copyright (c) 2024 chris1111. All Right Reserved.
# Credit: Apple
# Version "1.0"
# AppleScript Code

set theAction to button returned of (display dialog "
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

--If Create Install Media
if theAction = "Create Install Media" then
	do shell script "open -F -a 'Disk Utility'"
	delay 1
	tell application "Disk Utility"
		activate
	end tell
	
	repeat
		if application "Disk Utility" is not running then exit repeat
	end repeat
	activate me
	set Volumepath to paragraphs of (do shell script "ls /Volumes")
	set Diskpath to choose from list Volumepath with prompt "
To continue, select the volume you want to use, then press the OK button" OK button name "OK" with multiple selections allowed
	if Diskpath is false then
		display dialog "Quit Installer " with icon 0 buttons {"EXIT"} default button {"EXIT"}
		return
		
		return (POSIX path of Diskpath)
	end if
	try
		--If Continue
		set theAction to button returned of (display dialog "
Choose the location of your Install macOS.app" with icon 2 buttons {"Quit", "10.13 to Sonoma 14"} cancel button "Quit" default button {"10.13 to Sonoma 14"})
		if theAction = "10.13 to Sonoma 14" then
			--If 10.13 to Sonoma 14
			
			set InstallOSX to choose file of type {"XLSX", "APPL"} default location (path to applications folder) with prompt "Choose your Install macOS.app"
			set OSXInstaller to POSIX path of InstallOSX
			
			delay 2
			set the_results to (display dialog "Please confirm your choice?
Create Install Media from --> " & (InstallOSX as text) & "
Install to --> " & (Diskpath as text) with icon 2 buttons {"Cancel", "OK"} cancel button "Cancel" default button "OK")
			
			set button_returned to button returned of the_results
			if button_returned is "OK" then tell application "Terminal"
				activate
				set currentTab to do script "sudo \"" & OSXInstaller & "Contents/Resources/createinstallmedia\" --volume /Volumes/\"" & Diskpath & "\" --nointeraction"
			end tell
			
		end if
	end try
end if
