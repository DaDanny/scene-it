//
//  SceneItVirtualCamera.h
//  Scene It Virtual Camera Plugin
//
//  CoreMediaIO DAL Plugin Interface
//

#ifndef SceneItVirtualCamera_h
#define SceneItVirtualCamera_h

#include <CoreMediaIO/CMIOHardwarePlugin.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreVideo/CoreVideo.h>
#include <mach/mach.h>

#ifdef __cplusplus
extern "C" {
#endif

// Plugin identification
#define kSceneItVirtualCameraPlugInUUID CFUUIDGetConstantUUIDWithBytes(NULL, 0x9F, 0x34, 0xE4, 0x67, 0x8B, 0x95, 0x4F, 0x87, 0xB8, 0x4A, 0x3F, 0x5E, 0x3C, 0x5B, 0x8A, 0x9C)

// Device identification
#define kSceneItVirtualCameraDeviceUUID CFUUIDGetConstantUUIDWithBytes(NULL, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88)

// Stream identification
#define kSceneItVirtualCameraStreamUUID CFUUIDGetConstantUUIDWithBytes(NULL, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0x00)

// IPC Communication Constants
#define kSceneItSharedMemoryName "com.sceneit.virtualcamera.sharedmem"
#define kSceneItSemaphoreName "com.sceneit.virtualcamera.semaphore"
#define kSceneItMaxFrameSize (1920 * 1080 * 4) // RGBA32
#define kSceneItFrameRingBufferSize 8

// Frame metadata structure
typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t bytesPerRow;
    uint32_t pixelFormat; // kCVPixelFormatType_32BGRA
    uint64_t timestamp;
    uint32_t frameIndex;
    bool isValid;
} SceneItFrameMetadata;

// Shared memory ring buffer structure
typedef struct {
    volatile uint32_t writeIndex;
    volatile uint32_t readIndex;
    volatile uint32_t frameCount;
    SceneItFrameMetadata frames[kSceneItFrameRingBufferSize];
    uint8_t frameData[kSceneItFrameRingBufferSize][kSceneItMaxFrameSize];
} SceneItSharedMemory;

// Plugin entry points
OSStatus SceneItVirtualCamera_Initialize(CFUUIDRef requestedTypeUUID);
OSStatus SceneItVirtualCamera_InitializeWithObjectID(CMIOHardwarePlugInRef* outPlugIn, CMIOObjectID inObjectID);
OSStatus SceneItVirtualCamera_Teardown(void);

// Factory function
void* SceneItVirtualCameraPlugInFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID);

// Device management
OSStatus SceneItVirtualCamera_CreateDevice(CMIOObjectID* outDeviceID);
OSStatus SceneItVirtualCamera_DestroyDevice(CMIOObjectID deviceID);

// Stream management  
OSStatus SceneItVirtualCamera_CreateStream(CMIOObjectID deviceID, CMIOObjectID* outStreamID);
OSStatus SceneItVirtualCamera_DestroyStream(CMIOObjectID streamID);

// Frame processing
OSStatus SceneItVirtualCamera_StartStreaming(CMIOObjectID streamID);
OSStatus SceneItVirtualCamera_StopStreaming(CMIOObjectID streamID);

// IPC functions
OSStatus SceneItVirtualCamera_InitializeIPC(void);
OSStatus SceneItVirtualCamera_CleanupIPC(void);
CVPixelBufferRef SceneItVirtualCamera_GetNextFrame(void);

#ifdef __cplusplus
}
#endif

#endif /* SceneItVirtualCamera_h */