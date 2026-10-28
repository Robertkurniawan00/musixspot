import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_bridge.dart';

enum BluetoothDeviceType {
  earphones,
  headphones,
  speaker,
  carAudio,
  phoneSpeaker,
}

class BluetoothAudioDevice {
  final String id;
  final String name;
  final BluetoothDeviceType type;
  final int? batteryLevel;
  final bool isPaired;
  final bool isConnected;

  const BluetoothAudioDevice({
    required this.id,
    required this.name,
    required this.type,
    this.batteryLevel,
    this.isPaired = true,
    this.isConnected = false,
  });

  BluetoothAudioDevice copyWith({
    String? id,
    String? name,
    BluetoothDeviceType? type,
    int? batteryLevel,
    bool? isPaired,
    bool? isConnected,
  }) {
    return BluetoothAudioDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isPaired: isPaired ?? this.isPaired,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class BluetoothAudioService {
  static const String _prefConnectedKey = 'bt_connected_device_id';
  static final StreamController<BluetoothAudioDevice?> _deviceStreamController =
      StreamController<BluetoothAudioDevice?>.broadcast();

  static Stream<BluetoothAudioDevice?> get deviceStream => _deviceStreamController.stream;

  static BluetoothAudioDevice? _currentDevice;
  static BluetoothAudioDevice? get currentDevice => _currentDevice;

  static bool _isBluetoothEnabled = true;
  static bool get isBluetoothEnabled => _isBluetoothEnabled;

  static bool _isScanning = false;
  static bool get isScanning => _isScanning;

  /// Open Android OS native Bluetooth settings
  static Future<bool> openNativeSettings() => NativeBridge.openBluetoothSettings();

  // Curated list of paired & discoverable realistic Bluetooth audio devices
  static final List<BluetoothAudioDevice> _knownDevices = [
    const BluetoothAudioDevice(
      id: 'bt_sony_wh1000xm5',
      name: 'Sony WH-1000XM5',
      type: BluetoothDeviceType.headphones,
      batteryLevel: 92,
      isPaired: true,
      isConnected: false,
    ),
    const BluetoothAudioDevice(
      id: 'bt_airpods_pro',
      name: 'AirPods Pro (2nd Gen)',
      type: BluetoothDeviceType.earphones,
      batteryLevel: 85,
      isPaired: true,
      isConnected: false,
    ),
    const BluetoothAudioDevice(
      id: 'bt_jbl_flip6',
      name: 'JBL Flip 6',
      type: BluetoothDeviceType.speaker,
      batteryLevel: 70,
      isPaired: true,
      isConnected: false,
    ),
    const BluetoothAudioDevice(
      id: 'bt_galaxy_buds2',
      name: 'Galaxy Buds2 Pro',
      type: BluetoothDeviceType.earphones,
      batteryLevel: 80,
      isPaired: true,
      isConnected: false,
    ),
    const BluetoothAudioDevice(
      id: 'bt_car_audio',
      name: 'Audio Bluetooth Mobil',
      type: BluetoothDeviceType.carAudio,
      isPaired: true,
      isConnected: false,
    ),
  ];

  static List<BluetoothAudioDevice> _scannedDevices = [];

  static List<BluetoothAudioDevice> get pairedDevices =>
      _knownDevices.where((d) => d.isPaired).toList();

  static List<BluetoothAudioDevice> get scannedDevices => _scannedDevices;

  /// Initialize and load saved Bluetooth connection
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefConnectedKey);
      if (savedId != null && savedId.isNotEmpty && savedId != 'phone_speaker') {
        final match = _knownDevices.firstWhere(
          (d) => d.id == savedId,
          orElse: () => _knownDevices.first,
        );
        _currentDevice = match.copyWith(isConnected: true);
        _deviceStreamController.add(_currentDevice);
      }
    } catch (e) {
      debugPrint('BluetoothAudioService.init error: $e');
    }
  }

  /// Toggle Bluetooth Power
  static void setBluetoothEnabled(bool enabled) {
    _isBluetoothEnabled = enabled;
    if (!enabled && _currentDevice != null) {
      disconnect();
    }
  }

  /// Connect to a Bluetooth audio device
  static Future<bool> connect(BluetoothAudioDevice device) async {
    if (!_isBluetoothEnabled) return false;

    // Simulate connecting delay
    await Future.delayed(const Duration(milliseconds: 600));

    _currentDevice = device.copyWith(isConnected: true);
    _deviceStreamController.add(_currentDevice);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefConnectedKey, device.id);
    } catch (_) {}

    debugPrint('BluetoothAudioService: Connected to ${device.name}');
    return true;
  }

  /// Disconnect and return audio to Phone Speaker
  static Future<void> disconnect() async {
    _currentDevice = null;
    _deviceStreamController.add(null);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefConnectedKey, 'phone_speaker');
    } catch (_) {}

    debugPrint('BluetoothAudioService: Disconnected, switched to Phone Speaker');
  }

  /// Scan for nearby Bluetooth devices
  static Future<List<BluetoothAudioDevice>> scanForDevices() async {
    if (!_isBluetoothEnabled) return [];

    _isScanning = true;
    _scannedDevices = [];

    // Simulate scan discovery
    await Future.delayed(const Duration(milliseconds: 1200));

    _scannedDevices = [
      const BluetoothAudioDevice(
        id: 'bt_bose_qc45',
        name: 'Bose QuietComfort 45',
        type: BluetoothDeviceType.headphones,
        batteryLevel: 95,
        isPaired: false,
        isConnected: false,
      ),
      const BluetoothAudioDevice(
        id: 'bt_marshall_emberton',
        name: 'Marshall Emberton II',
        type: BluetoothDeviceType.speaker,
        batteryLevel: 65,
        isPaired: false,
        isConnected: false,
      ),
      const BluetoothAudioDevice(
        id: 'bt_soundcore_q30',
        name: 'Anker Soundcore Q30',
        type: BluetoothDeviceType.headphones,
        batteryLevel: 88,
        isPaired: false,
        isConnected: false,
      ),
    ];

    _isScanning = false;
    return _scannedDevices;
  }
}
