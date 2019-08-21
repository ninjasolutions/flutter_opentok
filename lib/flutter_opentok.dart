import 'dart:async';
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

class OpenTokConfiguration {
  final String token, apiKey, sessionId;

  OpenTokConfiguration(this.token, this.apiKey, this.sessionId);
}
