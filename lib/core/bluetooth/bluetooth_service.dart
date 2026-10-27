import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart' as bc;
import 'package:permission_handler/permission_handler.dart';
import '../models/device_model.dart';

enum ActiveConnectionType { none, classicSpp, bleGatt }

class RealBluetoothService extends ChangeNotifier {
  static final RealBluetoothService _instance = RealBluetoothService._internal();
  factory RealBluetoothService() => _instance;

  RealBluetoothService._internal() {
    _initBluetoothListeners();
  }

  // Dual-mode Bluetooth engines
  final BluetoothClassic _classic = BluetoothClassic();

  // --- Real Bluetooth State ---
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  bool isScanning = false;
  String? lastError;
  bool isPermissionGranted = false;
  bool isLocationEnabled = true;

  ActiveConnectionType activeType = ActiveConnectionType.none;
  String? connectedMac;
  String? connectedName;

  // Real world discovered & bonded devices
  List<RoboticDevice> realNearbyDevices = [];
  List<RoboticDevice> realBondedDevices = [];
  final Map<String, BluetoothDevice> _bleDeviceMap = {};

  BluetoothDevice? connectedBleDevice;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<bc.Device>? _classicDiscoverySub;
  StreamSubscription<int>? _classicStatusSub;
  StreamSubscription<Uint8List>? _classicDataSub;

  Function(String data)? onDataReceived;

  void _initBluetoothListeners() {
    try {
      _adapterSub = FlutterBluePlus.adapterState.listen((state) {
        adapterState = state;
        notifyListeners();
      });

      _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
        isScanning = scanning;
        notifyListeners();
      });

      _classicStatusSub = _classic.onDeviceStatusChanged().listen((status) {
        // Status 1 = connected, 0 = disconnected
        if (status == 0 && activeType == ActiveConnectionType.classicSpp) {
          activeType = ActiveConnectionType.none;
          connectedMac = null;
          connectedName = null;
          notifyListeners();
        }
      });

      _classicDataSub = _classic.onDeviceDataReceived().listen((data) {
        final text = utf8.decode(data, allowMalformed: true);
        onDataReceived?.call(text);
      });

      checkLocationService();
    } catch (e) {
      debugPrint("[BLE Service] Init error: $e");
    }
  }

  Future<bool> checkLocationService() async {
    if (Platform.isAndroid) {
      try {
        isLocationEnabled = await Permission.location.serviceStatus.isEnabled;
        notifyListeners();
        return isLocationEnabled;
      } catch (_) {}
    }
    return true;
  }

  // --- 1. Request Real Android Permissions ---
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        try {
          await _classic.initPermissions();
        } catch (_) {}

        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        await checkLocationService();

        final scanGranted = statuses[Permission.bluetoothScan]?.isGranted == true ||
            statuses[Permission.bluetoothScan]?.isLimited == true ||
            statuses[Permission.location]?.isGranted == true;

        final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted == true ||
            statuses[Permission.bluetoothConnect]?.isLimited == true ||
            statuses[Permission.location]?.isGranted == true;

        isPermissionGranted = scanGranted && connectGranted;
        notifyListeners();
        return isPermissionGranted;
      }
      isPermissionGranted = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[BLE Service] Permission request error: $e");
      return false;
    }
  }

  // --- 2. Check & Turn On Bluetooth ---
  Future<bool> ensureBluetoothOn() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        lastError = "Bluetooth hardware not supported on this device.";
        notifyListeners();
        return false;
      }

      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (e) {
            debugPrint("[BLE Service] Prompt turn on error: $e");
          }
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      }
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint("[BLE Service] turnOn error: $e");
      lastError = "Could not activate Bluetooth: $e";
      notifyListeners();
      return false;
    }
  }

  // --- 3. Get Real Paired / Bonded Devices (Both Classic & BLE) ---
  Future<List<RoboticDevice>> getBondedDevices() async {
    final Map<String, RoboticDevice> uniqueBonded = {};

    // A. Query Bluetooth Classic paired devices (HC-05, HC-06, etc.)
    try {
      final classicList = await _classic.getPairedDevices();
      for (var dev in classicList) {
        final mac = dev.address.trim();
        if (mac.isEmpty) continue;
        String name = dev.name?.trim() ?? "";
        if (name.isEmpty) {
          final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
          name = "Paired Device ($shortMac)";
        }

        uniqueBonded[mac] = RoboticDevice(
          id: "bonded-$mac",
          name: name,
          macAddress: mac,
          ipAddress: "192.168.4.1",
          protocol: "Bluetooth (Classic)",
          rssi: -50,
          isConnected: (activeType == ActiveConnectionType.classicSpp && connectedMac == mac),
          deviceType: _guessDeviceType(name),
        );
      }
    } catch (e) {
      debugPrint("[Classic Service] getPairedDevices error: $e");
    }

    // B. Query BLE bonded & system devices
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (isSupported) {
        final bonded = await FlutterBluePlus.bondedDevices;
        List<BluetoothDevice> sysConnected = [];
        try {
          sysConnected = await FlutterBluePlus.systemDevices([]);
        } catch (_) {}

        for (var dev in [...bonded, ...sysConnected]) {
          final mac = dev.remoteId.str;
          _bleDeviceMap[mac] = dev;

          if (!uniqueBonded.containsKey(mac)) {
            String name = dev.platformName.trim();
            if (name.isEmpty) name = dev.advName.trim();
            if (name.isEmpty) {
              final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
              name = "Paired Device ($shortMac)";
            }

            uniqueBonded[mac] = RoboticDevice(
              id: "bonded-$mac",
              name: name,
              macAddress: mac,
              ipAddress: "192.168.4.1",
              protocol: "BLE 5.2",
              rssi: -55,
              isConnected: dev.isConnected,
              deviceType: _guessDeviceType(name),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("[BLE Service] getBondedDevices error: $e");
    }

    realBondedDevices = uniqueBonded.values.toList();
    notifyListeners();
    return realBondedDevices;
  }

  // --- 4. Start Real Nearby Bluetooth Scan (Dual: Classic + BLE) ---
  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    lastError = null;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      lastError = "Bluetooth permission was not granted. Please allow nearby device permissions in settings.";
      notifyListeners();
      return;
    }

    final isBtOn = await ensureBluetoothOn();
    if (!isBtOn) {
      lastError = "Please turn on Bluetooth to scan for real devices.";
      notifyListeners();
      return;
    }

    await getBondedDevices();

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      try {
        await _classic.stopScan();
      } catch (_) {}

      realNearbyDevices.clear();
      isScanning = true;
      notifyListeners();

      final Map<String, RoboticDevice> unique = {};

      void updateList() {
        realNearbyDevices = unique.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        notifyListeners();
      }

      // Stream A: BLE Scan
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (var res in results) {
          final dev = res.device;
          final mac = dev.remoteId.str;
          _bleDeviceMap[mac] = dev;

          String name = dev.platformName.trim();
          if (name.isEmpty) name = res.advertisementData.advName.trim();
          if (name.isEmpty) {
            final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
            name = "BLE Device ($shortMac)";
          }

          unique[mac] = RoboticDevice(
            id: "real-$mac",
            name: name,
            macAddress: mac,
            ipAddress: "192.168.4.1",
            protocol: "BLE 5.2",
            rssi: res.rssi,
            isConnected: dev.isConnected,
            deviceType: _guessDeviceType(name),
          );
        }
        updateList();
      });

      // Stream B: Classic Discovery
      _classicDiscoverySub?.cancel();
      _classicDiscoverySub = _classic.onDeviceDiscovered().listen((dev) {
        final mac = dev.address.trim();
        if (mac.isEmpty) return;

        String name = dev.name?.trim() ?? "";
        if (name.isEmpty) {
          final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
          name = "Classic BT ($shortMac)";
        }

        if (!unique.containsKey(mac)) {
          unique[mac] = RoboticDevice(
            id: "real-$mac",
            name: name,
            macAddress: mac,
            ipAddress: "192.168.4.1",
            protocol: "Bluetooth (Classic)",
            rssi: -55,
            isConnected: (activeType == ActiveConnectionType.classicSpp && connectedMac == mac),
            deviceType: _guessDeviceType(name),
          );
          updateList();
        }
      });

      // Launch both scans
      await Future.wait([
        FlutterBluePlus.startScan(timeout: timeout).catchError((e) {
          debugPrint("[BLE] Scan error: $e");
        }),
        _classic.startScan().catchError((e) {
          debugPrint("[Classic] Scan error: $e");
          return false;
        }),
      ]);

      // Timer to stop classic after timeout
      Future.delayed(timeout, () {
        stopScan();
      });
    } catch (e) {
      debugPrint("[BLE Service] startScan error: $e");
      lastError = "Scan failed: $e";
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await _classic.stopScan();
    } catch (_) {}
    isScanning = false;
    notifyListeners();
  }

  // --- 5. Connect to Real Hardware Device (Classic SPP or BLE GATT) ---
  Future<bool> connect(RoboticDevice device) async {
    final mac = device.macAddress;
    lastError = null;

    // Disconnect any existing link first
    await disconnect();

    // Strategy: If protocol indicates Classic, or by default for robotics SPP (HC-05/HC-06),
    // try Bluetooth Classic SPP connection first.
    const String sppUuid = "00001101-0000-1000-8000-00805F9B34FB";

    bool isClassicDevice = device.protocol.contains("Classic") ||
        device.id.startsWith("classic-") ||
        !_bleDeviceMap.containsKey(mac);

    if (isClassicDevice) {
      try {
        debugPrint("[BLE/Classic Service] Attempting Classic SPP connect to $mac...");
        final success = await _classic.connect(mac, sppUuid);
        if (success) {
          activeType = ActiveConnectionType.classicSpp;
          connectedMac = mac;
          connectedName = device.name;
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint("[Classic Service] Classic SPP connection error: $e");
      }
    }

    // Attempt BLE GATT connection if Classic failed or device was discovered via BLE
    final bleDevice = _bleDeviceMap[mac] ?? BluetoothDevice.fromId(mac);
    try {
      debugPrint("[BLE/Classic Service] Attempting BLE GATT connect to $mac...");
      await bleDevice.connect(
        timeout: const Duration(seconds: 10),
        license: License.nonprofit,
      );
      connectedBleDevice = bleDevice;
      activeType = ActiveConnectionType.bleGatt;
      connectedMac = mac;
      connectedName = device.name;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[BLE Service] BLE GATT connection error: $e");
      try {
        await bleDevice.disconnect();
      } catch (_) {}

      // If BLE failed and we haven't tried Classic yet, try Classic SPP now!
      if (!isClassicDevice) {
        try {
          debugPrint("[BLE/Classic Service] Falling back to Classic SPP connect for $mac...");
          final success = await _classic.connect(mac, sppUuid);
          if (success) {
            activeType = ActiveConnectionType.classicSpp;
            connectedMac = mac;
            connectedName = device.name;
            notifyListeners();
            return true;
          }
        } catch (_) {}
      }

      lastError = "Could not connect to ${device.name}. Ensure device is powered on and in range.";
      notifyListeners();
      return false;
    }
  }

  Future<void> sendData(String message) async {
    try {
      debugPrint("[Bluetooth Service] TX: ${message.trim()} (mode: $activeType, mac: $connectedMac)");
      if (activeType == ActiveConnectionType.classicSpp) {
        final ok = await _classic.write(message);
        debugPrint("[Classic Service] write result: $ok");
      }
    } catch (e) {
      debugPrint("[Bluetooth Service] sendData error: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      if (activeType == ActiveConnectionType.classicSpp) {
        await _classic.disconnect();
      }
      if (connectedBleDevice != null) {
        await connectedBleDevice!.disconnect();
        connectedBleDevice = null;
      }
      activeType = ActiveConnectionType.none;
      connectedMac = null;
      connectedName = null;
      notifyListeners();
    } catch (e) {
      debugPrint("[BLE Service] Disconnect error: $e");
    }
  }

  static String _guessDeviceType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('car') || lower.contains('rover') || lower.contains('mecanum') || lower.contains('bot')) {
      return "Rover";
    } else if (lower.contains('arm') || lower.contains('servo')) {
      return "Arm";
    } else if (lower.contains('cam') || lower.contains('camera')) {
      return "Cam";
    } else if (lower.contains('lamp') || lower.contains('led') || lower.contains('rgb') || lower.contains('relay')) {
      return "Relay";
    } else if (lower.contains('headphone') || lower.contains('audio') || lower.contains('buds') || lower.contains('speaker')) {
      return "Audio";
    }
    return "Node";
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _adapterSub?.cancel();
    _classicDiscoverySub?.cancel();
    _classicStatusSub?.cancel();
    _classicDataSub?.cancel();
    super.dispose();
  }
}
