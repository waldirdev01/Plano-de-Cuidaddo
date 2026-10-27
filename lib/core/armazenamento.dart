import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'importacao_pdf.dart';
import 'plano.dart';
import 'pre_consulta.dart';
import 'retorno_acompanhamento.dart';

/// A person in the professional's local history, keyed by name + birth date.
class PacienteHistorico {
  const PacienteHistorico({
    required this.id,
    required this.nome,
    required this.nascimento,
    required this.atualizadoEm,
  });
  final String id;
  final String nome;
  final String nascimento;
  final DateTime atualizadoEm;

  /// Same identity rule the app uses to check a file's recipient.
  static String chave(String nome, String nascimento) =>
      '${PerfilPaciente.normalizarNome(nome)}|$nascimento';
}

class AcompanhamentoGuardado {
  const AcompanhamentoGuardado(this.plano, this.estado);
  final Plano plano;
  final String estado;
}

/// Persistência local: seleção em config, estado em planos e registros por ID.
/// Alterações de esquema exigem migração; veja docs/arquitetura.md.
class Armazenamento {
  Armazenamento._() : rascunhosPdf = ArquivosRascunhoPdf();
  Armazenamento.testing(this._db, {this.rascunhosPdf});

  /// PDF drafts live in files, not SQLite; the backup carries them too.
  /// Null in tests that do not exercise drafts.
  final ArquivosRascunhoPdf? rascunhosPdf;
  static final Armazenamento instance = Armazenamento._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    _db = await openDatabase(
      '${dir.path}/plano_de_cuidado.db',
      version: 3,
      onCreate: (db, _) => criarEsquema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE planos ADD COLUMN estado TEXT NOT NULL DEFAULT 'em_andamento'",
          );
        }
        if (oldVersion < 3) await criarHistorico(db);
      },
    );
    return _db!;
  }

  static Future<void> criarEsquema(DatabaseExecutor db) async {
    await db.execute(
      "CREATE TABLE planos(id TEXT PRIMARY KEY, json TEXT NOT NULL, status TEXT NOT NULL, origem TEXT NOT NULL, atualizado_em TEXT NOT NULL, estado TEXT NOT NULL DEFAULT 'em_andamento')",
    );
    await db.execute(
      'CREATE TABLE registros(plano_id TEXT NOT NULL, data TEXT NOT NULL, campo_id TEXT NOT NULL, valor TEXT NOT NULL, atualizado_em TEXT NOT NULL, PRIMARY KEY(plano_id,data,campo_id))',
    );
    await db.execute(
      'CREATE TABLE envios(id INTEGER PRIMARY KEY AUTOINCREMENT, plano_id TEXT NOT NULL, enviado_em TEXT NOT NULL, de TEXT NOT NULL, ate TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE config(chave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
    );
    await criarHistorico(db);
  }

  /// Version 3, additive: the professional's patient history.
  static Future<void> criarHistorico(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE pacientes(id TEXT PRIMARY KEY, chave TEXT NOT NULL UNIQUE, nome TEXT NOT NULL, nascimento TEXT NOT NULL, criado_em TEXT NOT NULL, atualizado_em TEXT NOT NULL)',
    );
    for (final tabela in ['pre_consultas', 'reavaliacoes']) {
      await db.execute(
        'CREATE TABLE $tabela(id TEXT PRIMARY KEY, paciente_id TEXT NOT NULL, recebida_em TEXT NOT NULL, json TEXT NOT NULL)',
      );
    }
  }

  Future<String?> config(String key) async =>
      (await (await db).query(
            'config',
            where: 'chave=?',
            whereArgs: [key],
            limit: 1,
          )).firstOrNull?['valor']
          as String?;
  Future<void> setConfig(String key, String value) async => (await db).insert(
    'config',
    {'chave': key, 'valor': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  Future<void> removerConfig(String key) async =>
      (await db).delete('config', where: 'chave=?', whereArgs: [key]);
  Future<String?> papel() => config('papel');

  /// Received snapshots live separately from patient plans and daily records.
  /// Config is already included in backups; no destructive schema change.
  Future<bool> guardarRetorno(RetornoAcompanhamento retorno) async {
    final validado = RetornoAcompanhamento.parse(jsonEncode(retorno.data));
    validado.conferirProfissional(
      await config('profissional_nome') ?? '',
      await config('profissional_registro') ?? '',
    );
    final chave = 'retorno_recebido_${retorno.id}';
    final json = jsonEncode(validado.data);
    return (await db).transaction((txn) async {
      final existente = await txn.query(
        'config',
        where: 'chave=?',
        whereArgs: [chave],
      );
      if (existente.isNotEmpty) {
        if (existente.single['valor'] != json) {
          throw const FormatException(
            'Já existe outro conteúdo com o mesmo identificador. Nada foi substituído.',
          );
        }
        return false;
      }
      await txn.insert('config', {'chave': chave, 'valor': json});
      return true;
    });
  }

  /// Files a received pre-consultation under its patient, creating the entry.
  /// Returns false when the same file was already received.
  Future<bool> guardarPreConsulta(PreConsulta p, {DateTime? agora}) async {
    final validado = PreConsulta.parse(jsonEncode(p.data), agora: agora);
    return _guardarNoHistorico(
      'pre_consultas',
      validado.id,
      validado.nomePaciente,
      validado.nascimentoPaciente,
      jsonEncode(validado.data),
      agora ?? DateTime.now(),
    );
  }

  Future<bool> guardarReavaliacao(Reavaliacao r, {DateTime? agora}) async {
    final validado = Reavaliacao.parse(jsonEncode(r.data), agora: agora);
    return _guardarNoHistorico(
      'reavaliacoes',
      validado.id,
      validado.nomePaciente,
      validado.nascimentoPaciente,
      jsonEncode(validado.data),
      agora ?? DateTime.now(),
    );
  }

  Future<bool> _guardarNoHistorico(
    String tabela,
    String id,
    String nome,
    String nascimento,
    String json,
    DateTime agora,
  ) async => (await db).transaction((txn) async {
    final existente = await txn.query(tabela, where: 'id=?', whereArgs: [id]);
    if (existente.isNotEmpty) {
      if (existente.single['json'] != json) {
        throw const FormatException(
          'Já existe outro conteúdo com o mesmo identificador. Nada foi substituído.',
        );
      }
      return false;
    }
    final quando = agora.toIso8601String();
    final chave = PacienteHistorico.chave(nome, nascimento);
    final paciente = await txn.query(
      'pacientes',
      where: 'chave=?',
      whereArgs: [chave],
    );
    final String pacienteId;
    if (paciente.isEmpty) {
      pacienteId = novoIdEnvelope();
      await txn.insert('pacientes', {
        'id': pacienteId,
        'chave': chave,
        'nome': nome.trim(),
        'nascimento': nascimento,
        'criado_em': quando,
        'atualizado_em': quando,
      });
    } else {
      pacienteId = paciente.single['id'] as String;
      await txn.update(
        'pacientes',
        {'nome': nome.trim(), 'atualizado_em': quando},
        where: 'id=?',
        whereArgs: [pacienteId],
      );
    }
    await txn.insert(tabela, {
      'id': id,
      'paciente_id': pacienteId,
      'recebida_em': quando,
      'json': json,
    });
    return true;
  });

  /// Most recently updated first.
  Future<List<PacienteHistorico>> pacientes() async {
    final rows = await (await db).query(
      'pacientes',
      orderBy: 'atualizado_em DESC',
    );
    return [
      for (final r in rows)
        PacienteHistorico(
          id: r['id'] as String,
          nome: r['nome'] as String,
          nascimento: r['nascimento'] as String,
          atualizadoEm: DateTime.parse(r['atualizado_em'] as String),
        ),
    ];
  }

  /// Newest first.
  Future<List<PreConsulta>> preConsultasDoPaciente(String pacienteId) async => [
    for (final r in await (await db).query(
      'pre_consultas',
      where: 'paciente_id=?',
      whereArgs: [pacienteId],
      orderBy: 'recebida_em DESC',
    ))
      PreConsulta.parse(r['json'] as String),
  ];

  Future<List<Reavaliacao>> reavaliacoesDoPaciente(String pacienteId) async => [
    for (final r in await (await db).query(
      'reavaliacoes',
      where: 'paciente_id=?',
      whereArgs: [pacienteId],
      orderBy: 'recebida_em DESC',
    ))
      Reavaliacao.parse(r['json'] as String),
  ];

  Future<List<RetornoAcompanhamento>> retornosRecebidos() async {
    final nome = await config('profissional_nome') ?? '';
    final registro = await config('profissional_registro') ?? '';
    final rows = await (await db).query(
      'config',
      where: 'chave LIKE ?',
      whereArgs: ['retorno_recebido_%'],
    );
    final retornos = <RetornoAcompanhamento>[];
    for (final row in rows) {
      final r = RetornoAcompanhamento.parse(row['valor'] as String);
      try {
        r.conferirProfissional(nome, registro);
        retornos.add(r);
      } on FormatException {
        // A changed professional profile must not show another recipient's data.
      }
    }
    retornos.sort((a, b) => b.exportadoEm.compareTo(a.exportadoEm));
    return retornos;
  }

  String _chaveAlimentacao(String planoId, String dia) =>
      'alimentacao_selecoes_${planoId}_$dia';

  Future<Map<String, String>> selecoesAlimentacao(
    String planoId,
    String dia,
  ) async {
    final raw = await config(_chaveAlimentacao(planoId, dia));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> salvarSelecoesAlimentacao(
    String planoId,
    String dia,
    Map<String, String> selecoes,
  ) => setConfig(_chaveAlimentacao(planoId, dia), jsonEncode(selecoes));

  Future<void> limparSelecoesAlimentacao(String planoId, String dia) async =>
      (await db).delete(
        'config',
        where: 'chave=?',
        whereArgs: [_chaveAlimentacao(planoId, dia)],
      );

  Future<PerfilPaciente?> perfilPaciente() async {
    final raw = await config('perfil_paciente');
    return raw == null
        ? null
        : PerfilPaciente.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> salvarPerfilPaciente(PerfilPaciente perfil) =>
      setConfig('perfil_paciente', jsonEncode(perfil.toJson()));

  Future<void> conferirDestinatario(Plano plano) async {
    final perfil = await perfilPaciente();
    if (perfil == null) {
      throw const FormatException(
        'Cadastre seu nome completo e nascimento antes de importar um plano.',
      );
    }
    perfil.conferir(plano);
  }

  Future<List<Map<String, Object?>>> planos({String? status}) async =>
      (await db).query(
        'planos',
        where: status == null ? null : 'status=?',
        whereArgs: status == null ? null : [status],
        orderBy: 'atualizado_em DESC',
      );

  Future<List<Map<String, Object?>>> planosEncerrados() async =>
      (await db).query(
        'planos',
        where: 'estado=? AND origem=?',
        whereArgs: ['encerrado', 'importado'],
        orderBy: 'atualizado_em DESC',
      );
  Future<Plano?> planoAtivo() async {
    final d = await db;
    var id = await config('acompanhamento_selecionado');
    if (id == null) {
      // Recover the selection from databases created by the earlier version.
      final legacy = await d.query(
        'planos',
        where: 'status=? AND origem=?',
        whereArgs: ['ativo', 'importado'],
        orderBy: 'atualizado_em DESC',
        limit: 1,
      );
      if (legacy.isEmpty) return null;
      id = legacy.single['id']! as String;
      await setConfig('acompanhamento_selecionado', id);
    }
    final rows = await d.query('planos', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty || rows.single['estado'] == 'encerrado') return null;
    return Plano.parse(rows.single['json']! as String);
  }

  /// All plans received on this device, including archived ones. Their
  /// records remain keyed by plan id, so switching never mixes histories.
  Future<List<Plano>> planosPaciente() async {
    return (await acompanhamentosPaciente()).map((item) => item.plano).toList();
  }

  Future<List<AcompanhamentoGuardado>> acompanhamentosPaciente() async {
    final perfil = await perfilPaciente();
    if (perfil == null) return [];
    final rows = await (await db).query(
      'planos',
      where: 'origem=?',
      whereArgs: ['importado'],
      orderBy: 'atualizado_em DESC',
    );
    return rows
        .map(
          (r) => AcompanhamentoGuardado(
            Plano.parse(r['json']! as String),
            r['estado']! as String,
          ),
        )
        .where((item) => perfil.corresponde(item.plano))
        .toList();
  }

  Future<String> estadoAcompanhamento(String id) async {
    final rows = await (await db).query(
      'planos',
      columns: ['estado'],
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? 'encerrado' : rows.single['estado']! as String;
  }

  Future<void> encerrarAcompanhamento(String id) async {
    final d = await db;
    final rows = await d.query(
      'planos',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty || rows.single['origem'] != 'importado') {
      throw const FormatException('Este acompanhamento não está disponível.');
    }
    await conferirDestinatario(Plano.parse(rows.single['json']! as String));
    await d.update(
      'planos',
      {
        'estado': 'encerrado',
        'atualizado_em': DateTime.now().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> reativarAcompanhamento(String id) async {
    final rows = await (await db).query(
      'planos',
      where: 'id=?',
      whereArgs: [id],
    );
    if (rows.isEmpty || rows.single['origem'] != 'importado') {
      throw const FormatException('Este acompanhamento não está disponível.');
    }
    await conferirDestinatario(Plano.parse(rows.single['json']! as String));
    await (await db).update(
      'planos',
      {
        'estado': 'em_andamento',
        'atualizado_em': DateTime.now().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> selecionarPlano(String id) async {
    final d = await db;
    await d.transaction((txn) async {
      final rows = await txn.query('planos', where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty || rows.single['origem'] != 'importado') {
        throw const FormatException('Este plano não está disponível.');
      }
      final plano = Plano.parse(rows.single['json']! as String);
      final settings = await txn.query(
        'config',
        where: 'chave=?',
        whereArgs: ['perfil_paciente'],
      );
      if (settings.isEmpty) {
        throw const FormatException(
          'Cadastre seu nome completo e nascimento antes de abrir um plano.',
        );
      }
      PerfilPaciente.fromJson(
        jsonDecode(settings.single['valor']! as String) as Map<String, dynamic>,
      ).conferir(plano);
      if (rows.single['estado'] == 'encerrado') {
        throw const FormatException(
          'Reative este acompanhamento antes de selecioná-lo.',
        );
      }
      await txn.insert('config', {
        'chave': 'acompanhamento_selecionado',
        'valor': id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> salvarCriado(Plano plano) async {
    // Validate before writing and retain patient status/notes when editing an export.
    Plano.parse(jsonEncode(plano.data));
    await (await db).transaction((txn) async {
      final existing = await txn.query(
        'planos',
        where: 'id=?',
        whereArgs: [plano.id],
      );
      if (existing.isEmpty) {
        await txn.insert('planos', {
          'id': plano.id,
          'json': jsonEncode(plano.data),
          'status': 'rascunho',
          'origem': 'criado',
          'atualizado_em': DateTime.now().toIso8601String(),
        });
      } else {
        await txn.update(
          'planos',
          {
            'json': jsonEncode(plano.data),
            'origem': 'criado',
            'atualizado_em': DateTime.now().toIso8601String(),
          },
          where: 'id=?',
          whereArgs: [plano.id],
        );
      }
    });
  }

  Future<List<Plano>> planosCriados() async => (await (await db).query(
    'planos',
    where: 'origem=?',
    whereArgs: ['criado'],
    orderBy: 'atualizado_em DESC',
  )).map((r) => Plano.parse(r['json'] as String)).toList();

  Future<void> importar(Plano plano) async {
    Plano.parse(jsonEncode(plano.data));
    final d = await db;
    await d.transaction((txn) async {
      // Check again in the transaction, before any plan or notes are changed.
      final settings = await txn.query(
        'config',
        where: 'chave=?',
        whereArgs: ['perfil_paciente'],
      );
      if (settings.isEmpty) {
        throw const FormatException(
          'Cadastre seu nome completo e nascimento antes de importar um plano.',
        );
      }
      PerfilPaciente.fromJson(
        jsonDecode(settings.single['valor'] as String) as Map<String, dynamic>,
      ).conferir(plano);
      final same = await txn.query(
        'planos',
        where: 'id=?',
        whereArgs: [plano.id],
        limit: 1,
      );
      if (same.isNotEmpty) {
        // Same-id reimport refreshes the plan and preserves records.
        await txn.update(
          'planos',
          {
            'json': jsonEncode(plano.data),
            'status': 'ativo',
            'origem': 'importado',
            'estado': 'em_andamento',
            'atualizado_em': DateTime.now().toIso8601String(),
          },
          where: 'id=?',
          whereArgs: [plano.id],
        );
        await txn.insert('config', {
          'chave': 'acompanhamento_selecionado',
          'valor': plano.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return;
      }
      await txn.insert('planos', {
        'id': plano.id,
        'json': jsonEncode(plano.data),
        'status': 'ativo',
        'origem': 'importado',
        'atualizado_em': DateTime.now().toIso8601String(),
      });
      await txn.insert('config', {
        'chave': 'acompanhamento_selecionado',
        'valor': plano.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Map<String, dynamic>> registros(String planoId, String day) async {
    final rows = await (await db).query(
      'registros',
      where: 'plano_id=? AND data=?',
      whereArgs: [planoId, day],
    );
    return {
      for (final r in rows)
        r['campo_id']! as String: jsonDecode(r['valor']! as String),
    };
  }

  Future<Map<String, Map<String, dynamic>>> registrosPeriodo(
    String planoId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await (await db).query(
      'registros',
      where: 'plano_id=? AND data>=? AND data<=?',
      whereArgs: [planoId, Plano.formatDia(from), Plano.formatDia(to)],
    );
    final result = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      (result[row['data']! as String] ??= {})[row['campo_id']! as String] =
          jsonDecode(row['valor']! as String);
    }
    return result;
  }

  Future<void> salvarRegistro(
    String planId,
    String day,
    String fieldId,
    Object? value,
  ) async => (await db).insert('registros', {
    'plano_id': planId,
    'data': day,
    'campo_id': fieldId,
    'valor': jsonEncode(value),
    'atualizado_em': DateTime.now().toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<String?> ultimoEnvio(String planId) async {
    final rows = await (await db).query(
      'envios',
      where: 'plano_id=?',
      whereArgs: [planId],
      orderBy: 'enviado_em DESC',
      limit: 1,
    );
    return rows.firstOrNull?['ate'] as String?;
  }

  Future<void> registrarEnvio(
    String id,
    DateTime sent,
    DateTime from,
    DateTime to,
  ) async => (await db).insert('envios', {
    'plano_id': id,
    'enviado_em': sent.toIso8601String(),
    'de': Plano.formatDia(from),
    'ate': Plano.formatDia(to),
  });

  Future<String> backupConteudo() async {
    final d = await db;
    final allPlans = await d.query('planos');
    final entries = <Map<String, dynamic>>[];
    for (final p in allPlans) {
      final records = await d.query(
        'registros',
        where: 'plano_id=?',
        whereArgs: [p['id']],
      );
      final sends = await d.query(
        'envios',
        where: 'plano_id=?',
        whereArgs: [p['id']],
      );
      entries.add({
        ...p,
        'registros': records
            .map((r) => {...r, 'valor': jsonDecode(r['valor']! as String)})
            .toList(),
        'envios': sends,
      });
    }
    final settings = await d.query('config');
    return jsonEncode({
      'formato': 'plano-de-cuidado-backup',
      'versao': 1,
      'planos': entries,
      'config': settings,
      // Optional keys: older apps ignore them, older backups lack them.
      'pacientes': await d.query('pacientes'),
      'preConsultas': await d.query('pre_consultas'),
      'reavaliacoes': await d.query('reavaliacoes'),
      if (rascunhosPdf != null)
        'rascunhosPdf': await rascunhosPdf!.paraBackup(),
    });
  }

  static (String, String, String) _identidadeNoHistorico(
    String tabela,
    String json,
  ) {
    if (tabela == 'pre_consultas') {
      final p = PreConsulta.parse(json);
      return (p.id, p.nomePaciente, p.nascimentoPaciente);
    }
    final r = Reavaliacao.parse(json);
    return (r.id, r.nomePaciente, r.nascimentoPaciente);
  }

  Future<File> backup() async {
    final source = await backupConteudo();
    final dir = await getTemporaryDirectory();
    return File(
      '${dir.path}/plano-backup-${DateTime.now().millisecondsSinceEpoch}.plano-backup',
    ).writeAsString(source);
  }

  Future<void> restaurar(String source) async {
    final value = jsonDecode(source);
    if (value is! Map ||
        value['formato'] != 'plano-de-cuidado-backup' ||
        value['versao'] != 1 ||
        value['planos'] is! List) {
      throw const FormatException(
        'Este arquivo de cópia de segurança é inválido.',
      );
    }
    // A backup must not silently replace an already registered recipient.
    final atual = await perfilPaciente();
    if (atual != null) {
      final configs = value['config'] as List;
      final dados = configs
          .where((r) => r['chave'] == 'perfil_paciente')
          .toList();
      if (dados.isEmpty) {
        throw const FormatException(
          'A cópia não tem o cadastro do paciente. Nada foi restaurado.',
        );
      }
      final outro = PerfilPaciente.fromJson(
        jsonDecode(dados.single['valor'] as String) as Map<String, dynamic>,
      );
      if (PerfilPaciente.normalizarNome(atual.nome) !=
              PerfilPaciente.normalizarNome(outro.nome) ||
          atual.nascimento != outro.nascimento) {
        throw const FormatException(
          'Esta cópia não corresponde ao seu cadastro. Nada foi restaurado.',
        );
      }
    }
    // Check the drafts before touching the database, so a damaged one
    // leaves everything as it was.
    final rascunhos = value['rascunhosPdf'] as List?;
    if (rascunhos != null) {
      for (final r in rascunhos) {
        ArquivosRascunhoPdf.validarParaRestaurar(r);
      }
    }
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('planos');
      await txn.delete('registros');
      await txn.delete('envios');
      await txn.delete('config');
      for (final tabela in ['pacientes', 'pre_consultas', 'reavaliacoes']) {
        await txn.delete(tabela);
      }
      for (final raw in value['planos']) {
        final p = raw as Map;
        final plano = Plano.parse(jsonEncode(jsonDecode(p['json'] as String)));
        await txn.insert('planos', {
          'id': plano.id,
          'json': jsonEncode(plano.data),
          'status': p['status'],
          'origem': p['origem'],
          'atualizado_em': p['atualizado_em'],
          'estado': p['estado'] ?? 'em_andamento',
        });
        for (final row in p['registros'] as List) {
          final r = row as Map;
          await txn.insert('registros', {
            'plano_id': r['plano_id'],
            'data': r['data'],
            'campo_id': r['campo_id'],
            'valor': jsonEncode(r['valor']),
            'atualizado_em': r['atualizado_em'],
          });
        }
        for (final row in p['envios'] as List) {
          await txn.insert(
            'envios',
            Map<String, Object?>.from(row as Map)..remove('id'),
          );
        }
      }
      for (final row in value['config'] as List) {
        await txn.insert('config', Map<String, Object?>.from(row as Map));
      }
      final pacientes = {
        for (final row in value['pacientes'] as List? ?? const [])
          (row as Map)['id'] as String: row,
      };
      for (final row in pacientes.values) {
        final nome = row['nome'] as String,
            nascimento = row['nascimento'] as String;
        PerfilPaciente(nome: nome, nascimento: nascimento);
        await txn.insert('pacientes', {
          'id': row['id'],
          'chave': PacienteHistorico.chave(nome, nascimento),
          'nome': nome,
          'nascimento': nascimento,
          'criado_em': DateTime.parse(
            row['criado_em'] as String,
          ).toIso8601String(),
          'atualizado_em': DateTime.parse(
            row['atualizado_em'] as String,
          ).toIso8601String(),
        });
      }
      for (final (chave, tabela) in [
        ('preConsultas', 'pre_consultas'),
        ('reavaliacoes', 'reavaliacoes'),
      ]) {
        for (final raw in value[chave] as List? ?? const []) {
          final row = raw as Map;
          final paciente = pacientes[row['paciente_id']];
          final json = row['json'] as String;
          final (id, nome, nascimento) = _identidadeNoHistorico(tabela, json);
          if (paciente == null ||
              id != row['id'] ||
              PacienteHistorico.chave(nome, nascimento) !=
                  PacienteHistorico.chave(
                    paciente['nome'] as String,
                    paciente['nascimento'] as String,
                  )) {
            throw const FormatException(
              'O histórico de pacientes da cópia está inconsistente. Nada foi restaurado.',
            );
          }
          await txn.insert(tabela, {
            'id': id,
            'paciente_id': row['paciente_id'],
            'recebida_em': DateTime.parse(
              row['recebida_em'] as String,
            ).toIso8601String(),
            'json': json,
          });
        }
      }
    });
    if (rascunhos != null && rascunhosPdf != null) {
      await rascunhosPdf!.restaurar(rascunhos.cast<Map<String, dynamic>>());
    }
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
