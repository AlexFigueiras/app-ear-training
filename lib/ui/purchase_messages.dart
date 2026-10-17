import 'dart:async';

import 'package:flutter/material.dart';

import '../services/billing_service.dart';

/// Mostra os avisos da compra da assinatura (aprovada, pendente, recusada) em qualquer tela.
/// A resposta da Play chega depois que a folha do PRO já fechou, às vezes com outra tela aberta.
class PurchaseMessages extends StatefulWidget {
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  const PurchaseMessages(
      {super.key, required this.messengerKey, required this.child});

  @override
  State<PurchaseMessages> createState() => _PurchaseMessagesState();
}

class _PurchaseMessagesState extends State<PurchaseMessages> {
  late final StreamSubscription<String> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = BillingService().messages.listen((message) {
      widget.messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        duration: const Duration(seconds: 6),
      ));
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
