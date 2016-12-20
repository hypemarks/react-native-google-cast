import {NativeModules} from 'react-native';

const {GoogleCast} = NativeModules;

export default {
  startScan: function (googleCastReceiverID:string) {
    GoogleCast.startScan(googleCastReceiverID);
  },
  startScanForVideoCast: function (googleCastReceiverID:string) {
    GoogleCast.startScanForVideoCast(googleCastReceiverID);
  },
  stopScan: function () {
    GoogleCast.stopScan();
  },
  isConnected: function () {
    return GoogleCast.isConnected();
  },
  getDevices: function () {
    return GoogleCast.getDevices();
  },
  connectToDevice: function (deviceId:string) {
    GoogleCast.connectToDevice(deviceId);
  },
  disconnect: function(){
    GoogleCast.disconnect();
  },
  castMedia: function (mediaUrl:string, title:string, imageUrl:string, seconds:number = 0, customData:object = {}) {
    GoogleCast.castMedia(mediaUrl, title, imageUrl, seconds, customData);
  },
  seekCast: function (seconds:number) {
    GoogleCast.seekCast(seconds);
  },
  togglePauseCast: function () {
    GoogleCast.togglePauseCast();
  },
  getStreamPosition: function (){
    return GoogleCast.getStreamPosition();
  },
  sendTextMessage: function (message:string) {
    GoogleCast.sendTextMessage(message);
  },
  DEVICE_CHANGED: GoogleCast.DEVICE_CHANGED,
  DEVICE_AVAILABLE: GoogleCast.DEVICE_AVAILABLE,
  DEVICE_CONNECTED: GoogleCast.DEVICE_CONNECTED,
  DEVICE_DISCONNECTED: GoogleCast.DEVICE_DISCONNECTED,
  MEDIA_LOADED: GoogleCast.MEDIA_LOADED,
  MESSAGE_RECEIVED: GoogleCast.MESSAGE_RECEIVED,
};
