import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/app.dart';
import 'package:centavoo/data/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(CentavooApp(
    database: AppDatabase(),
    loadSeedJson: () => rootBundle.loadString('assets/europa.json'),
  ));
}
