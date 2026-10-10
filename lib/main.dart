import 'package:flutter/material.dart';
import 'core/armazenamento.dart';
import 'core/lembretes.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Armazenamento.instance.db;
  await Lembretes.instance.inicializar();
  runApp(const PlanoCuidadoApp());
}
