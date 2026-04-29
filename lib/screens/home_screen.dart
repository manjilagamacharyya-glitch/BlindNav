import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/maps_service.dart';
import '../models/direction_step.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final FlutterTts _tts = FlutterTts();
  final MapsService _mapsService = MapsService();
  final Set<Marker> _markers = {};

  final stt.SpeechToText _speech = stt.SpeechToText();
  GoogleMapController? _mapController;
  User? _user;
  bool _loadingLandmarks = false;
  bool _scanning = false;
  bool _speechEnabled = false;
  bool _isListening = false;
  List<String> _landmarks = [];
  Position? _currentPosition;
  String _voiceCommand = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeServices();
    AuthService.authStateChanges().listen((user) {
      setState(() {
        _user = user;
      });
    });
    _tts.setLanguage('en-IN');
    _tts.setSpeechRate(0.5);
  }

  Future<void> _initializeServices() async {
    await _initSpeech();
    await _requestLocationPermission();
  }

  Future<void> _initializeCamera() async {
    CameraDescription? rearCamera;

    // 1. Try to explicitly find the back camera
    for (var camera in widget.cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        rearCamera = camera;
        break;
      }
    }

    // 2. Web browser fallback: If 'back' isn't labeled, but we have multiple cameras,
    // the second camera (index 1) is almost always the rear-facing phone camera.
    rearCamera ??= widget.cameras.length > 1
        ? widget.cameras[1]
        : widget.cameras.first;

    _controller = CameraController(rearCamera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller!.initialize();
    setState(() {});
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        setState(() {
          _isListening = false;
        });
      },
    );
    if (!_speechEnabled) {
      await _tts.speak('Voice commands are not available right now.');
    }
  }

  Future<void> _requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _tts.speak('Please enable location services on your phone.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      await _tts.speak(
        'Location permission is required to show your current position.',
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _updateCurrentLocation(position);
  }

  void _updateCurrentLocation(Position position) {
    setState(() {
      _currentPosition = position;
      _markers.removeWhere((marker) => marker.markerId.value == 'current');
      _markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
      );
    });
    _moveCamera(position);
  }

  Future<void> _signIn() async {
    await AuthService.signInAnonymously();
    await _tts.speak('Signed in anonymously.');
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    await _tts.speak('Signed out.');
  }

  Future<void> _loadLandmarks() async {
    if (_currentPosition == null) {
      await _tts.speak('Current location is not available yet. Please wait.');
      return;
    }

    setState(() {
      _loadingLandmarks = true;
      _landmarks = [];
    });

    final landmarks = await _mapsService.nearbyLandmarks(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    setState(() {
      _landmarks = landmarks;
      _loadingLandmarks = false;
    });

    await _tts.speak(
      landmarks.isEmpty
          ? 'No nearby landmarks were found.'
          : 'Loaded ${landmarks.length} nearby landmarks.',
    );
  }

  Future<void> _startSafetyScan() async {
    if (_scanning) return;

    setState(() {
      _scanning = true;
    });

    await _tts.speak('Starting safety scan. Please hold your phone still.');
    await Future.delayed(const Duration(seconds: 3));
    await _tts.speak('Warning. Vehicle approaching in five meters ahead.');
    await Future.delayed(const Duration(seconds: 5));
    await _tts.speak('Caution. Uneven path ahead in forty meters.');

    setState(() => _scanning = false);
  }

  Future<void> _listenForVoiceCommand() async {
    if (!_speechEnabled) {
      await _tts.speak('Voice commands are not available right now.');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      await _tts.speak('Voice command cancelled.');
      return;
    }

    setState(() {
      _isListening = true;
      _voiceCommand = '';
    });

    await _tts.speak(
      'Listening for a command. Say take me to followed by place name, load nearby landmarks, or start safety scan.',
    );

    _speech.listen(
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        final recognizedWords = result.recognizedWords;
        setState(() {
          _voiceCommand = recognizedWords;
        });
        if (result.finalResult && recognizedWords.isNotEmpty) {
          setState(() => _isListening = false);
          _handleVoiceCommand(recognizedWords);
        }
      },
    );
  }

  Future<void> _handleVoiceCommand(String command) async {
    final text = command.toLowerCase();

    if (text.contains('take me to') ||
        text.contains('go to') ||
        text.contains('navigate to')) {
      final place = text.replaceAll(
        RegExp(r'.*(take me to|go to|navigate to)\s*'),
        '',
      );
      if (place.trim().isEmpty) {
        await _tts.speak('Please say a place name after take me to.');
        return;
      }
      if (_currentPosition == null) {
        await _tts.speak('Current location is not available yet.');
        return;
      }
      await _tts.speak('Searching for $place near you.');
      final result = await _mapsService.searchPlace(
        place,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (result == null) {
        await _tts.speak('I could not find $place nearby.');
        return;
      }
      setState(() {
        _markers.removeWhere(
          (marker) => marker.markerId.value == 'voice_target',
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('voice_target'),
            position: result.location,
            infoWindow: InfoWindow(title: result.name),
          ),
        );
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(result.location, 16),
      );
      await _tts.speak('Found ${result.name}. Getting directions.');
      final directions = await _mapsService.getDirections(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        result.location.latitude,
        result.location.longitude,
      );
      if (directions.isEmpty) {
        await _tts.speak('Could not get directions to ${result.name}.');
        return;
      }
      await _tts.speak('Directions to ${result.name}:');
      for (final step in directions.take(5)) {
        final speakableStep = '${step.instruction}, for ${step.distance}.';
        await _tts.speak(speakableStep);
        await Future.delayed(const Duration(seconds: 2));
      }
      if (directions.length > 5) {
        await _tts.speak('And ${directions.length - 5} more steps.');
      }
    } else if (text.contains('landmarks')) {
      await _loadLandmarks();
    } else if (text.contains('safety scan')) {
      await _startSafetyScan();
    } else {
      await _tts.speak(
        'I heard $command. Say take me to a place, load nearby landmarks, or start safety scan.',
      );
    }
  }

  void _moveCamera(Position position) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        16,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition = _currentPosition != null
        ? CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 16,
          )
        : _mapsService.initialCameraPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlindNav'),
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            onPressed: _listenForVoiceCommand,
            tooltip: 'Voice command',
          ),
          if (_user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: 'Sign out',
            )
          else
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _signIn,
              tooltip: 'Sign in',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _initializeControllerFuture == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return CameraPreview(_controller!);
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
          ),
          SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: initialPosition,
              markers: _markers,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_currentPosition != null) {
                  _moveCamera(_currentPosition!);
                }
              },
              zoomControlsEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              border: Border(
                top: BorderSide(color: const Color.fromRGBO(255, 235, 59, 0.4)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user != null
                      ? 'Signed in as ${_user!.uid.substring(0, 8)}'
                      : 'Not signed in',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                if (_isListening || _voiceCommand.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _isListening
                          ? 'Hearing: $_voiceCommand'
                          : 'Command: $_voiceCommand',
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadingLandmarks ? null : _loadLandmarks,
                        icon: const Icon(Icons.place),
                        label: const Text('Load nearby landmarks'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingLandmarks)
                  const Text(
                    'Loading landmarks...',
                    style: TextStyle(color: Colors.white70),
                  )
                else if (_landmarks.isEmpty)
                  const Text(
                    'No landmarks loaded yet.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _landmarks
                        .take(3)
                        .map(
                          (name) => Text(
                            '• $name',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startSafetyScan,
        icon: const Icon(Icons.radar),
        label: Text(_scanning ? 'Scanning…' : 'Start safety scan'),
      ),
    );
  }
}
