import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF7C5CFF);     // morado principal
  static const Color primaryDark = Color(0xFF5B3FD9); // morado del gradiente
  static const Color pink = Color(0xFFEC4899);        // rosa (perfil)
  static const Color cyan = Color(0xFF00D4FF);        // cyan acento
  static const Color textDark = Color(0xFF0F172A);    // texto oscuro

  // Prioridades (exactas de tu guía)
  static const Color alta = Color(0xFFEF4444);  // rojo
  static const Color media = Color(0xFFF59E0B); // ámbar
  static const Color baja = Color(0xFF10B981);  // verde esmeralda

  // Gradientes
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient profileGradient = LinearGradient(
    colors: [primary, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Pantalla Asistente IA (mockup 03 · fondo oscuro)
  static const Color violetLight = Color(0xFFA78BFA);
  static const Color aiDarkTop = Color(0xFF0F0A2E);
  static const Color aiDarkMid = Color(0xFF1A1147);
  static const Color aiDarkBottom = Color(0xFF2D1B69);

  static const LinearGradient aiBackgroundGradient = LinearGradient(
    colors: [aiDarkTop, aiDarkMid, aiDarkBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient voiceGradient = LinearGradient(
    colors: [primary, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aiTitleGradient = LinearGradient(
    colors: [primary, cyan, pink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}