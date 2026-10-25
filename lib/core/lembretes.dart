import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'armazenamento.dart';
import 'plano.dart';

class Lembretes {
  Lembretes._() : plugin = FlutterLocalNotificationsPlugin();
  Lembretes.testing(this.plugin);
  static Lembretes _instance = Lembretes._();
  static Lembretes get instance => _instance;
  @visibleForTesting
  static void configurarParaTestes(FlutterLocalNotificationsPlugin plugin) {
    _instance = Lembretes.testing(plugin);
  }

  final FlutterLocalNotificationsPlugin plugin;

  Future<void> inicializar() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    await plugin.initialize(
      const InitializationSettings(
        iOS: IOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<bool> pedirPermissao() async =>
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true) ??
      false;

  /// Reconstrói até 60 avisos futuros no fuso America/Sao_Paulo.
  /// Sem reposição em background: a janela avança nas chamadas do aplicativo.
  Future<void> reagendar(Plano? plano, {bool ativo = true}) async {
    await plugin.cancelAll();
    if (!ativo || plano == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.isAfter(plano.inicio) ? today : plano.inicio;
    final sent = await Armazenamento.instance.ultimoEnvio(plano.id);
    final candidates = <({DateTime at, String title, String body, int id})>[];
    var serial = 100;
    for (final meta in plano.metas) {
      final customized = await Armazenamento.instance.config(
        'horarios_meta_${meta['id']}',
      );
      final hours = customized == null
          ? (meta['lembretes'] as List? ?? const [])
                .whereType<String>()
                .toList()
          : (jsonDecode(customized) as List).whereType<String>().toList();
      for (final hour in hours) {
        final p = hour.split(':');
        if (p.length != 2) continue;
        final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
        if (h == null || m == null || h > 23 || m > 59) continue;
        for (final day in diasDoPlano(from, plano.fim)) {
          candidates.add((
            at: DateTime(day.year, day.month, day.day, h, m),
            title: meta['titulo'] as String,
            body: 'Lembrete do seu plano de cuidado.',
            id: serial++,
          ));
        }
      }
    }
    for (final meal in plano.refeicoesPrescritas) {
      final parts = (meal['horario'] as String).split(':');
      for (final day in diasDoPlano(from, plano.fim)) {
        candidates.add((
          at: DateTime(
            day.year,
            day.month,
            day.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          ),
          title: meal['titulo'] as String,
          body: meal['regra'] == 'condicional'
              ? 'Confira a refeição e a condição de dispensa do seu plano.'
              : 'Confira a refeição prescrita e registre se fez.',
          id: serial++,
        ));
      }
    }
    final alimentacao = plano.alimentacao;
    if (alimentacao != null) {
      for (final meal in alimentacao.refeicoes) {
        final hour = meal.horario;
        if (hour == null) continue;
        final p = hour.split(':');
        final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
        if (h == null || m == null) continue;
        for (final day in diasDoPlano(from, plano.fim)) {
          candidates.add((
            at: DateTime(day.year, day.month, day.day, h, m),
            title: meal.titulo,
            body: 'Confira a refeição prevista na sua rotina alimentar.',
            id: serial++,
          ));
        }
      }
    }
    final weekly = plano.data['envioSemanal'] as Map?;
    if (weekly != null) {
      final limit = (weekly['ate'] as String? ?? '18:00').split(':');
      final hour = int.tryParse(limit.first) ?? 18;
      final minute = int.tryParse(limit.length > 1 ? limit[1] : '0') ?? 0;
      for (final day in diasDoPlano(from, plano.fim)) {
        if (day.weekday % 7 != weekly['diaDaSemana']) continue;
        if (sent != null && !day.isAfter(Plano.parseDia(sent))) continue;
        final at = DateTime(
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        ).subtract(const Duration(hours: 1));
        candidates.add((
          at: at,
          title: 'Enviar semana',
          body: plano.data['versao'] == 4
              ? 'Exporte e envie o acompanhamento à médica até as ${weekly['ate'] ?? '18:00'}.'
              : 'Hoje é dia de mandar a sua semana até as ${weekly['ate'] ?? '18:00'}.',
          id: serial++,
        ));
      }
    }
    if (plano.data['versao'] == 4 &&
        (sent == null || Plano.parseDia(sent).isBefore(plano.fim))) {
      candidates.add((
        at: DateTime(plano.fim.year, plano.fim.month, plano.fim.day, 18),
        title: 'Enviar acompanhamento final',
        body:
            'Exporte o acompanhamento em .plano e envie à médica antes do retorno.',
        id: serial++,
      ));
    }
    final eve = plano.retorno.subtract(const Duration(days: 1));
    candidates.add((
      at: DateTime(eve.year, eve.month, eve.day, 18),
      title: 'Retorno amanhã',
      body:
          'Amanhã é o seu retorno, às ${plano.data['retorno']['hora'] ?? 'horário combinado'}.',
      id: serial++,
    ));
    final future = candidates.where((c) => c.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    // iOS allows only 64 pending requests. Rebuild a rolling window on each launch.
    for (final item in future.take(60)) {
      await plugin.zonedSchedule(
        item.id,
        item.title,
        item.body,
        tz.TZDateTime.from(item.at, tz.local),
        const NotificationDetails(
          iOS: IOSNotificationDetails(presentAlert: true, presentSound: true),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
      );
    }
  }
}
