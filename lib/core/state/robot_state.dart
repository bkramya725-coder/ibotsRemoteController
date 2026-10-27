import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../database/device_database.dart';
import '../bluetooth/bluetooth_service.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class RobotState extends ChangeNotifier {
  static final RobotState _instance = RobotState._internal();
  factory RobotState() => _instance;

  final DeviceProfileDatabase database = DeviceProfileDatabase();
  final RealBluetoothService bleService = RealBluetoothService();

  RobotState._internal() {
    _initTerminalLogs();
    _startSimulatedTelemetry();
    _loadPairedProfiles();
    _initBleListener();
    _refreshNearbyForProtocol(activeProtocol);
  }

  void _initBleListener() {
    bleService.addListener(_onBleChanged);
    bleService.onDataReceived = (data) {
      addTerminalLog(data.trim(), LogType.rx);
    };
    // Asynchronously load real phone bonded devices on launch
    bleService.getBondedDevices();
  }

  void _onBleChanged() {
    isScanning = bleService.isScanning;
    if (bleService.activeType != ActiveConnectionType.none) {
      if (connectionStatus != ConnectionStatus.connected) {
        connectionStatus = ConnectionStatus.connected;
        currentDevice = currentDevice.copyWith(
          name: bleService.connectedName ?? currentDevice.name,
          macAddress: bleService.connectedMac ?? currentDevice.macAddress,
          isConnected: true,
        );
      }
    }
    if (activeProtocol.contains("Bluetooth") || activeProtocol.contains("BLE")) {
      nearbyDiscoveredDevices = List.from(bleService.realNearbyDevices);
    }
    notifyListeners();
  }

  // --- DEVICE CONNECTION & RADIO STATE ---
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  String activeProtocol = "Bluetooth / BLE";
  bool isRadioEnabled = true;
  bool isScanning = false;

  RoboticDevice currentDevice = const RoboticDevice(
    id: "ibt-classic-01",
    name: "iBots Mecanum 4WD (Classic)",
    macAddress: "00:1A:7D:DA:71:13",
    ipAddress: "192.168.4.10",
    protocol: "Bluetooth (Classic)",
    rssi: -48,
    isConnected: false,
    batteryVoltage: 8.4,
    pingMs: 12,
    deviceType: "Rover",
  );

  RoboticDevice? targetDevice;

  List<DeviceProfile> pairedProfiles = [];
  List<RoboticDevice> nearbyDiscoveredDevices = [];

  List<RoboticDevice> get discoveredDevices => nearbyDiscoveredDevices;

  Future<void> _loadPairedProfiles() async {
    pairedProfiles = await database.getAllProfiles();
    notifyListeners();
  }

  void setProtocol(String protocol) {
    activeProtocol = protocol;
    _refreshNearbyForProtocol(protocol);
    // If not connected, also update current target profile
    final matchingPaired = pairedProfiles.where((p) {
      if (protocol.contains("Classic")) return p.protocol.contains("Classic");
      if (protocol.contains("BLE")) return p.protocol.contains("BLE");
      return p.protocol.contains("Wi-Fi") || p.protocol.contains("WiFi");
    }).toList();

    if (matchingPaired.isNotEmpty && !currentDevice.isConnected) {
      targetDevice = matchingPaired.first.toRoboticDevice();
    }
    notifyListeners();
  }

  void _refreshNearbyForProtocol(String protocol) {
    if (protocol.contains("Classic")) {
      nearbyDiscoveredDevices = [
        const RoboticDevice(
          id: "bt-hc05-01",
          name: "iBots HC-05 SPP Bridge",
          macAddress: "00:14:03:05:58:20",
          ipAddress: "192.168.4.15",
          protocol: "Bluetooth (Classic)",
          rssi: -42,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "bt-mecanum-02",
          name: "iBots Mecanum 4WD",
          macAddress: "00:1A:7D:DA:71:13",
          ipAddress: "192.168.4.10",
          protocol: "Bluetooth (Classic)",
          rssi: -48,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "bt-nano-03",
          name: "Arduino Nano Bluetooth",
          macAddress: "98:D3:31:FC:2B:7A",
          ipAddress: "192.168.4.18",
          protocol: "Bluetooth (Classic)",
          rssi: -68,
          deviceType: "Rover",
        ),
      ];
    } else if (protocol.contains("BLE")) {
      nearbyDiscoveredDevices = [
        const RoboticDevice(
          id: "ibt-4899",
          name: "iBots Rover ESP32-WROOM",
          macAddress: "24:6F:28:B2:1A:40",
          ipAddress: "192.168.4.1",
          protocol: "BLE 5.2",
          rssi: -54,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "ibt-arm-06",
          name: "iBots 6-DOF Robotic Arm",
          macAddress: "A4:CF:12:D5:78:10",
          ipAddress: "192.168.4.3",
          protocol: "BLE 5.2",
          rssi: -71,
          deviceType: "Arm",
        ),
        const RoboticDevice(
          id: "esp-relay-08",
          name: "ESP32-S3 SmartRelay Node",
          macAddress: "7C:DF:A1:40:9B:12",
          ipAddress: "192.168.4.8",
          protocol: "BLE 5.2",
          rssi: -59,
          deviceType: "Relay",
        ),
      ];
    } else {
      // Wi-Fi AP
      nearbyDiscoveredDevices = [
        const RoboticDevice(
          id: "ibt-cam-02",
          name: "iBots ESP32-CAM Streamer",
          macAddress: "30:AE:A4:07:0C:88",
          ipAddress: "192.168.4.1",
          protocol: "Wi-Fi AP",
          rssi: -52,
          deviceType: "Cam",
        ),
        const RoboticDevice(
          id: "ibt-wifi-rover",
          name: "iBots High-Speed Rover AP",
          macAddress: "48:55:19:D2:88:2E",
          ipAddress: "192.168.4.2",
          protocol: "Wi-Fi AP",
          rssi: -60,
          deviceType: "Rover",
        ),
        const RoboticDevice(
          id: "mesh-gateway-01",
          name: "iBots Mesh Fleet Gateway",
          macAddress: "18:FE:34:E0:11:9C",
          ipAddress: "192.168.1.180",
          protocol: "Wi-Fi AP",
          rssi: -68,
          deviceType: "Gateway",
        ),
      ];
    }
  }

  void selectTargetDevice(RoboticDevice device) {
    targetDevice = device;
    currentDevice = device.copyWith(isConnected: false);
    activeProtocol = device.protocol;
    // Save to SQLite/Drift database profiles
    database.saveProfile(DeviceProfile.fromRoboticDevice(device));
    _loadPairedProfiles();
    addTerminalLog("[SYS] Selected target node: ${device.name} (${device.macAddress})", LogType.system);
    notifyListeners();
  }

  void toggleRadio(bool enabled) {
    isRadioEnabled = enabled;
    if (!enabled && currentDevice.isConnected) {
      disconnectDevice();
    }
    notifyListeners();
  }

  Future<void> startScanning() async {
    isScanning = true;
    notifyListeners();

    if (activeProtocol.contains("Bluetooth") || activeProtocol.contains("BLE") || activeProtocol.contains("Classic")) {
      addTerminalLog("[BLE] Requesting hardware permissions and scanning RF spectrum...", LogType.system);
      await bleService.startScan();
      isScanning = bleService.isScanning;
      if (bleService.realNearbyDevices.isNotEmpty) {
        nearbyDiscoveredDevices = List.from(bleService.realNearbyDevices);
      }
      notifyListeners();
    } else {
      // Wi-Fi AP fallback
      await Future.delayed(const Duration(milliseconds: 1500));
      _refreshNearbyForProtocol(activeProtocol);
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> connectToTargetDevice() async {
    final dev = targetDevice ?? currentDevice;
    connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    addTerminalLog("[${dev.protocol}] Handshake initiated with ${dev.name} (${dev.macAddress})...", LogType.bluetooth);

    // Check if device is a real hardware Bluetooth device (bonded, discovered, or valid MAC)
    final bool isMockDemo = dev.id == "bt-hc05-01" ||
        dev.id == "bt-mecanum-02" ||
        dev.id == "bt-nano-03" ||
        dev.id == "ibt-classic-01" ||
        dev.id == "ibt-4899";

    final bool isRealHardware = !isMockDemo ||
        dev.id.startsWith("real-") ||
        dev.id.startsWith("bonded-") ||
        RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$').hasMatch(dev.macAddress);

    bool success = true;
    if (isRealHardware) {
      // Real Bluetooth connection attempt to hardware (HC-05 Classic SPP or BLE GATT)
      addTerminalLog("[SYS] Connecting to real hardware ${dev.macAddress}...", LogType.system);
      success = await bleService.connect(dev);
    } else {
      // Simulated delay for demo device
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (success) {
      connectionStatus = ConnectionStatus.connected;
      currentDevice = dev.copyWith(isConnected: true);
      database.updateLastConnected(dev.id);
      _loadPairedProfiles();
      addTerminalLog("[${dev.protocol}] Connection established! RSSI: ${dev.rssi} dBm", LogType.system);
    } else {
      connectionStatus = ConnectionStatus.disconnected;
      addTerminalLog("[${dev.protocol}] Connection failed to ${dev.name}. Check device power or pairing.", LogType.error);
    }
    notifyListeners();
  }

  void disconnectDevice() {
    final dev = currentDevice;
    bleService.disconnect();
    connectionStatus = ConnectionStatus.disconnected;
    currentDevice = dev.copyWith(isConnected: false);
    addTerminalLog("[SYS] Disconnected from ${dev.name}", LogType.system);
    notifyListeners();
  }

  void toggleDeviceConnection(String id) {
    if (connectionStatus == ConnectionStatus.connected) {
      disconnectDevice();
    } else {
      final dev = nearbyDiscoveredDevices.firstWhere((d) => d.id == id, orElse: () => currentDevice);
      selectTargetDevice(dev);
      connectToTargetDevice();
    }
  }

  Future<void> forgetDevice(String id) async {
    await database.deleteProfile(id);
    await _loadPairedProfiles();
    if (currentDevice.id == id && currentDevice.isConnected) {
      disconnectDevice();
    }
    notifyListeners();
  }

  // --- CAR CONTROLLER & DRIVING STATE ---
  double speedCap = 75.0; // percentage
  String driveMode = "NORM"; // "CRAWL", "NORM", "SPORT"
  String gear = "D"; // 'P', 'R', 'N', 'D'
  bool headlights = false;
  bool hornActive = false;
  bool emergencyBrake = false;
  bool danceMode = false;
  double throttle = 0.0; // -1.0 to 1.0
  double steering = 0.0; // -1.0 to 1.0
  String motionStatusText = "IDLE • STANDBY";

  void setSpeedCap(double val) {
    speedCap = val;
    if (val <= 40) {
      driveMode = "CRAWL";
    } else if (val <= 80) {
      driveMode = "NORM";
    } else {
      driveMode = "SPORT";
    }
    bleService.sendData("SPEED:${val.toInt()}\n");
    addTerminalLog(">>> SET_SPEED: ${val.toInt()}% [$driveMode]", LogType.tx);
    notifyListeners();
  }

  void setThrottle(double t) {
    throttle = t;
    _updateMotionText();
    notifyListeners();
  }

  void setSteering(double s) {
    steering = s;
    _updateMotionText();
    notifyListeners();
  }

  void _updateMotionText() {
    if (emergencyBrake) {
      motionStatusText = "EMERGENCY BRAKE ACTIVE";
    } else if (throttle > 0.1) {
      motionStatusText = "FORWARD • ${(throttle * 100).toInt()}%";
    } else if (throttle < -0.1) {
      motionStatusText = "REVERSE • ${(-throttle * 100).toInt()}%";
    } else if (steering.abs() > 0.1) {
      motionStatusText = steering > 0 ? "RIGHT TURN" : "LEFT TURN";
    } else {
      motionStatusText = "IDLE • STANDBY";
    }
  }

  void sendCarMotionCommand(String cmd) {
    bleService.sendData("$cmd\n");
  }

  void toggleHeadlights() {
    headlights = !headlights;
    relays[0] = headlights; // sync with switch panel Ch 1
    bleService.sendData(headlights ? "W\n" : "w\n");
    addTerminalLog(">>> SET_LIGHT=${headlights ? 1 : 0}", LogType.tx);
    notifyListeners();
  }

  void setHorn(bool active) {
    hornActive = active;
    relays[3] = active; // sync with Buzzer Ch 4
    bleService.sendData(active ? "H\n" : "h\n");
    addTerminalLog(">>> HORN=${active ? 1 : 0}", LogType.tx);
    notifyListeners();
  }

  void triggerEmergencyBrake() {
    emergencyBrake = !emergencyBrake;
    if (emergencyBrake) {
      throttle = 0;
      steering = 0;
      danceMode = false;
      motionStatusText = "EMERGENCY BRAKE ACTIVE";
      bleService.sendData("S\n");
      addTerminalLog(">>> [E-STOP] MOTORS HALTED IMMEDIATELY", LogType.error);
    } else {
      motionStatusText = "IDLE • STANDBY";
    }
    notifyListeners();
  }

  void toggleDanceMode() {
    danceMode = !danceMode;
    if (danceMode) {
      emergencyBrake = false;
      motionStatusText = "DANCE CHOREOGRAPHY ACTIVE";
      bleService.sendData("X\n");
      addTerminalLog(">>> EXEC_ROUTINE: CHOREO_DANCE_01", LogType.tx);
    } else {
      motionStatusText = "IDLE • STANDBY";
      bleService.sendData("S\n");
    }
    notifyListeners();
  }

  // --- VIRTUAL KEYPAD ---
  String keypadDisplay = "READY";
  List<String> keypadHistory = ["A: SCAN", "1: FWD_10CM", "5: CENTER_ALL"];

  void pressKeypad(String key) {
    if (key == "*") {
      keypadDisplay = "";
      bleService.sendData("*\n");
    } else if (key == "#") {
      if (keypadDisplay.isNotEmpty) {
        keypadHistory.insert(0, keypadDisplay);
        if (keypadHistory.length > 20) keypadHistory.removeLast();
        addTerminalLog(">>> KEYPAD_CMD: $keypadDisplay", LogType.tx);
        bleService.sendData("$keypadDisplay#\n");
        keypadDisplay = "SENT: $keypadDisplay";
      }
    } else {
      bleService.sendData("$key\n");
      if (keypadDisplay == "READY" || keypadDisplay.startsWith("SENT")) {
        keypadDisplay = key;
      } else {
        keypadDisplay += key;
      }
    }
    notifyListeners();
  }

  // --- TELEMETRY STATE ---
  double batteryVoltage = 8.4;
  double batteryPercentage = 92.0;
  double motorCurrent = 1.65; // Amps
  double coreTemperature = 38.4; // Celsius
  double pitchAngle = -1.8; // degrees
  double rollAngle = 3.2; // degrees
  double yawAngle = 142.0; // degrees
  int linkLatency = 12; // ms
  double proximityDistance = 48.0; // cm
  double get ultrasonicDistance => proximityDistance;
  int get batteryPercent => batteryPercentage.toInt();

  void addLog(LogType type, String msg) => addTerminalLog(msg, type);

  Timer? _telemetryTimer;
  void _startSimulatedTelemetry() {
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!currentDevice.isConnected) return;
      // Slight subtle realistic jitter
      batteryVoltage = 8.38 + (timer.tick % 5) * 0.01;
      coreTemperature = 38.0 + (timer.tick % 7) * 0.1;
      motorCurrent = (throttle != 0 || steering != 0) ? 2.45 + (timer.tick % 4) * 0.2 : 0.42;
      linkLatency = 11 + (timer.tick % 4);
      notifyListeners();
    });
  }

  void stopSimulatedTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  // --- LED / LAMP STATE ---
  bool lampPower = false;
  Color lampColor = const Color(0xFF00E5FF);
  double lampBrightness = 85.0; // 0 - 100
  String lampMode = "Solid"; // "Solid", "Pulse", "Strobe", "Rainbow", "Police"
  double lampSpeed = 50.0;

  void toggleLampPower() {
    lampPower = !lampPower;
    bleService.sendData("RGB_POWER:${lampPower ? 1 : 0}\n");
    addTerminalLog(">>> RGB_POWER=${lampPower ? 1 : 0}", LogType.tx);
    notifyListeners();
  }

  void setLampColor(Color c) {
    lampColor = c;
    lampPower = true;
    final hex = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    bleService.sendData("RGB_COLOR:$hex\n");
    addTerminalLog(">>> RGB_COLOR=$hex", LogType.tx);
    notifyListeners();
  }

  void setLampBrightness(double b) {
    lampBrightness = b;
    bleService.sendData("RGB_BRIGHT:${b.toInt()}\n");
    notifyListeners();
  }

  void setLampMode(String m) {
    lampMode = m;
    bleService.sendData("RGB_MODE:$m\n");
    notifyListeners();
  }

  // --- 8-CHANNEL SWITCH PANEL ---
  List<bool> relays = [
    false, // Ch 1: Headlights
    false, // Ch 2: Underglow Neopixels
    true,  // Ch 3: Auxiliary 5V Rail
    false, // Ch 4: Warning Buzzer
    true,  // Ch 5: FPV Camera Pan/Tilt
    false, // Ch 6: High-Torque Gearbox Solenoid
    true,  // Ch 7: Cooling Fan
    false, // Ch 8: Targeting Laser Pointer
  ];

  final List<String> relayNames = [
    "Headlights (High Beam)",
    "Underglow Neopixels",
    "Auxiliary 5V Power Rail",
    "Audible Alert Siren / Buzzer",
    "FPV Camera Gimbal Servos",
    "Gearbox High-Torque Lock",
    "Active Cooling Fan",
    "Targeting Red Laser Pointer",
  ];

  void toggleRelay(int index) {
    relays[index] = !relays[index];
    if (index == 0) headlights = relays[0];
    final charCode = relays[index] ? (97 + index) : (65 + index); // 'a'-'h' for ON, 'A'-'H' for OFF
    final relayChar = String.fromCharCode(charCode);
    bleService.sendData("$relayChar\n");
    addTerminalLog(">>> RELAY_SET(CH${index + 1}, ${relays[index] ? 1 : 0}) [$relayChar]", LogType.tx);
    notifyListeners();
  }

  void setAllRelays(bool state) {
    for (int i = 0; i < relays.length; i++) {
      relays[i] = state;
    }
    headlights = state;
    bleService.sendData(state ? "RELAY_ALL_ON\n" : "RELAY_ALL_OFF\n");
    addTerminalLog(">>> MASTER_RELAYS=${state ? 'ALL_ON' : 'ALL_OFF'}", LogType.tx);
    notifyListeners();
  }

  // --- SERIAL TERMINAL / CLI ---
  List<TerminalLog> logs = [];
  int baudRate = 115200;
  bool autoScroll = true;

  void _initTerminalLogs() {
    logs = [];
  }

  void addTerminalLog(String msg, LogType type) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond).toString().padLeft(3, '0')}";
    logs.add(TerminalLog(timestamp: timeStr, message: msg, type: type));
    if (logs.length > 200) logs.removeAt(0);
    notifyListeners();
  }

  void sendTerminalCommand(String cmd) {
    if (cmd.trim().isEmpty) return;
    addTerminalLog(cmd.trim(), LogType.tx);
    bleService.sendData("${cmd.trim()}\n");
  }

  void clearTerminal() {
    logs.clear();
    notifyListeners();
  }

  // --- ROBOTIC ARM (6-DOF) ---
  Map<String, double> armAngles = {
    'A': 90.0,  // Base Axis 1
    'B': 45.0,  // Shoulder Axis 2
    'C': 120.0, // Elbow Axis 3
    'D': 90.0,  // Wrist Pitch Axis 4
    'E': 0.0,   // Wrist Roll Axis 5
    'F': 55.0,  // Gripper Claw Axis 6
  };

  void setArmAngle(String axis, double angle) {
    armAngles[axis] = angle;
    bleService.sendData("ARM:$axis:${angle.toInt()}\n");
    notifyListeners();
  }

  void resetAllArmServos() {
    armAngles = {
      'A': 90.0,
      'B': 90.0,
      'C': 90.0,
      'D': 90.0,
      'E': 90.0,
      'F': 0.0,
    };
    bleService.sendData("ARM_GOTO:90,90,90,90,90,0\n");
    addTerminalLog(">>> ARM_GOTO(90, 90, 90, 90, 90, 0)", LogType.tx);
    notifyListeners();
  }

  void setArmPose(String poseName) {
    if (poseName == "Home") {
      armAngles = {'A': 90.0, 'B': 90.0, 'C': 90.0, 'D': 90.0, 'E': 90.0, 'F': 0.0};
    } else if (poseName == "Pick") {
      armAngles = {'A': 90.0, 'B': 140.0, 'C': 45.0, 'D': 110.0, 'E': 0.0, 'F': 100.0};
    } else if (poseName == "Place") {
      armAngles = {'A': 170.0, 'B': 130.0, 'C': 50.0, 'D': 95.0, 'E': 45.0, 'F': 10.0};
    } else if (poseName == "Wave") {
      armAngles = {'A': 90.0, 'B': 30.0, 'C': 160.0, 'D': 45.0, 'E': 80.0, 'F': 50.0};
    }
    bleService.sendData("ARM_PRESET:$poseName\n");
    addTerminalLog(">>> ARM_EXEC_PRESET: $poseName", LogType.tx);
    notifyListeners();
  }

  // --- GYRO / TILT-TO-STEER ---
  bool gyroEnabled = true;
  double gyroSensitivity = 1.2;
  double gyroDeadzone = 5.0; // degrees
  double phonePitch = 0.0;
  double phoneRoll = 0.0;
  double phoneYaw = 0.0;

  void toggleGyro() {
    gyroEnabled = !gyroEnabled;
    addTerminalLog(">>> GYRO_STEER_ACTIVE=${gyroEnabled ? 1 : 0}", LogType.tx);
    notifyListeners();
  }

  void calibrateGyroHorizon() {
    phonePitch = 0.0;
    phoneRoll = 0.0;
    addTerminalLog(">>> GYRO_ZERO_CALIBRATED", LogType.tx);
    notifyListeners();
  }

  // --- VOICE CONTROL ---
  bool isVoiceListening = false;
  String lastVoiceTranscript = "Move forward at half speed";
  double voiceConfidence = 0.94;
  List<String> voiceHistory = [
    "Move forward at half speed",
    "Turn lights on",
    "Full stop",
    "Arm pick object",
  ];

  void toggleVoiceListening() {
    isVoiceListening = !isVoiceListening;
    if (isVoiceListening) {
      Future.delayed(const Duration(seconds: 2), () {
        isVoiceListening = false;
        lastVoiceTranscript = "Turn lights on";
        voiceConfidence = 0.96;
        voiceHistory.insert(0, lastVoiceTranscript);
        headlights = true;
        relays[0] = true;
        addTerminalLog(">>> VOICE_CMD: '$lastVoiceTranscript' [CONF: 96%]", LogType.tx);
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // --- ESP32-CAM ---
  String camMode = "AP"; // "AP" or "Router"
  String camIp = "192.168.4.1";
  bool isCamStreaming = true;
  bool camFlash = false;
  double camFlashBrightness = 60.0;
  bool faceDetection = true;
  double camPan = 90.0;
  double camTilt = 45.0;
  List<String> capturedPhotos = [];

  void toggleCamMode(String mode) {
    camMode = mode;
    camIp = (mode == "AP") ? "192.168.4.1" : "192.168.1.184";
    notifyListeners();
  }

  void toggleCamFlash() {
    camFlash = !camFlash;
    notifyListeners();
  }

  void captureCamPhoto() {
    final photoName = "IMG_ESP32_${DateTime.now().millisecondsSinceEpoch}.jpg";
    capturedPhotos.insert(0, photoName);
    addTerminalLog(">>> ESP32_CAM: Snapshot saved to $photoName", LogType.rx);
    notifyListeners();
  }

  // --- USER PROFILE & SETTINGS ---
  String userName = "Alex Harrison";
  String userRole = "Lead Robotics Operator";
  int connectedRobotsCount = 12;
  int hoursLogged = 148;
  double linkReliability = 99.4;

  bool hapticVibration = true;
  int telemetryFrequencyHz = 20;
  bool invertY = false;

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }
}
