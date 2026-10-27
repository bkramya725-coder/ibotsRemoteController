import 'package:flutter/material.dart';
import '../core/state/robot_state.dart';
import '../core/database/device_database.dart';

class DeviceDiscoverySheet extends StatefulWidget {
  final String protocol;
  const DeviceDiscoverySheet({super.key, required this.protocol});

  static Future<void> show(BuildContext context, String protocol) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceDiscoverySheet(protocol: protocol),
    );
  }

  @override
  State<DeviceDiscoverySheet> createState() => _DeviceDiscoverySheetState();
}

class _DeviceDiscoverySheetState extends State<DeviceDiscoverySheet> with SingleTickerProviderStateMixin {
  final RobotState state = RobotState();
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Start scanning safely after initial frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) state.startScanning();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'arm':
        return Icons.precision_manufacturing;
      case 'cam':
        return Icons.videocam;
      case 'relay':
        return Icons.toggle_on;
      case 'gateway':
        return Icons.router;
      case 'rover':
      default:
        return Icons.smart_toy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanProto = state.activeProtocol;
    final isWifi = cleanProto.toLowerCase().contains("wi-fi") || cleanProto.toLowerCase().contains("wifi");
    final title = isWifi ? "Wi-Fi Networks & APs" : (cleanProto.contains("BLE") ? "BLE 5.2 Device Discovery" : "Bluetooth Devices");
    final target = state.targetDevice ?? state.currentDevice;

    // Filter paired profiles for current protocol + real phone bonded devices
    final List<DeviceProfile> matchingProfiles = List.from(state.pairedProfiles.where((p) {
      if (cleanProto.contains("Classic") || cleanProto.contains("Bluetooth") || cleanProto.contains("BLE")) {
        return p.protocol.contains("Classic") || p.protocol.contains("Bluetooth") || p.protocol.contains("BLE");
      }
      return p.protocol.contains("Wi-Fi") || p.protocol.contains("WiFi");
    }));

    // Merge real phone bonded devices if protocol is Bluetooth/BLE
    if (!isWifi) {
      for (var dev in state.bleService.realBondedDevices) {
        if (!matchingProfiles.any((p) => p.macAddress == dev.macAddress)) {
          matchingProfiles.add(DeviceProfile(
            id: dev.id,
            name: dev.name,
            macAddress: dev.macAddress,
            ipAddress: dev.ipAddress,
            protocol: dev.protocol,
            deviceType: dev.deviceType,
            lastConnected: DateTime.now().subtract(const Duration(minutes: 10)),
          ));
        }
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle notch
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),

          // Modal Top Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Icon(
                        isWifi ? Icons.wifi : Icons.bluetooth,
                        color: const Color(0xFF0284C7),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          state.isRadioEnabled ? "Discoverable as mobile phone" : "Radio is turned OFF",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Radio Toggle Switch (like phone settings)
                Switch(
                  value: state.isRadioEnabled,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) => state.toggleRadio(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scan status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (state.isScanning)
                      RotationTransition(
                        turns: _radarController,
                        child: const Icon(Icons.sync, size: 16, color: Color(0xFF0284C7)),
                      )
                    else
                      const Icon(Icons.radar, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      state.isScanning ? "Scanning nearby ${isWifi ? 'networks' : 'devices'}..." : "Scan completed",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: state.isScanning ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: state.isScanning ? null : state.startScanning,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text("Scan Again", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Device Lists
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // SECTION 1: PREVIOUSLY CONNECTED DEVICES (SQLite & Drift)
                _buildSectionHeader(
                  title: "PAIRED PROFILES (SQLite + Drift)",
                  count: matchingProfiles.length,
                  badge: "SQLite Saved",
                ),
                const SizedBox(height: 8),
                if (matchingProfiles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      "No saved profiles found in SQLite for this protocol.\nConnect to a nearby device to save its profile.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  )
                else
                  ...matchingProfiles.map((profile) {
                    final isSelectedTarget = target.id == profile.id;
                    final isLiveConnected = state.currentDevice.id == profile.id && state.currentDevice.isConnected;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLiveConnected
                              ? const Color(0xFF10B981)
                              : (isSelectedTarget ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
                          width: (isLiveConnected || isSelectedTarget) ? 1.5 : 1,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isLiveConnected ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getDeviceIcon(profile.deviceType),
                            color: isLiveConnected ? const Color(0xFF059669) : const Color(0xFF475569),
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLiveConnected) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Text("CONNECTED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              ),
                            ] else if (isSelectedTarget) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBAE6FD)),
                                ),
                                child: const Text("TARGET", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              "${profile.macAddress} • Saved Profile",
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                            ),
                            Text(
                              "Last sync: ${_formatDateTime(profile.lastConnected)}",
                              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: "Forget Profile",
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                state.forgetDevice(profile.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Removed ${profile.name} from SQLite database")),
                                );
                              },
                            ),
                            GestureDetector(
                              onTap: () {
                                final dev = profile.toRoboticDevice();
                                state.selectTargetDevice(dev);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Target set to: ${profile.name}")),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelectedTarget ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isSelectedTarget ? "Selected" : "Select",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelectedTarget ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          final dev = profile.toRoboticDevice();
                          state.selectTargetDevice(dev);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Target set to: ${profile.name}")),
                          );
                        },
                      ),
                    );
                  }),

                const SizedBox(height: 20),

                // SECTION 2: AVAILABLE DEVICES NEARBY (Discovered)
                _buildSectionHeader(
                  title: "AVAILABLE DEVICES NEARBY",
                  count: state.nearbyDiscoveredDevices.length,
                  badge: "In Range",
                ),
                const SizedBox(height: 8),
                ...state.nearbyDiscoveredDevices.map((dev) {
                  final isSelectedTarget = target.id == dev.id;
                  final isLiveConnected = state.currentDevice.id == dev.id && state.currentDevice.isConnected;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelectedTarget ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                        width: isSelectedTarget ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getDeviceIcon(dev.deviceType),
                              color: const Color(0xFF0284C7),
                              size: 20,
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              dev.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${dev.rssi} dBm",
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF059669)),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        "${dev.protocol} • ${dev.macAddress}",
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLiveConnected
                              ? const Color(0xFFDC2626)
                              : (isSelectedTarget ? const Color(0xFF059669) : const Color(0xFF0284C7)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(60, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          state.selectTargetDevice(dev);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Selected and paired ${dev.name}!")),
                          );
                        },
                        child: Text(
                          isLiveConnected ? "Disconnect" : (isSelectedTarget ? "Selected" : "Pair & Select"),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () {
                        state.selectTargetDevice(dev);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Selected and paired ${dev.name}!")),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Bottom Action Bar: Connect Now or Done
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.currentDevice.isConnected ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      if (state.connectionStatus == ConnectionStatus.connected) {
                        state.disconnectDevice();
                      } else {
                        await state.connectToTargetDevice();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.connectionStatus == ConnectionStatus.connected ? Icons.link_off : Icons.link,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.connectionStatus == ConnectionStatus.connected
                              ? "Disconnect Device"
                              : "Connect to ${target.name.split(' ').take(2).join(' ')}",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required int count, required String badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Color(0xFF475569),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$count • $badge",
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else {
      return "${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
  }
}
