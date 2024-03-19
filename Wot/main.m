/*
 
 Wot: Wot WHAT is what? Unexpected behavior from CoreAudio.
 
 main.m
 
 A demonstration that can show getting 'WHAT' instead of 'what' as an
 return/error code from AudioObjectGetPropertyData(). I see that error code
 when attempting to get the Channel Number Name or the Channel Category Name
 for my iPhone Microphone or the MacBook Pro Microphone audio devices.
 
 Running macOS 14.4 Sonoma on a Intel MacBook Pro 15" 2019.
 
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
 
 I expect that 
 
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
 
 */

/*
 
 With the exception of the original portions of checkError(), all other code
 here is Copyright 2024 Darryl Ramm.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 Portions of checkError() are based on sample code provided with the book
 "Learning Core Audio" by Chris Adamson and Kevin Avila. And may be governed
 by a different license.
 
 */


#import <Foundation/Foundation.h>
#include <CoreAudio/AudioHardware.h>

void CheckError(OSStatus error, const char *operation);
CFStringRef getCFString(AudioObjectID device, AudioObjectPropertyAddress propertyAddress);
CFStringRef getCFChannelName(AudioObjectID id, AudioObjectPropertyScope directionProperty, AudioObjectPropertyElement channel);
CFStringRef getCFChannelCategoryName(AudioObjectID id, AudioObjectPropertyScope directionProperty, AudioObjectPropertyElement channel);
CFStringRef getCFChannelNumberName(AudioObjectID id, AudioObjectPropertyScope directionProperty, AudioObjectPropertyElement channel);

// main loop
void processDevice(AudioObjectID id);
void processDeviceChannels(AudioObjectID id, AudioObjectPropertyScope directionProperty);


int main(int argc, const char *argv[]) {

    UInt32 size;
    AudioObjectID *audioDevices;
    
    static const AudioObjectPropertyAddress devicesAddress = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal, // scope makes no difference?
        kAudioObjectPropertyElementMain
        };
    
    AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &devicesAddress, 0, NULL, &size);
    audioDevices = (AudioObjectID *) malloc(size);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &devicesAddress, 0, NULL, &size, audioDevices);
    UInt32 nDevices = size / sizeof(AudioObjectID);

    for (UInt32 i = 0; i < nDevices; i++) {
        processDevice(audioDevices[i]);
    }
    
    exit(0);
}
    

void processDevice(AudioObjectID id) {
    
    static const AudioObjectPropertyAddress nameAddress = {
        kAudioObjectPropertyName,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
        };

    static const AudioObjectPropertyAddress manufacturerAddress = {
        kAudioObjectPropertyManufacturer,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
        };

    NSLog(@"   ID  Device Name                         Manufacturer");
    NSLog(@" ----  ----------------------------------  --------------------------------");
    NSLog(@" 0x%2x  %-34@  %-34@",
          id,
          (__bridge NSString *) getCFString(id, nameAddress),
          (__bridge NSString *) getCFString(id, manufacturerAddress));
    
    processDeviceChannels(id, kAudioDevicePropertyScopeInput);
    processDeviceChannels(id, kAudioDevicePropertyScopeOutput);
    
    NSLog(@" ");
    NSLog(@" **************************************************************************");
}

        
void processDeviceChannels(AudioObjectID id, AudioObjectPropertyScope directionProperty) {
        
    OSStatus error;
    UInt32 nStreams;
    UInt32 size;
        
    if ((directionProperty != kAudioObjectPropertyScopeInput) && (directionProperty != kAudioObjectPropertyScopeOutput)) {
        NSLog(@"Fatal error: processDeviceChannels(): Invalid directionProperty == %d", directionProperty);
        exit(-1);
    }
    
    AudioObjectPropertyAddress streamConfigurationAddress = {
        kAudioDevicePropertyStreamConfiguration,
        directionProperty,
        kAudioObjectPropertyElementMain
    };
    
    error = AudioObjectGetPropertyDataSize(id, &streamConfigurationAddress, 0, NULL, &size);
    CheckError(error, "processDeviceChannels(): AudioObjectGetPropertyData());");
    
    AudioBufferList *audioBufferListPtr = (AudioBufferList *) malloc(size);
    
    if (audioBufferListPtr == NULL) {
        NSLog(@"Error: processDevice(): malloc(audioBufferListSize) failed");
        exit(-1);
    }
    
    error = AudioObjectGetPropertyData(id, &streamConfigurationAddress, 0, NULL, &size, audioBufferListPtr);
    CheckError(error, "2 AudioObjectGetPropertyData(id, &streamConfigurationAddress, 0, NULL, &audioBufferListSize, audioBufferListPtr);");
    
    nStreams = audioBufferListPtr->mNumberBuffers;
    
    if (nStreams == 0) {
        return; // No channels in this direction
    }
    
    AudioObjectPropertyAddress deviceStreamsAddress = {
        kAudioDevicePropertyStreams,
        directionProperty,
        kAudioObjectPropertyElementMain
    };
    
    error = AudioObjectGetPropertyDataSize(id, &deviceStreamsAddress, 0, NULL, &size);
    CheckError(error, "3 AudioObjectGetPropertyDataSize(AudioDevices[i], &kInputPropertyStreamsAddress, 0, NULL, &size);");
    
    UInt32 numAudioStreamsID = size/sizeof(AudioStreamID);
    
    AudioStreamID audioStreamIDArray[numAudioStreamsID];
     
    error = AudioObjectGetPropertyData(id, &deviceStreamsAddress, 0, NULL, &size, audioStreamIDArray);
    CheckError(error, "4 AudioObjectGetPropertyData(audioDevices, &kAudioDevicePropertyStreamsAddress, 0, NULL, &size, audioStreamIDArray);");
    
    AudioObjectPropertyAddress streamStartAddress = {
        kAudioStreamPropertyStartingChannel,
        directionProperty,
        kAudioObjectPropertyElementMain
    };
    
    NSLog(@" ----------------------------------%s--------------------------------",
           directionProperty == kAudioObjectPropertyScopeInput ? " Input -" : " Output ");
    NSLog(@" Stream #  Chan  Channel NumberName  Channel Name        Channel Category");
    NSLog(@" --------  ----  ------------------  ------------------  ------------------");
    
    UInt32 startChannel=1;
    size = sizeof(startChannel);
    
    for (UInt32 stream = 0; stream < nStreams; stream++) {
        
        AudioObjectPropertyAddress streamDirectionAddress = {
            kAudioStreamPropertyDirection,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        
        UInt32 direction;
        size = sizeof(direction);
        
        error = AudioObjectGetPropertyData(audioStreamIDArray[stream], &streamDirectionAddress, 0, NULL, &size, &direction);
        CheckError(error, "4 AudioObjectGetPropertyData(audioStreamIDArray[stream], &streamDirectionAddress, 0, NULL, &size, &direction);");

        error = AudioObjectGetPropertyData(audioStreamIDArray[stream], &streamStartAddress, 0, NULL, &size, &startChannel);
        CheckError(error, "5 AudioObjectGetPropertyData(audioStreamIDArray[stream], &streamStartAddress, 0, NULL, &size, &startChannel)");
        
        /*NSLog(@"stream = %d, direction = %d %s, startChannel=%d, numChannel = %d",
                stream,
                direction, (direction==0) ? "Output" : "Input",
                startChannel,
                audioBufferListPtr->mBuffers[stream].mNumberChannels); */
        
        for (UInt32 channel = startChannel; channel < (startChannel + audioBufferListPtr->mBuffers[stream].mNumberChannels); channel++) {
            
            NSLog(@" %8d  %4d  %18@  %18@  %18@",
                  stream,
                  channel,
                  (__bridge NSString *)getCFChannelNumberName(id, directionProperty, channel),
                  (__bridge NSString *)getCFChannelName(id, directionProperty, channel),
                  (__bridge NSString *)getCFChannelCategoryName(id, directionProperty, channel));
        }
    }
}


CFStringRef getCFString(AudioObjectID id, AudioObjectPropertyAddress propertyAddress) {
    
    OSStatus error;
    UInt32 size;
    CFStringRef cfString;
    
    if (!AudioObjectHasProperty(id, &propertyAddress)) {
        return CFSTR("NO SUCH PROPERTY");
    }
    
    error = AudioObjectGetPropertyDataSize(id, &propertyAddress, 0, NULL, &size);
    CheckError(error, "getCFString(): AudioObjectGetPropertyDataSize()");

    error = AudioObjectGetPropertyData(id, &propertyAddress, 0, NULL, &size, &cfString);
    CheckError(error, "getCFString(): AudioObjectGetPropertyData()");
    
    if (error != kAudioHardwareNoError) {
        return(CFSTR("GET PROPERTY ERROR"));
    }

    return cfString;
}


CFStringRef getCFChannelName(AudioObjectID id, AudioObjectPropertyScope directionProperty, AudioObjectPropertyElement channel) {
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyElementName,
        directionProperty,
        channel
    };
    
    return getCFString(id, propertyAddress);
}


CFStringRef getCFChannelCategoryName(AudioObjectID id, AudioObjectPropertyScope directionProperty, AudioObjectPropertyElement channel) {
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyElementCategoryName,
        directionProperty,
        channel};
    
    return getCFString(id, propertyAddress);
}


CFStringRef getCFChannelNumberName(AudioDeviceID id, AudioObjectPropertyScope directionProperty, AudioObjectPropertyElement channel) {
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyElementNumberName,
        directionProperty,
        channel};

    return getCFString(id, propertyAddress);
}


// CheckError() is based on code from the book "Learning Core Audio" by Chris Adamson and Kevin Avila
void CheckError(OSStatus error, const char *operation) {
    
    // Add capitalized error codes here. Not sure why 'WHAT' exists
    CF_ENUM(OSStatus) {
        kCapsAudioHardwareNotRunningError           = 'STOP',
        kCapsAudioHardwareUnspecifiedError          = 'WHAT',
        kCapsAudioHardwareUnknownPropertyError      = 'WHO?',
        kCapsAudioHardwareBadPropertySizeError      = '!SIZ',
        kCapsAudioHardwareIllegalOperationError     = 'NOPT',
        kCapsAudioHardwareBadObjectError            = '!OBJ',
        kCapsAudioHardwareBadDeviceError            = '!DEV',
        kCapsAudioHardwareBadStreamError            = '!STR',
        kCapsAudioHardwareUnsupportedOperationError = 'UNOP',
        kCapsAudioHardwareNotReadyError             = 'NRDY',
        kCapsAudioDeviceUnsupportedFormatError      = '!DAT',
        kCapsAudioDevicePermissionsError            = '!HOG'
    };
    
    if (error == noErr) return;
    
    char errorString[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(errorString, "%d", (int)error);
    
    switch (error) {
        
    case kAudioHardwareNoError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The function call completed successfully.");
            break;
        
    case kAudioHardwareNotRunningError:
    case kCapsAudioHardwareNotRunningError:

            NSLog(@"Error: %s (%s): %s", operation, errorString, "The function call requires that the hardware be running but it isn't.");
            break;
        
    case kAudioHardwareUnspecifiedError:
    case kCapsAudioHardwareUnspecifiedError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The function call failed while doing something that doesn't provide any error messages.");
            break;
        
    case kAudioHardwareUnknownPropertyError:
    case kCapsAudioHardwareUnknownPropertyError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The AudioObject doesn't know about the property at the given address.");
            break;
        
    case kAudioHardwareBadPropertySizeError:
    case kCapsAudioHardwareBadPropertySizeError:
            NSLog(@"Error: %s (%s): %s",  operation, errorString, "An improperly sized buffer was provided when accessing the data of a property.");
            break;
        
    case kAudioHardwareIllegalOperationError:
    case kCapsAudioHardwareIllegalOperationError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The requested operation couldn't be completed.");
            break;
        
    case kAudioHardwareBadObjectError:
    case kCapsAudioHardwareBadObjectError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The AudioObjectID passed to the function doesn't map to a valid AudioObject.");
            break;
        
    case kAudioHardwareBadDeviceError:
    case kCapsAudioHardwareBadDeviceError:
            NSLog(@"Error: %s (%s): %s",  operation, errorString, "The AudioObjectID passed to the function doesn't map to a valid AudioDevice.");
            break;
        
    case kAudioHardwareBadStreamError:
    case kCapsAudioHardwareBadStreamError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The AudioObjectID passed to the function doesn't map to a valid AudioStream.");
            break;
        
    case kAudioHardwareUnsupportedOperationError:
    case kCapsAudioHardwareUnsupportedOperationError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The AudioObject doesn't support the requested operation.");
            break;
        
    case kAudioHardwareNotReadyError:
    case kCapsAudioHardwareNotReadyError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The AudioObject isn't ready to do the requested operation.");
            break;
        
    case kAudioDeviceUnsupportedFormatError:
    case kCapsAudioDeviceUnsupportedFormatError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The AudioStream doesn't support the requested format.");
            break;
        
    case kAudioDevicePermissionsError:
    case kCapsAudioDevicePermissionsError:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "The requested operation can't be completed because the process doesn't have permission.");
            break;
            
    default:
            NSLog(@"Error: %s (%s): %s", operation, errorString, "UNKNOWN ERROR");
            break;
        
    }
    //exit(1); // Don't exit for debugging.
}
