import 'package:flutter/widgets.dart';

import '../services/audio_service_manager.dart';

/// Silencia todo o áudio quando o app sai da frente (segundo plano, tela bloqueada, outra app
/// por cima). Sem isso, um estímulo ou o ruído do Coquetel continuava tocando fora do app.
class AudioLifecycleGuard extends StatefulWidget {
  final Widget child;

  const AudioLifecycleGuard({super.key, required this.child});

  @override
  State<AudioLifecycleGuard> createState() => _AudioLifecycleGuardState();
}

class _AudioLifecycleGuardState extends State<AudioLifecycleGuard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      AudioServiceManager().silenceAll();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
