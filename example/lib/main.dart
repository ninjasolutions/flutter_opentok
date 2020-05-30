import 'package:flutter/material.dart';
import 'package:flutter_opentok/flutter_opentok.dart';
import 'package:flutter_opentok_example/video_session.dart';
import 'package:flutter_opentok_example/settings.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final _sessions = List<VideoSession>();
  final _infoStrings = <String>[];
  bool muted = false;
  bool publishVideo = true;
  OTFlutter controller;
  OpenTokConfiguration openTokConfiguration;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    _sessions.clear();

    super.dispose();
  }

  void initialize() {
    if (API_KEY.isEmpty) {
      setState(() {
        _infoStrings.add(
            "APP_ID missing, please provide your API_KEY in settings.dart");
        _infoStrings.add("OpenTok is not starting");
      });
      return;
    }

    if (SESSION_ID.isEmpty) {
      setState(() {
        _infoStrings.add(
            "SESSION_ID missing, please provide your SESSION_ID in settings.dart");
        _infoStrings.add("OpenTok is not starting");
      });
      return;
    }

    if (TOKEN.isEmpty) {
      setState(() {
        _infoStrings
            .add("TOKEN missing, please provide your TOKEN in settings.dart");
        _infoStrings.add("OpenTok is not starting");
      });
      return;
    }

    openTokConfiguration = OpenTokConfiguration(
        token: TOKEN, apiKey: API_KEY, sessionId: SESSION_ID);

    _addRenderView(0, (viewId) {
      print(viewId);
    });
  }

  // Toolbar layout
  Widget _toolbar() {
    return Container(
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RawMaterialButton(
              onPressed: () => _togglePublisherVideo(),
              child: Icon(
                publishVideo ? Icons.videocam : Icons.videocam_off,
                color: publishVideo ? Colors.white : Colors.blueAccent,
                size: 20.0,
              ),
              shape: CircleBorder(),
              elevation: 2.0,
              fillColor: muted ? Colors.blueAccent : Colors.white,
              padding: const EdgeInsets.all(12.0),
            ),
            RawMaterialButton(
              onPressed: () => _onToggleMute(),
              child: Icon(
                muted ? Icons.mic : Icons.mic_off,
                color: muted ? Colors.white : Colors.blueAccent,
                size: 20.0,
              ),
              shape: CircleBorder(),
              elevation: 2.0,
              fillColor: muted ? Colors.blueAccent : Colors.white,
              padding: const EdgeInsets.all(12.0),
            ),
            RawMaterialButton(
              onPressed: () => _onSwitchCamera(),
              child: Icon(
                Icons.switch_camera,
                color: Colors.blueAccent,
                size: 20.0,
              ),
              shape: CircleBorder(),
              elevation: 2.0,
              fillColor: Colors.white,
              padding: const EdgeInsets.all(12.0),
            )
          ],
        ));
  }

  /// Helper function to get list of native views
  List<Widget> _getRenderViews() {
    return _sessions.map((session) => session.view).toList();
  }

  Widget _viewRows() {
    List<Widget> views = _getRenderViews();
    if (views.isNotEmpty) {
      return Container (
        child: Expanded(child: views[0]),
      );
    }

    return Container();
  }

  /// Info panel to show logs
  Widget _panel() {
    return Container(
        padding: EdgeInsets.symmetric(vertical: 48),
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.5,
          child: Container(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: ListView.builder(
                  reverse: true,
                  itemCount: _infoStrings.length,
                  itemBuilder: (BuildContext context, int index) {
                    if (_infoStrings.length == 0) {
                      return null;
                    }
                    return Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                              child: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 2, horizontal: 5),
                                  decoration: BoxDecoration(
                                      color: Colors.yellowAccent,
                                      borderRadius: BorderRadius.circular(5)),
                                  child: Text(_infoStrings[index],
                                      style:
                                          TextStyle(color: Colors.blueGrey))))
                        ]));
                  })),
        ));
  }

  /// Create a native view and add a new video session object
  void _addRenderView(int uid, Function(int viewId) finished) {
    OTFlutter.onSessionConnect = () {
      print("onSessionConnect");
    };

    OTFlutter.onSessionDisconnect = () {
      print("onSessionDisconnect");
    };

    var publisherSettings = OTPublisherKitSettings(
      name: "Mr. John Doe",
      audioTrack: true,
      videoTrack: publishVideo,
      audioBitrate: 40000,
      cameraResolution: OTCameraCaptureResolution.OTCameraCaptureResolutionHigh,
      cameraFrameRate: OTCameraCaptureFrameRate.OTCameraCaptureFrameRate30FPS,
    );
    Widget view = OTFlutter.createNativeView(uid,
        publisherSettings: publisherSettings, created: (viewId) async {
      controller = await OTFlutter.init(viewId);

      await controller.create(openTokConfiguration);
    });

    VideoSession session = VideoSession(uid, view);
    _sessions.add(session);
  }

  void _togglePublisherVideo() async {
    if (publishVideo) {
      await controller?.disablePublisherVideo();
    } else {
      await controller?.enablePublisherVideo();
    }

    setState(() {
      publishVideo = !publishVideo;
    });
  }

  void _onToggleMute() async {
    if (muted) {
      await controller?.unmutePublisherAudio();
    } else {
      await controller?.mutePublisherAudio();
    }

    setState(() {
      muted = !muted;
    });
  }

  void _onSwitchCamera() async {
    await controller?.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('OpenTok SDK'),
          ),
          backgroundColor: Colors.black,
          body: Center(
              child: Stack(
            children: <Widget>[_viewRows(), _panel(), _toolbar()],
          ))),
    );
  }
}
