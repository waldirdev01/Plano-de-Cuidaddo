import 'package:flutter/services.dart';

// Manter o nome igual ao canal no AppDelegate.swift e aos mocks de interface.
const incomingFiles = EventChannel(
  'br.com.waldirdev01.plano_cuidado/incoming-files',
);
