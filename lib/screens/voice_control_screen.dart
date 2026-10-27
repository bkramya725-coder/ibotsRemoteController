import 'package:flutter/material.dart';
import '../core/models/device_model.dart';
import '../core/state/robot_state.dart';

class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen({super.key});

  @override
  State<VoiceControlScreen> createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen> with SingleTickerProviderStateMixin {
  final RobotState state = RobotState();
  bool isListening = false;
  String recognizedText = "";
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      isListening = !isListening;
    });

    if (isListening) {
      // Simulate recognized command after 2 seconds
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && isListening) {
          final sampleCommands = [
            'Move forward',
            'Turn left',
            'Turn right',
            'Turn on the lights',
            'Start dance mode',
            'Stop the car',
          ];
          final randomCmd = (sampleCommands..shuffle()).first;
          setState(() {
            recognizedText = '“$randomCmd”';
            isListening = false;
          });
          state.addLog(LogType.cmd, 'VOICE RECOGNIZED: $randomCmd');
        }
      });
    }
  }

  void _openVoiceCommandsModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF0F9FF),
                        ),
                        child: const Icon(Icons.record_voice_over, size: 16, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Available Commands',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF1F5F9),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCmdRow('“Move forward”', Icons.arrow_upward, const Color(0xFF0284C7)),
                      _buildCmdRow('“Move backward”', Icons.arrow_downward, const Color(0xFF0284C7)),
                      _buildCmdRow('“Turn left”', Icons.turn_left, const Color(0xFF0284C7)),
                      _buildCmdRow('“Turn right”', Icons.turn_right, const Color(0xFF0284C7)),
                      _buildCmdRow('“Stop the car”', Icons.stop_circle, const Color(0xFFE11D48), isAlert: true),
                      _buildCmdRow('“Turn on the lights”', Icons.lightbulb, const Color(0xFFF59E0B)),
                      _buildCmdRow('“Turn off the lights”', Icons.lightbulb_outline, const Color(0xFF94A3B8)),
                      _buildCmdRow('“Start dance mode”', Icons.celebration, const Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCmdRow(String text, IconData icon, Color iconColor, {bool isAlert = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isAlert ? const Color(0xFFBE123C) : const Color(0xFF1E293B),
            ),
          ),
          Icon(icon, size: 16, color: iconColor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFAF9FA).withOpacity(0.95),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEFEDEE),
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1B1C1D)),
            ),
          ),
        ),
        title: const Text(
          'Voice Control',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 22, color: Color(0xFF334155)),
            onPressed: _openVoiceCommandsModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 'TAP TO SPEAK' Pill
              InkWell(
                onTap: _toggleListening,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isListening) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        isListening ? 'LISTENING...' : 'TAP TO SPEAK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isListening ? const Color(0xFFEF4444) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Waveform bars
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isListening ? 1.0 : 0.0,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final heights = [10.0, 18.0, 24.0, 14.0, 20.0];
                        final h = heights[index] * (0.5 + (_waveController.value * 0.5));
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 4,
                          height: h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              // Large Circular Microphone Button
              InkWell(
                onTap: _toggleListening,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(isListening ? 0.25 : 0.08),
                        blurRadius: isListening ? 36 : 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.mic,
                      size: 68,
                      color: isListening ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Guide Text & Recognition Output
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Text(
                      'Tap the microphone and speak a command.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recognizedText.isEmpty ? '“...”' : recognizedText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: recognizedText.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
