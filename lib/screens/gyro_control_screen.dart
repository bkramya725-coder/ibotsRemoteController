import 'package:flutter/material.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class GyroControlScreen extends StatefulWidget {
  const GyroControlScreen({super.key});

  @override
  State<GyroControlScreen> createState() => _GyroControlScreenState();
}

class _GyroControlScreenState extends State<GyroControlScreen> {
  final RobotState state = RobotState();
  double pitch = -8.0;
  double roll = 4.8;
  double yaw = 86.0;
  double steeringSensitivity = 1.5; // 0.5x to 3.0x multiplier

  void _calibrateZero() {
    setState(() {
      pitch = 0.0;
      roll = 0.0;
    });
    state.addLog(LogType.cmd, 'GYRO: CALIBRATED NEUTRAL ZERO');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Neutral orientation calibrated to 0.0°'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _setSensitivity(double val) {
    setState(() {
      steeringSensitivity = double.parse(val.toStringAsFixed(1));
    });
    state.gyroSensitivity = steeringSensitivity;
    state.addLog(LogType.cmd, 'GYRO: SENSITIVITY ${steeringSensitivity.toStringAsFixed(1)}x');
  }

  String get _sensitivityLabel {
    if (steeringSensitivity <= 1.0) {
      return '${steeringSensitivity.toStringAsFixed(1)}x (Low)';
    } else if (steeringSensitivity <= 1.8) {
      return '${steeringSensitivity.toStringAsFixed(1)}x (Medium)';
    } else {
      return '${steeringSensitivity.toStringAsFixed(1)}x (High)';
    }
  }

  Widget _buildPresetButton(double val, String title, String multiplier) {
    final isSelected = (steeringSensitivity - val).abs() < 0.15;
    return InkWell(
      onTap: () => _setSensitivity(val),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              multiplier,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0.95),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F5F9),
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF334155)),
            ),
          ),
        ),
        title: const Text(
          'Gyro Control',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: InkWell(
              onTap: _calibrateZero,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.restart_alt, size: 15, color: Color(0xFF475569)),
                    SizedBox(width: 4),
                    Text(
                      'Center All',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [


              // 3. Interactive Gimbal & Attitude Visualizer Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.explore, size: 16, color: Color(0xFF94A3B8)),
                            SizedBox(width: 6),
                            Text(
                              'Attitude Matrix',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ROLL',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PITCH',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Virtual Gimbal Horizon Ring Container
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Compass Ring
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            ),
                          ),
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                            ),
                          ),
                          // Crosshair lines
                          Container(width: 180, height: 1, color: const Color(0xFFE2E8F0)),
                          Container(width: 1, height: 180, color: const Color(0xFFE2E8F0)),

                          // Direction Pointers
                          const Positioned(top: 4, child: Text('FWD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8)))),
                          const Positioned(bottom: 4, child: Text('REV', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8)))),
                          const Positioned(left: 6, child: Text('L', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8)))),
                          const Positioned(right: 6, child: Text('R', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8)))),

                          // Stylized 3D Phone Model / Silhouette Layer
                          Transform.rotate(
                            angle: (roll * 3.14159 / 180.0),
                            child: Container(
                              width: 90,
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF020617),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF020617),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.adjust, size: 28, color: Color(0xFF38BDF8)),
                                        SizedBox(height: 4),
                                        Text(
                                          'IMU 6-DOF',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7DD3FC),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF475569),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Live Axis Value Readouts (Bento Row)
                    Row(
                      children: [
                        // Pitch Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text('Pitch (X)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 2),
                                Text(
                                  '${pitch.toStringAsFixed(1)}°',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                const Text('▲ FWD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Roll Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text('Roll (Y)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 2),
                                Text(
                                  '+${roll.toStringAsFixed(1)}°',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                const Text('◄ LEFT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Yaw Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text('Yaw (Z)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 2),
                                Text(
                                  '${yaw.toStringAsFixed(1)}°',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                const Text('➤ EAST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Tuning & Calibration Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune, size: 18, color: Color(0xFF0284C7)),
                            SizedBox(width: 8),
                            Text(
                              'Steering Sensitivity',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _sensitivityLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                      ),
                      child: Slider(
                        value: steeringSensitivity.clamp(0.5, 3.0),
                        min: 0.5,
                        max: 3.0,
                        divisions: 25,
                        activeColor: const Color(0xFF0284C7),
                        inactiveColor: const Color(0xFFE2E8F0),
                        onChanged: (val) => _setSensitivity(val),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick-Select Sensitivity Preset Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildPresetButton(0.8, 'Low', '0.8x'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPresetButton(1.5, 'Medium', '1.5x'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPresetButton(2.4, 'High', '2.4x'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _calibrateZero,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.my_location, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text(
                              'Calibrate Neutral Zero',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
