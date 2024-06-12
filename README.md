# Wot: Wot WHAT is what? Unexpected behavior from CoreAudio.

 Quick Note: Apple has partially addressed the issues here in macOS Sequoia 15.0 
 (24A5264n). Where the error code 'what' is now correctly returned instead of 'WHAT'. 
 However the bug with AudioObjectHasProperty() returning TRUE when the matching 
 AudioObjectGetPropertyData() does not work has sofar not been fixed.

 ---
 
 This CoreAudio command line program can show AudioObjectGetPropertyData() returning
'WHAT' instead of 'what' as an error code. I see that incorrect/unexpected 'WHAT' 
 error code when attempting to get the Channel Number Name or the Channel Category Name
 for my iPhone Microphone or the MacBook Pro Microphone audio devices.
 
 I am running macOS 14.4 Sonoma on a Intel MacBook Pro 15" 2019.
 
 A question about this posted to the Apple Developer Forum:
 https://developer.apple.com/forums/thread/748749
 
 This program loops though all audio devices on a system, and all channels on 
 each device. Uses AudioObjectGetPropertyData() to get the device name and
 manufacturer name and then iterate over the input and output channels getting
 Channel Number Name, Channel Name and Channel Category.
 
 I would exect some of these values (like channel Name frequently is) to be 
 empty CFStrings. Or for others to return FALSE to AudioObjectHasProperty() if
 the property does no exist. And that is how things behave on my system for
 most devices...
 
 ... except for the MacBook Pro Microphone and iPhone Microphone devices.
 There I get AudioObjectHasProperty() return TRUE but then a
 AudioObjectGetPropertyData() call with the exact same AudioObjectPropertyAddress
 returns with an error code 'WHAT'.
 
 I expect that:
 
 1. If AudioObjectHasProperty() returns TRUE that the matching
    AudioObjectGetPropertyData() works.
 
 and
 
 2. What the hecks is 'WHAT'? If an error code is returned I assume it is 
    supposed to mean 'what' aka kAudioHardwareUnspecifiedError then why is
    that actual error value not used?
 
 This program uses NSLog() instead of printf()/wprintf() to lazilly handle 
 device names with UTF characters. Output will likely not be formatted
 correctly when run from a shell command line. Best to run it from within
 Xcode and view the output on the Xcode console.
