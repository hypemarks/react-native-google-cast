#import "RNGoogleCast.h"
#import "RCTLog.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"

static NSString *const DEVICE_CHANGED = @"GoogleCast:DeviceListChanged";
static NSString *const DEVICE_AVAILABLE = @"GoogleCast:DeviceAvailable";
static NSString *const DEVICE_CONNECTED = @"GoogleCast:DeviceConnected";
static NSString *const DEVICE_DISCONNECTED = @"GoogleCast:DeviceDisconnected";
static NSString *const MEDIA_LOADED = @"GoogleCast:MediaLoaded";


@implementation GoogleCast
@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (NSDictionary *)constantsToExport
{
  return @{
           @"DEVICE_CHANGED": DEVICE_CHANGED,
           @"DEVICE_AVAILABLE": DEVICE_AVAILABLE,
           @"DEVICE_CONNECTED": DEVICE_CONNECTED,
           @"DEVICE_DISCONNECTED": DEVICE_DISCONNECTED,
           @"MEDIA_LOADED": MEDIA_LOADED,
           };
}


RCT_EXPORT_METHOD(startScan
                    :(NSString *) receiverID)
{
  RCTLogInfo(@"start scan chromecast!");
  RCTLogInfo(@"%@", receiverID);

  self.currentDevices = [[NSMutableDictionary alloc] init];
  self.receiverID = receiverID;

  // Initialize device scanner.
  dispatch_async(dispatch_get_main_queue(), ^{
    GCKFilterCriteria *filterCriteria =
    [GCKFilterCriteria criteriaForAvailableApplicationWithID: receiverID];
    self.deviceScanner = [[GCKDeviceScanner alloc] initWithFilterCriteria:filterCriteria];
    [_deviceScanner addListener:self];
    [_deviceScanner startScan];
    [_deviceScanner setPassiveScan:YES];

  });
}

RCT_EXPORT_METHOD(stopScan)
{
  RCTLogInfo(@"stop chromecast!");
  dispatch_async(dispatch_get_main_queue(), ^{
    [_deviceScanner removeListener:self];
  });
}

RCT_REMAP_METHOD(isConnected,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

{
  BOOL isConnected = self.deviceManager.connectionState == GCKConnectionStateConnected;
  RCTLogInfo(@"is connected? %d", isConnected);
  resolve(@(isConnected));

}

RCT_EXPORT_METHOD(connectToDevice:(NSString *)deviceId)
{
  RCTLogInfo(@"connecting to device %@", deviceId);
  GCKDevice *selectedDevice = self.currentDevices[deviceId];
  dispatch_async(dispatch_get_main_queue(), ^{
    self.deviceManager = [[GCKDeviceManager alloc] initWithDevice:selectedDevice
                                                clientPackageName:[NSBundle mainBundle].bundleIdentifier];
    self.deviceManager.delegate = self;
    [_deviceManager connect];
  });
}

RCT_EXPORT_METHOD(disconnect)
{
  if(_deviceManager == nil) return;

  RCTLogInfo(@"disconnecting from app: %@", self.receiverID);

  dispatch_async(dispatch_get_main_queue(), ^{
    [_deviceManager disconnectWithLeave: NO];
  });
}

RCT_EXPORT_METHOD(castMedia
                  :(NSString *) mediaUrl
                  :(NSString *) title
                  :(NSString *) imageUrl
                  :(double) seconds
                  :(id) customData)
{
  RCTLogInfo(@"casting media");
  seconds = !seconds ? 0 : seconds;

  GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];

  [metadata setString:title forKey:kGCKMetadataKeyTitle];

  [metadata addImage:[[GCKImage alloc]
                      initWithURL:[[NSURL alloc] initWithString: imageUrl]
                      width:480
                      height:360]];

  GCKMediaInformation *mediaInformation =
  [[GCKMediaInformation alloc] initWithContentID: mediaUrl
                                      streamType: GCKMediaStreamTypeNone
                                     contentType: @"video/mp4"
                                        metadata: metadata
                                  streamDuration: 0
                                      customData: customData];

  // Cast the video.
  [self.mediaControlChannel loadMedia:mediaInformation autoplay:YES playPosition: seconds];
}

RCT_EXPORT_METHOD(sendTextMessage :(NSString *) message)
{
  RCTLogInfo(@"sendTextMessage %@", message);

  dispatch_async(dispatch_get_main_queue(), ^{
    GCKError *messageSentError;
    BOOL messageSent = [self.castChannel sendTextMessage: message
                        error: &messageSentError];

    if (!messageSent) {
      RCTLogInfo(@"%@", messageSentError);
    }
  });
}

RCT_EXPORT_METHOD(togglePauseCast)
{
  BOOL isPlaying = self.mediaControlChannel.mediaStatus.playerState == GCKMediaPlayerStatePlaying;
  isPlaying ? [self.mediaControlChannel pause] : [self.mediaControlChannel play];
}

RCT_EXPORT_METHOD(seekCast:(double) seconds){
  [self.mediaControlChannel seekToTimeInterval: seconds];
}

RCT_REMAP_METHOD(getDevices,
                 resolver:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)
{
  NSMutableArray *devicesList = [[NSMutableArray alloc] init];
  NSMutableDictionary *singleDevice;
  for (NSString *key in [self.currentDevices allKeys]) {
    GCKDevice *device = self.currentDevices[key];
    singleDevice = [[NSMutableDictionary alloc] init];
    singleDevice[@"id"] = key;
    singleDevice[@"name"] = device.friendlyName;
    [devicesList addObject:singleDevice];
  }
  resolve(devicesList);
}

RCT_REMAP_METHOD(getStreamPosition,
                 resolved:(RCTPromiseResolveBlock)resolve
                 rejected:(RCTPromiseRejectBlock)reject)
{
  double time = [self.mediaControlChannel approximateStreamPosition];
  resolve(@(time));
}

#pragma mark - GCKDeviceScannerListener
- (void)deviceDidComeOnline:(GCKDevice *)device {
  NSLog(@"device found!! %@", device.friendlyName);
  [self emitMessageToRN:DEVICE_AVAILABLE
                       :@{@"device_available": @YES}];
  [self addDevice: device];
}

- (void)deviceDidGoOffline:(GCKDevice *)device {
  NSLog(@"device death !! %@", device.friendlyName);
  [self removeDevice: device];
  if([self.currentDevices count] == 0) {
    [self emitMessageToRN:DEVICE_AVAILABLE
                         :@{@"device_available": @NO}];
  }
}

#pragma mark - GCKDeviceManagerDelegate

- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {
  // Launch application after getting connected.
  RCTLogInfo(@"Custom Receiver ID: %@", self.receiverID);
  [_deviceManager launchApplication: self.receiverID];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didDisconnectWithError:(NSError *)error {
    [self emitMessageToRN:DEVICE_DISCONNECTED
                         :nil];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didConnectToCastApplication
                     :(GCKApplicationMetadata *)applicationMetadata
            sessionID:(NSString *)sessionID
  launchedApplication:(BOOL)launchedApplication {
    RCTLogInfo(@"didConnectToCastApplication");

    self.castChannel = [[GCKCastChannel alloc] initWithNamespace: @"urn:x-cast:com.google.cast.sample.helloworld"];
    [_deviceManager addChannel:self.castChannel];

    // self.mediaControlChannel = [[GCKMediaControlChannel alloc] init];
    // self.mediaControlChannel.delegate = self;
    // [_deviceManager addChannel:self.mediaControlChannel];

  //send message to react native
  [self emitMessageToRN:DEVICE_CONNECTED
                       :nil];
}

- (void) mediaControlChannel:(GCKMediaControlChannel *)mediaControlChannel didCompleteLoadWithSessionID:(NSInteger)sessionID {
  [self emitMessageToRN:MEDIA_LOADED
                       :nil];
}


#pragma mark - Private methods

- (void) addDevice: (GCKDevice *)device {
  self.currentDevices[device.deviceID] = device;
}

- (void) removeDevice: (GCKDevice *)device {
  [self.currentDevices removeObjectForKey:device.deviceID];
}

- (void) emitMessageToRN: (NSString *)eventName
                        :(NSDictionary *)params{
  [self.bridge.eventDispatcher sendAppEventWithName: eventName
                                               body: params];
}
@end
