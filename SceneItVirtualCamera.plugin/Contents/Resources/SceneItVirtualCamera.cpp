//
//  SceneItVirtualCamera.cpp
//  Scene It Virtual Camera Plugin
//
//  CoreMediaIO DAL Plugin Implementation
//

#include "SceneItVirtualCamera.h"
#include <CoreMediaIO/CMIOHardwarePlugIn.h>
#include <dispatch/dispatch.h>
#include <sys/mman.h>
#include <semaphore.h>
#include <unistd.h>
#include <pthread.h>

// Global plugin state
static CMIOHardwarePlugInInterface** gPlugInInterface = NULL;
static CMIOObjectID gDeviceObjectID = kCMIOObjectUnknown;
static CMIOObjectID gStreamObjectID = kCMIOObjectUnknown;
static bool gIsStreaming = false;

// IPC state
static SceneItSharedMemory* gSharedMemory = NULL;
static int gSharedMemoryFD = -1;
static sem_t* gFrameSemaphore = NULL;
static dispatch_queue_t gFrameQueue = NULL;
static dispatch_source_t gFrameTimer = NULL;

// Forward declarations
static OSStatus SceneItVirtualCamera_QueryInterface(void* self, REFIID iid, LPVOID* ppv);
static ULONG SceneItVirtualCamera_AddRef(void* self);
static ULONG SceneItVirtualCamera_Release(void* self);

static OSStatus SceneItVirtualCamera_Initialize(CMIOHardwarePlugInRef self, CMIOObjectID objectID);
static OSStatus SceneItVirtualCamera_InitializeWithObjectID(CMIOHardwarePlugInRef self, CMIOObjectID objectID);
static OSStatus SceneItVirtualCamera_Teardown(CMIOHardwarePlugInRef self);

static OSStatus SceneItVirtualCamera_ObjectShow(CMIOHardwarePlugInRef self, CMIOObjectID objectID);
static OSStatus SceneItVirtualCamera_ObjectHasProperty(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, Boolean* outHasProperty);
static OSStatus SceneItVirtualCamera_ObjectIsPropertySettable(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, Boolean* outIsSettable);
static OSStatus SceneItVirtualCamera_ObjectGetPropertyDataSize(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, UInt32 qualifierDataSize, const void* qualifierData, UInt32* outDataSize);
static OSStatus SceneItVirtualCamera_ObjectGetPropertyData(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, UInt32 qualifierDataSize, const void* qualifierData, UInt32 dataSize, UInt32* outDataUsed, void* outData);
static OSStatus SceneItVirtualCamera_ObjectSetPropertyData(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, UInt32 qualifierDataSize, const void* qualifierData, UInt32 dataSize, const void* data);

static OSStatus SceneItVirtualCamera_StreamCopyBufferQueue(CMIOHardwarePlugInRef self, CMIOObjectID streamID, CMIODeviceStreamQueueAlteredProc queueAlteredProc, void* queueAlteredRefCon, CMSimpleQueueRef* outQueue);

// Plugin interface structure
static CMIOHardwarePlugInInterface gPlugInInterfaceStruct = {
    NULL,                                                     // _reserved
    SceneItVirtualCamera_QueryInterface,                     // QueryInterface
    SceneItVirtualCamera_AddRef,                              // AddRef
    SceneItVirtualCamera_Release,                             // Release
    SceneItVirtualCamera_Initialize,                          // Initialize
    SceneItVirtualCamera_InitializeWithObjectID,             // InitializeWithObjectID
    SceneItVirtualCamera_Teardown,                            // Teardown
    SceneItVirtualCamera_ObjectShow,                          // ObjectShow
    SceneItVirtualCamera_ObjectHasProperty,                   // ObjectHasProperty
    SceneItVirtualCamera_ObjectIsPropertySettable,           // ObjectIsPropertySettable
    SceneItVirtualCamera_ObjectGetPropertyDataSize,          // ObjectGetPropertyDataSize
    SceneItVirtualCamera_ObjectGetPropertyData,              // ObjectGetPropertyData
    SceneItVirtualCamera_ObjectSetPropertyData,              // ObjectSetPropertyData
    NULL,                                                     // DeviceStartStream (deprecated)
    NULL,                                                     // DeviceStopStream (deprecated)
    NULL,                                                     // DeviceRead (deprecated)
    SceneItVirtualCamera_StreamCopyBufferQueue,              // StreamCopyBufferQueue
};

#pragma mark - Entry Points

extern "C" {

OSStatus SceneItVirtualCamera_Initialize(CFUUIDRef requestedTypeUUID) {
    // Verify this is the correct plugin type
    if (!CFEqual(requestedTypeUUID, kCMIOHardwarePlugInTypeID)) {
        return kCMIOHardwareUnknownPropertyError;
    }
    
    // Initialize IPC
    return SceneItVirtualCamera_InitializeIPC();
}

void* SceneItVirtualCameraPlugInFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID) {
    if (!CFEqual(typeUUID, kCMIOHardwarePlugInTypeID)) {
        return NULL;
    }
    
    // Allocate plugin interface
    gPlugInInterface = (CMIOHardwarePlugInInterface**)malloc(sizeof(CMIOHardwarePlugInInterface*));
    if (gPlugInInterface == NULL) {
        return NULL;
    }
    
    *gPlugInInterface = &gPlugInInterfaceStruct;
    
    return gPlugInInterface;
}

OSStatus SceneItVirtualCamera_Teardown(void) {
    SceneItVirtualCamera_CleanupIPC();
    
    if (gPlugInInterface != NULL) {
        free(gPlugInInterface);
        gPlugInInterface = NULL;
    }
    
    return noErr;
}

} // extern "C"

#pragma mark - Plugin Interface Implementation

static OSStatus SceneItVirtualCamera_QueryInterface(void* self, REFIID iid, LPVOID* ppv) {
    CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(NULL, iid);
    
    if (CFEqual(interfaceID, kCMIOHardwarePlugInInterfaceID)) {
        *ppv = self;
        SceneItVirtualCamera_AddRef(self);
        CFRelease(interfaceID);
        return S_OK;
    }
    
    CFRelease(interfaceID);
    return E_NOINTERFACE;
}

static ULONG SceneItVirtualCamera_AddRef(void* self) {
    return 1; // Static interface, no reference counting needed
}

static ULONG SceneItVirtualCamera_Release(void* self) {
    return 1; // Static interface, no reference counting needed
}

static OSStatus SceneItVirtualCamera_Initialize(CMIOHardwarePlugInRef self, CMIOObjectID objectID) {
    return SceneItVirtualCamera_InitializeWithObjectID(self, objectID);
}

static OSStatus SceneItVirtualCamera_InitializeWithObjectID(CMIOHardwarePlugInRef self, CMIOObjectID objectID) {
    // Create virtual camera device
    OSStatus error = SceneItVirtualCamera_CreateDevice(&gDeviceObjectID);
    if (error != noErr) {
        return error;
    }
    
    // Create video stream for the device
    error = SceneItVirtualCamera_CreateStream(gDeviceObjectID, &gStreamObjectID);
    if (error != noErr) {
        SceneItVirtualCamera_DestroyDevice(gDeviceObjectID);
        return error;
    }
    
    return noErr;
}

static OSStatus SceneItVirtualCamera_Teardown(CMIOHardwarePlugInRef self) {
    if (gStreamObjectID != kCMIOObjectUnknown) {
        SceneItVirtualCamera_DestroyStream(gStreamObjectID);
        gStreamObjectID = kCMIOObjectUnknown;
    }
    
    if (gDeviceObjectID != kCMIOObjectUnknown) {
        SceneItVirtualCamera_DestroyDevice(gDeviceObjectID);
        gDeviceObjectID = kCMIOObjectUnknown;
    }
    
    return noErr;
}

#pragma mark - Property Management

static OSStatus SceneItVirtualCamera_ObjectShow(CMIOHardwarePlugInRef self, CMIOObjectID objectID) {
    return noErr;
}

static OSStatus SceneItVirtualCamera_ObjectHasProperty(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, Boolean* outHasProperty) {
    *outHasProperty = false;
    
    switch (address->mSelector) {
        case kCMIOObjectPropertyName:
        case kCMIOObjectPropertyManufacturer:
        case kCMIOObjectPropertyElementName:
        case kCMIOObjectPropertyElementCategoryName:
        case kCMIOObjectPropertyElementNumberName:
            *outHasProperty = true;
            break;
            
        case kCMIODevicePropertyStreams:
            if (objectID == gDeviceObjectID) {
                *outHasProperty = true;
            }
            break;
            
        case kCMIOStreamPropertyDirection:
        case kCMIOStreamPropertyTerminalType:
        case kCMIOStreamPropertyStartingChannel:
        case kCMIOStreamPropertyLatency:
        case kCMIOStreamPropertyFormatDescriptions:
        case kCMIOStreamPropertyFormatDescription:
        case kCMIOStreamPropertyFrameRates:
        case kCMIOStreamPropertyFrameRate:
            if (objectID == gStreamObjectID) {
                *outHasProperty = true;
            }
            break;
    }
    
    return noErr;
}

static OSStatus SceneItVirtualCamera_ObjectIsPropertySettable(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, Boolean* outIsSettable) {
    *outIsSettable = false;
    
    // Most properties are read-only for our virtual camera
    switch (address->mSelector) {
        case kCMIOStreamPropertyFormatDescription:
        case kCMIOStreamPropertyFrameRate:
            if (objectID == gStreamObjectID) {
                *outIsSettable = true;
            }
            break;
    }
    
    return noErr;
}

static OSStatus SceneItVirtualCamera_ObjectGetPropertyDataSize(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, UInt32 qualifierDataSize, const void* qualifierData, UInt32* outDataSize) {
    switch (address->mSelector) {
        case kCMIOObjectPropertyName:
        case kCMIOObjectPropertyManufacturer:
        case kCMIOObjectPropertyElementName:
        case kCMIOObjectPropertyElementCategoryName:
        case kCMIOObjectPropertyElementNumberName:
            *outDataSize = sizeof(CFStringRef);
            break;
            
        case kCMIODevicePropertyStreams:
            *outDataSize = sizeof(CMIOObjectID);
            break;
            
        case kCMIOStreamPropertyDirection:
        case kCMIOStreamPropertyTerminalType:
        case kCMIOStreamPropertyStartingChannel:
        case kCMIOStreamPropertyLatency:
            *outDataSize = sizeof(UInt32);
            break;
            
        case kCMIOStreamPropertyFormatDescriptions:
            *outDataSize = sizeof(CFArrayRef);
            break;
            
        case kCMIOStreamPropertyFormatDescription:
            *outDataSize = sizeof(CMFormatDescriptionRef);
            break;
            
        case kCMIOStreamPropertyFrameRates:
            *outDataSize = sizeof(CMTime);
            break;
            
        case kCMIOStreamPropertyFrameRate:
            *outDataSize = sizeof(Float64);
            break;
            
        default:
            return kCMIOHardwareUnknownPropertyError;
    }
    
    return noErr;
}

static OSStatus SceneItVirtualCamera_ObjectGetPropertyData(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, UInt32 qualifierDataSize, const void* qualifierData, UInt32 dataSize, UInt32* outDataUsed, void* outData) {
    switch (address->mSelector) {
        case kCMIOObjectPropertyName:
            if (objectID == gDeviceObjectID) {
                *((CFStringRef*)outData) = CFSTR("Scene It Virtual Camera");
                *outDataUsed = sizeof(CFStringRef);
            } else if (objectID == gStreamObjectID) {
                *((CFStringRef*)outData) = CFSTR("Scene It Video Stream");
                *outDataUsed = sizeof(CFStringRef);
            }
            break;
            
        case kCMIOObjectPropertyManufacturer:
            *((CFStringRef*)outData) = CFSTR("Scene It");
            *outDataUsed = sizeof(CFStringRef);
            break;
            
        case kCMIODevicePropertyStreams:
            if (objectID == gDeviceObjectID) {
                *((CMIOObjectID*)outData) = gStreamObjectID;
                *outDataUsed = sizeof(CMIOObjectID);
            }
            break;
            
        case kCMIOStreamPropertyDirection:
            *((UInt32*)outData) = 1; // Output stream
            *outDataUsed = sizeof(UInt32);
            break;
            
        case kCMIOStreamPropertyTerminalType:
            *((UInt32*)outData) = kCMIOTerminalTypeCamera;
            *outDataUsed = sizeof(UInt32);
            break;
            
        case kCMIOStreamPropertyFrameRate:
            *((Float64*)outData) = 30.0; // 30 FPS
            *outDataUsed = sizeof(Float64);
            break;
            
        // TODO: Implement remaining properties
        default:
            return kCMIOHardwareUnknownPropertyError;
    }
    
    return noErr;
}

static OSStatus SceneItVirtualCamera_ObjectSetPropertyData(CMIOHardwarePlugInRef self, CMIOObjectID objectID, const CMIOObjectPropertyAddress* address, UInt32 qualifierDataSize, const void* qualifierData, UInt32 dataSize, const void* data) {
    // TODO: Implement property setters
    return kCMIOHardwareUnknownPropertyError;
}

#pragma mark - Stream Management

static OSStatus SceneItVirtualCamera_StreamCopyBufferQueue(CMIOHardwarePlugInRef self, CMIOObjectID streamID, CMIODeviceStreamQueueAlteredProc queueAlteredProc, void* queueAlteredRefCon, CMSimpleQueueRef* outQueue) {
    // TODO: Implement buffer queue for frame delivery
    return kCMIOHardwareUnknownPropertyError;
}

#pragma mark - Device and Stream Creation

OSStatus SceneItVirtualCamera_CreateDevice(CMIOObjectID* outDeviceID) {
    // This would typically register a new device with the system
    // For now, we use a static device ID
    *outDeviceID = 1000; // Static device ID
    return noErr;
}

OSStatus SceneItVirtualCamera_DestroyDevice(CMIOObjectID deviceID) {
    // Cleanup device resources
    return noErr;
}

OSStatus SceneItVirtualCamera_CreateStream(CMIOObjectID deviceID, CMIOObjectID* outStreamID) {
    // Create a video stream for the device
    *outStreamID = 2000; // Static stream ID
    return noErr;
}

OSStatus SceneItVirtualCamera_DestroyStream(CMIOObjectID streamID) {
    // Cleanup stream resources
    return noErr;
}

#pragma mark - Frame Processing

OSStatus SceneItVirtualCamera_StartStreaming(CMIOObjectID streamID) {
    if (gIsStreaming) {
        return noErr;
    }
    
    gIsStreaming = true;
    
    // Create frame processing timer
    gFrameQueue = dispatch_queue_create("com.sceneit.virtualcamera.frames", DISPATCH_QUEUE_SERIAL);
    gFrameTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, gFrameQueue);
    
    // 30 FPS timer
    dispatch_source_set_timer(gFrameTimer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 30, NSEC_PER_SEC / 60);
    
    dispatch_source_set_event_handler(gFrameTimer, ^{
        CVPixelBufferRef frame = SceneItVirtualCamera_GetNextFrame();
        if (frame) {
            // TODO: Send frame to the output stream
            CVPixelBufferRelease(frame);
        }
    });
    
    dispatch_resume(gFrameTimer);
    
    return noErr;
}

OSStatus SceneItVirtualCamera_StopStreaming(CMIOObjectID streamID) {
    if (!gIsStreaming) {
        return noErr;
    }
    
    gIsStreaming = false;
    
    if (gFrameTimer) {
        dispatch_source_cancel(gFrameTimer);
        dispatch_release(gFrameTimer);
        gFrameTimer = NULL;
    }
    
    if (gFrameQueue) {
        dispatch_release(gFrameQueue);
        gFrameQueue = NULL;
    }
    
    return noErr;
}

#pragma mark - IPC Implementation

OSStatus SceneItVirtualCamera_InitializeIPC(void) {
    // Create shared memory for frame data
    gSharedMemoryFD = shm_open(kSceneItSharedMemoryName, O_CREAT | O_RDWR, 0666);
    if (gSharedMemoryFD == -1) {
        return -1;
    }
    
    // Set shared memory size
    size_t sharedMemorySize = sizeof(SceneItSharedMemory);
    if (ftruncate(gSharedMemoryFD, sharedMemorySize) == -1) {
        close(gSharedMemoryFD);
        return -1;
    }
    
    // Map shared memory
    gSharedMemory = (SceneItSharedMemory*)mmap(NULL, sharedMemorySize, PROT_READ | PROT_WRITE, MAP_SHARED, gSharedMemoryFD, 0);
    if (gSharedMemory == MAP_FAILED) {
        close(gSharedMemoryFD);
        return -1;
    }
    
    // Initialize shared memory structure
    memset(gSharedMemory, 0, sharedMemorySize);
    
    // Create semaphore for frame synchronization
    gFrameSemaphore = sem_open(kSceneItSemaphoreName, O_CREAT, 0666, 0);
    if (gFrameSemaphore == SEM_FAILED) {
        munmap(gSharedMemory, sharedMemorySize);
        close(gSharedMemoryFD);
        return -1;
    }
    
    return noErr;
}

OSStatus SceneItVirtualCamera_CleanupIPC(void) {
    if (gFrameSemaphore && gFrameSemaphore != SEM_FAILED) {
        sem_close(gFrameSemaphore);
        sem_unlink(kSceneItSemaphoreName);
        gFrameSemaphore = NULL;
    }
    
    if (gSharedMemory && gSharedMemory != MAP_FAILED) {
        munmap(gSharedMemory, sizeof(SceneItSharedMemory));
        gSharedMemory = NULL;
    }
    
    if (gSharedMemoryFD != -1) {
        close(gSharedMemoryFD);
        shm_unlink(kSceneItSharedMemoryName);
        gSharedMemoryFD = -1;
    }
    
    return noErr;
}

CVPixelBufferRef SceneItVirtualCamera_GetNextFrame(void) {
    if (!gSharedMemory) {
        return NULL;
    }
    
    // Check if there are available frames
    if (gSharedMemory->frameCount == 0) {
        return NULL;
    }
    
    // Get frame from ring buffer
    uint32_t readIndex = gSharedMemory->readIndex;
    SceneItFrameMetadata* metadata = &gSharedMemory->frames[readIndex];
    
    if (!metadata->isValid) {
        return NULL;
    }
    
    // Create pixel buffer from shared memory data
    CVPixelBufferRef pixelBuffer = NULL;
    uint8_t* frameData = gSharedMemory->frameData[readIndex];
    
    CVPixelBufferCreateWithBytes(NULL, 
                                metadata->width, 
                                metadata->height, 
                                metadata->pixelFormat, 
                                frameData, 
                                metadata->bytesPerRow, 
                                NULL, NULL, NULL, 
                                &pixelBuffer);
    
    // Mark frame as consumed
    metadata->isValid = false;
    gSharedMemory->readIndex = (readIndex + 1) % kSceneItFrameRingBufferSize;
    __sync_fetch_and_sub(&gSharedMemory->frameCount, 1);
    
    return pixelBuffer;
}