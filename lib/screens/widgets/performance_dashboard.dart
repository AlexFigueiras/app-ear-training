import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class PerformanceDashboard extends StatelessWidget {
  const PerformanceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("PERFORMANCE TELEMETRY", style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseService().getLatencyEvolution(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyan));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("NO TELEMETRY DATA AVAILABLE", style: TextStyle(color: Colors.white24)));
          }

          final data = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("EVOLUÇÃO DA LATÊNCIA (REACTION TIME)", 
                  style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                Expanded(
                  child: CustomPaint(
                    painter: LinearTrendPainter(data),
                    child: Container(),
                  ),
                ),
                const SizedBox(height: 24),
                _buildStatsRow(data),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    "Nota: Dados de Bluetooth não são comparáveis a fones com fio\ndevido à latência variável do hardware sem fio.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> data) {
    // Cálculo de Melhoria (Senior Fullstack: Redução de latência é progresso)
    final first = data.first['avg_latency'] as double;
    final last = data.last['avg_latency'] as double;
    final improvement = ((first - last) / first * 100).toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stat("BASE", "${first.toInt()}ms"),
        _stat("ATUAL", "${last.toInt()}ms"),
        _stat("PROCESSO", "$improvement%+", color: Colors.greenAccent),
      ],
    );
  }

  Widget _stat(String label, String val, {Color color = Colors.white}) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      Text(val, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
    ],
  );
}

class LinearTrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  LinearTrendPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);
    
    // Escalonamento para o gráfico (Min 0, Max ~1000ms)
    const maxVal = 1000.0;
    
    for (int i = 0; i < data.length; i++) {
      final y = size.height - ((data[i]['avg_latency'] as num).toDouble() / maxVal * size.height);
      final x = i * stepX;
      
      final String hwType = data[i]['output_hardware'] ?? 'unknown';
      final Color dotColor = hwType == 'bluetooth' ? Colors.amberAccent : Colors.greenAccent;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      // Pontos de dados coloridos por hardware
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = dotColor);
    }

    canvas.drawPath(path, paint);
    
    // Grid de fundo utilitária
    final gridPaint = Paint()..color = Colors.white10;
    for (int i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => true;
}
