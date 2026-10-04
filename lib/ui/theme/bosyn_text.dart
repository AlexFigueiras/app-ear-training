import 'package:flutter/material.dart';

/// Tamanhos e estilos de texto do BOSYN.
///
/// O público principal tem perda auditiva relacionada à idade, e muitos usam óculos. Por isso
/// nenhum texto vivo fica abaixo de [minSize] e o corpo usa [body]. As telas reescritas no plano
/// "treino eficaz" usam estes estilos; a varredura final (Etapa 11) troca o resto.
/// Termos de interface em português simples: ver `docs/GLOSSARIO_UI.md`.
class BosynText {
  const BosynText._();

  static const double minSize = 14;

  static const Color primary = Colors.white;
  static const Color secondary = Color(0xFFB8B8C0); // contraste AA sobre #0A0A0A
  static const Color accent = Color(0xFF00FF41);

  static const TextStyle title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primary);
  static const TextStyle heading = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary);
  static const TextStyle body = TextStyle(fontSize: 16, color: primary, height: 1.4);
  static const TextStyle bodySecondary = TextStyle(fontSize: 16, color: secondary, height: 1.4);
  static const TextStyle caption = TextStyle(fontSize: minSize, color: secondary);
  static const TextStyle button = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const TextStyle answer = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: primary);
}
