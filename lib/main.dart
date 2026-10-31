import 'dart:async';

import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/material.dart';

import 'data/vault_service.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/unlock_screen.dart';
import 'data/theme_controller.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable(); // usa cifrado nativo (más rápido) si existe
  await vault.init();
  await themeController.load();
  runApp(const BovedaApp());
}

class BovedaApp extends StatelessWidget {
  const BovedaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1E5EFF);
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Bóveda',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorSchemeSeed: seed,
            useMaterial3: true,
            brightness: Brightness.light),
        darkTheme: ThemeData(
            colorSchemeSeed: seed,
            useMaterial3: true,
            brightness: Brightness.dark),
        themeMode: themeController.mode,
        home: const AppRoot(),
      ),
    );
  }
}

/// Decide qué pantalla mostrar y aplica el bloqueo automático.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  static const _idleLimit = Duration(minutes: 5);
  DateTime? _pausedAt;
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vault.addListener(_onVault);
    _resetIdle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    vault.removeListener(_onVault);
    _idle?.cancel();
    super.dispose();
  }

  void _onVault() {
    if (!vault.unlocked) {
      // Al bloquear, cierra cualquier pantalla abierta encima.
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
    }
    _resetIdle();
  }

  void _resetIdle() {
    _idle?.cancel();
    if (vault.unlocked) _idle = Timer(_idleLimit, vault.lock);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!vault.unlocked || vault.externalBusy) return;
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      if (vault.settings.autoLockSeconds == 0) vault.lock();
    } else if (state == AppLifecycleState.resumed) {
      final t = _pausedAt;
      _pausedAt = null;
      if (t != null &&
          DateTime.now().difference(t).inSeconds >=
              vault.settings.autoLockSeconds) {
        vault.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetIdle(),
      child: ListenableBuilder(
        listenable: vault,
        builder: (context, _) {
          if (!vault.hasVault) return const SetupScreen();
          if (!vault.unlocked) return const UnlockScreen();
          return const HomeScreen();
        },
      ),
    );
  }
}
