import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'providers/crash_notifier.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'services/notif_svc.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Dark status bar icons
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
    statusBarBrightness:      Brightness.dark,
  ));

  // Notification channels (no background service)
  await NotifSvc.init();

  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (_) => CrashNotifier()),
      ],
      child: MaterialApp(
        title:                     'SOS Guardian',
        debugShowCheckedModeBanner: false,
        theme:                     T.theme,
        home:                      const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    if (s.phase == AppPhase.boot) {
      return const Scaffold(
        backgroundColor: T.bg,
        body: Center(
          child: CircularProgressIndicator(color: T.red),
        ),
      );
    }

    if (s.phase == AppPhase.unregistered) {
      return const RegisterScreen();
    }

    return const HomeScreen();
  }
}
