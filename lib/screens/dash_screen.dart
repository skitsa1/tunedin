import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animarker/widgets/animarker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../markergen.dart';

class DashScreen extends StatefulWidget {
  const DashScreen({this.unit = 'm/s', Key? key}) : super(key: key);

  final String unit;

  @override
  // ignore: library_private_types_in_public_api
  _DashScreenState createState() => _DashScreenState();
}

class _DashScreenState extends State<DashScreen> {
  // For text to speed naration of current velocity

  /// Create a stream trying to speak speed
  StreamSubscription? _ttsCallback;

  /// String that the tts will read aloud, Speed + Expanded Unit
  String get speakText {
    String unit;
    switch (widget.unit) {
      case 'km/h':
        unit = 'kilometers per hour';
        break;

      case 'miles/h':
        unit = 'miles per hour';
        break;

      case 'm/s':
      default:
        unit = 'meters per second';
        break;
    }
    return '${convertedVelocity(_velocity)!.toStringAsFixed(2)} $unit';
  }

  /// Utility function to deserialize saved Duration

  // For velocity Tracking
  /// Geolocator is used to find velocity
  GeolocatorPlatform locator = GeolocatorPlatform.instance;

  /// Stream that emits values when velocity updates
  late StreamController<double?> _velocityUpdatedStreamController;

  /// Current Velocity in m/s
  double? _velocity;

  /// Highest recorded velocity so far in m/s.
  double? _highestVelocity;

  double? _longitude;
  double? _latitude;
  var _markers = <Marker>{};

  /// Velocity in m/s to km/hr converter
  double mpstokmph(double mps) => mps * 18 / 5;

  /// Velocity in m/s to miles per hour converter
  double mpstomilesph(double mps) => mps * 85 / 38;

  /// Relevant velocity in chosen unit
  double? convertedVelocity(double? velocity) {
    velocity = velocity ?? _velocity;

    if (widget.unit == 'm/s') {
      return velocity;
    } else if (widget.unit == 'km/h') {
      return mpstokmph(velocity!);
    } else if (widget.unit == 'miles/h') {
      return mpstomilesph(velocity!);
    }
    return velocity;
  }

  @override
  void initState() {
    super.initState();
    // Speedometer functionality. Updates any time velocity chages.
    _velocityUpdatedStreamController = StreamController<double?>();
    locator
        .getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    )
        .listen(
      (Position position) {
        _onAccelerate(position.speed);
        _onLocationChane(position.latitude, position.longitude);
        _loadMarker(position.speed);
      },
    );

    // Set velocities to zero when app opens
    _velocity = 0;
    _highestVelocity = 0.0;

    _longitude = 0;
    _latitude = 0;
    _markers = <Marker>{};
  }

  /// Callback that runs when velocity updates, which in turn updates stream.
  void _onAccelerate(double speed) {
    locator.getCurrentPosition().then(
      (Position updatedPosition) {
        _velocity = updatedPosition.speed;
        if (_velocity! > _highestVelocity!) _highestVelocity = _velocity;
        _velocityUpdatedStreamController.add(_velocity!);
      },
    );
  }

  void _onLocationChane(double latitude, double longitude) {
    locator.getCurrentPosition().then(
      (Position updatedPosition) {
        _longitude = longitude;
        _latitude = latitude;
      },
    );
  }

  void _loadMarker(double speed) async {
    _markers = {
      Marker(
        infoWindow: InfoWindow(
          onTap: () {
            markerOnTap();
          },
        ),
        consumeTapEvents: true,
        markerId: const MarkerId('source'),
        position: LatLng(_latitude!, _longitude!),
        icon: await getMarkerIcon(
          "images/users.png",
          const Size(150.0, 150.0),
          convertedVelocity(speed)?.round(),
        ),
      ),
    };
  }

  markerOnTap() {
    setState(() {
      following = !following;
    });
  }

  bool following = false;
  bool test = true;
  final GlobalKey globalKey = GlobalKey();

  final controller = Completer<GoogleMapController>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object?>(
      stream: _velocityUpdatedStreamController.stream,
      builder: (context, snapshot) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              convertedVelocity(_velocity).toString(),
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              convertedVelocity(_highestVelocity).toString(),
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              _latitude.toString(),
              style: const TextStyle(color: Colors.white),
            ),
            Expanded(
                child: Animarker(
              shouldAnimateCamera: following,
              isActiveTrip: true,
              duration: const Duration(milliseconds: 2000),
              useRotation: false,
              mapId: controller.future
                  .then<int>((value) => value.mapId), //Grab Google Map Id
              // ignore: unrelated_type_equality_checks
              markers: _markers == {}
                  ? {
                      Marker(
                        consumeTapEvents: true,
                        markerId: const MarkerId('source1'),
                        position: LatLng(_latitude!, _longitude!),
                      )
                    }
                  : _markers,

              child: GoogleMap(
                initialCameraPosition:
                    const CameraPosition(target: LatLng(100, 100), zoom: 1.5),
                onMapCreated: (gController) => controller.complete(gController),
              ),
            ))
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Velocity Stream
    _velocityUpdatedStreamController.close();
    // TTS
    _ttsCallback!.cancel();

    super.dispose();
  }
}
