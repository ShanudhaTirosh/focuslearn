import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final problem = config.problem(allowLocalHttp: kDebugMode);
  if (problem != null) {
    runApp(MisconfiguredApp(problem: problem));
    return;
  }
  await Supabase.initialize(url: config.supabaseUrl.trim(), anonKey: config.publishableKey.trim());
  runApp(const ProviderScope(child: FocusLearnApp()));
}
