import 'package:flutter/material.dart';

import 'game/game_screen.dart';
import 'game/sfx.dart';
import 'game/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.load();
  final sfx = Sfx()..init();
  runApp(UntangleApp(store: store, sfx: sfx));
}

class UntangleApp extends StatefulWidget {
  final Store store;
  final Sfx sfx;

  const UntangleApp({super.key, required this.store, required this.sfx});

  @override
  State<UntangleApp> createState() => _UntangleAppState();
}

class _UntangleAppState extends State<UntangleApp> {
  late ThemeMode _themeMode = widget.store.themeMode;

  void _toggleTheme(Brightness current) {
    setState(() {
      _themeMode = current == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
    widget.store.themeMode = _themeMode;
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B7B2C),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF13160E)
        : const Color(0xFFEFF1E2),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Untangle',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: GameScreen(
        store: widget.store,
        sfx: widget.sfx,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
