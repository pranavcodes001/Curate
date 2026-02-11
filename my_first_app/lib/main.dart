import 'package:flutter/material.dart';
import 'app.dart';
import 'src/core/state/app_state.dart';
import 'src/core/auth/auth_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent state
  await AppState.instance.init();
  await AuthSession.instance.init();

  runApp(const App());
}
