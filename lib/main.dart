import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/audio_service.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/save_service.dart';
import 'theme.dart';
import 'ui/screens/title_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SaveService.instance.init();
  await AudioService.instance.init();
  await NotificationService.instance.init();
  // Cloud layer is optional — never block launch on it.
  // ignore: unawaited_futures
  FirebaseService.instance.init();
  runApp(const DeathNoteApp());
}

class DeathNoteApp extends StatelessWidget {
  const DeathNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Death Note',
      debugShowCheckedModeBanner: false,
      theme: buildNotebookTheme(),
      home: const TitleScreen(),
    );
  }
}
