import 'package:flutter/material.dart';
import 'package:quepilot_client_01/db/hive_service.dart';
import 'package:quepilot_client_01/screens/splash_screen.dart';
import 'package:quepilot_client_01/services/overlay_service.dart';
import 'package:quepilot_client_01/widgets/global_overlay_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Hive 초기화
  final hiveService = HiveService();
  await hiveService.initHiveManager();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuePilot Client App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(builder: (_) => GlobalOverlayWrapper(child:child!),)
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}
