import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlutterOpenTok {
  static const MethodChannel _channel = const MethodChannel('flutter_opentok');

  /// Occurs when the SDK cannot reconnect to server 10 seconds after its connection to the server is interrupted.
  ///
  /// The SDK triggers this callback when it cannot connect to the server 10 seconds after calling [joinChannel], regardless of whether it is in the channel or not.
  static VoidCallback onConnectionLost;

  // Core Methods
  /// Creates an OpenTok instance.
  ///
  /// The OpenTok SDK only supports one instance at a time, therefore the app should create one object only.
  /// Only users with the same api key, session id and token can join the same channel and call each other.
  static Future<void> create(OpenTokConfiguration configuration) async {
    _addMethodCallHandler();
    return await _channel.invokeMethod('create', {
      'apiKey': configuration.apiKey,
      'sessionId': configuration.sessionId,
      'token': configuration.token,
    });
  }

  /// Destroys the instance and releases all resources used by the OpenTok SDK.
  ///
  /// This method is useful for apps that occasionally make voice or video calls, to free up resources for other operations when not making calls.
  /// Once the app calls destroy to destroy the created instance, you cannot use any method or callback in the SDK.
  static Future<void> destroy() async {
    _removeMethodCallHandler();
    return await _channel.invokeMethod('destroy');
  }

  /// Creates the video renderer Widget.
  ///
  static Widget createNativeView(int uid, Function(int viewId) created) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: new ObjectKey(uid.toString()),
        viewType: 'OpenTokRendererView',
        onPlatformViewCreated: (viewId) {
          if (created != null) {
            created(viewId);
          }
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: new ObjectKey(uid.toString()),
        viewType: 'OpenTokRendererView',
        onPlatformViewCreated: (viewId) {
          if (created != null) {
            created(viewId);
          }
        },
      );
    }

    return Text('$defaultTargetPlatform is not yet supported by this plugin');
  }

  // CallHandler
  static void _addMethodCallHandler() {
    _channel.setMethodCallHandler((MethodCall call) {
      Map values = call.arguments;

      switch (call.method) {
        case 'onConnectionLost':
          if (onConnectionLost != null) {
            onConnectionLost();
          }
          break;
        default:
      }

      return;
    });
  }

  static void _removeMethodCallHandler() {
    _channel.setMethodCallHandler(null);
  }

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}

const int OpenTokVideoBitrateStandard = 0;
const int OpenTokVideoBitrateCompatible = -1;

class OpenTokConfiguration {
  final String token, apiKey, sessionId;

  OpenTokConfiguration(this.token, this.apiKey, this.sessionId);
}

/// Properties of the video encoder configuration.
class VideoEncoderConfiguration {
  /// The video frame dimension used to specify the video quality in the total number of pixels along a frame's width and height.
  ///
  /// The dimension does not specify the orientation mode of the output ratio. For how to set the video orientation, see [VideoOutputOrientationMode].
  /// Whether 720p can be supported depends on the device. If the device cannot support 720p, the frame rate will be lower than the one listed in the table.
  Size dimensions = Size(640, 360);

  /// The frame rate of the video (fps).
  ///
  /// We do not recommend setting this to a value greater than 30.
  int frameRate = 15;

  /// The minimum video encoder frame rate (fps).
  ///
  /// The default value (-1) means the SDK uses the lowest encoder frame rate.
  int minFrameRate = -1;

  /// The bitrate of the video.
  ///
  /// Sets the video bitrate (Kbps). If you set a bitrate beyond the proper range, the SDK automatically adjusts it to a value within the range. You can also choose from the following options:
  ///  - Standard: (recommended) In this mode, the bitrates differ between the Live-broadcast and Communication profiles:
  ///   - Communication profile: the video bitrate is the same as the base bitrate.
  ///   - Live-broadcast profile: the video bitrate is twice the base bitrate.
  ///  - Compatible: In this mode, the bitrate stays the same regardless of the profile. In the Live-broadcast profile, if you choose this mode, the video frame rate may be lower than the set value.
  /// It uses different video codecs for different profiles to optimize the user experience. For example, the Communication profile prioritizes the smoothness while the Live-broadcast profile prioritizes the video quality (a higher bitrate).
  /// Therefore, OpenTok recommends setting this parameter as OpenTokVideoBitrateStandard.
  int bitrate = OpenTokVideoBitrateStandard;

  /// The minimum encoding bitrate.
  ///
  /// The SDK automatically adjusts the encoding bitrate to adapt to network conditions.
  /// Using a value greater than the default value forces the video encoder to output high-quality images but may cause more packet loss and hence sacrifice the smoothness of the video transmission.
  /// Unless you have special requirements for image quality, OpenTok does not recommend changing this value.
  int minBitrate = -1;

  /// The video orientation mode of the video.
  VideoOutputOrientationMode orientationMode =
      VideoOutputOrientationMode.Adaptative;

  Map<String, dynamic> _jsonMap() {
    return {
      'width': dimensions.width.toInt(),
      'height': dimensions.height.toInt(),
      'frameRate': frameRate,
      'minFrameRate': minFrameRate,
      'bitrate': bitrate,
      'minBitrate': minBitrate,
      'orientationMode': orientationMode.index,
    };
  }
}

enum VideoOutputOrientationMode {
  /// Adaptive mode.
  ///
  /// The video encoder adapts to the orientation mode of the video input device. When you use a custom video source, the output video from the encoder inherits the orientation of the original video.
  /// If the width of the captured video from the SDK is greater than the height, the encoder sends the video in landscape mode. The encoder also sends the rotational information of the video, and the receiver uses the rotational information to rotate the received video.
  /// If the original video is in portrait mode, the output video from the encoder is also in portrait mode. The encoder also sends the rotational information of the video to the receiver.
  Adaptative,

  /// Landscape mode.
  ///
  /// The video encoder always sends the video in landscape mode. The video encoder rotates the original video before sending it and the rotational information is 0. This mode applies to scenarios involving CDN live streaming.
  FixedLandscape,

  /// Portrait mode.
  ///
  /// The video encoder always sends the video in portrait mode. The video encoder rotates the original video before sending it and the rotational information is 0. This mode applies to scenarios involving CDN live streaming.
  FixedPortrait,
}
