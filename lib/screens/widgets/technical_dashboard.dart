import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../services/event_buffer.dart';
import '../../services/audio_service_manager.dart';
import 'qa_audio_panel.dart';

class TechnicalDashboard extends StatefulWidget {
  const TechnicalDashboard({super.key});

  @override
  State<TechnicalDashboard> createState() => _TechnicalDashboardState();
}

class _TechnicalDashboardState extends State<TechnicalDashboard> {
  late Timer _ticker;
  double _dspLoad = 0.0;
  int _xRuns = 0;
  int _limiterHits = 0;
  List<String> _pendingFiles = [];
  String _socModel = "Detecting...";

  @override
  void initState() {
    super.initState();
    _loadPendingFiles();
    _loadDeviceInfo();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final engine = AudioServiceManager().engine;
      final native = engine.native; // Acesso direto à ponte FFI
      
      setState(() {
        _dspLoad = native.getDspLoad();
        _xRuns = native.getXRunCount();
        _limiterHits = native.getLimiterHits();
      });
    });
  }

  Future<void> _loadPendingFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().where((f) => f is File && f.path.contains("pending_telemetry_")).cast<File>().toList();
    setState(() {
      _pendingFiles = files.map((f) => f.path.split('/').last).toList();
    });
  }

  Future<void> _loadDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _socModel = "${androidInfo.hardware} | ${androidInfo.board}";
      });
    } else {
      setState(() {
        _socModel = "Desktop Environment";
      });
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("MODO ENGENHEIRO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
            ],
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          
          // SoC Info Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.memory, color: Colors.blueAccent, size: 14),
                const SizedBox(width: 8),
                Text("SoC Hardware: $_socModel", style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Row 1: Hardware Metrics
          Row(
            children: [
              _buildMetricCard("DSP LOAD", "${(_dspLoad * 100).toStringAsFixed(1)}%", _dspLoad > 0.8 ? Colors.redAccent : Colors.greenAccent),
              const SizedBox(width: 8),
              _buildMetricCard("XRUNS", _xRuns.toString(), _xRuns > 0 ? Colors.orangeAccent : Colors.greenAccent),
              const SizedBox(width: 8),
              // Acionamentos do limitador de segurança (-1 dBFS): numa sessão normal deve ficar 0.
              _buildMetricCard("LIMITADOR", _limiterHits.toString(), _limiterHits > 0 ? Colors.orangeAccent : Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 16),
          const QaAudioPanel(),
          const SizedBox(height: 16),
          
          // Row 3: Persistence Sync
          const Text("OFFLINE BACKLOG", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
            child: _pendingFiles.isEmpty 
              ? const Center(child: Text("All Clean (Sync OK)", style: TextStyle(color: Colors.greenAccent, fontSize: 12)))
              : ListView.builder(
                  itemCount: _pendingFiles.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(_pendingFiles[i], style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontFamily: 'monospace')),
                  ),
                ),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await SessionEventBuffer().syncOfflineTelemetry();
                _loadPendingFiles();
              },
              icon: const Icon(Icons.sync_problem),
              label: const Text("FORCE SYNC NOW"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}
