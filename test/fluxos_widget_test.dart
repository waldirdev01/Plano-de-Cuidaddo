import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:platform/testing.dart';
import 'package:plano_de_cuidado/core/lembretes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/edicao_plano.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:plano_de_cuidado/ui/app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Picker extends FilePickerPlatform {
  File? file;
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => file == null ? [] : [_LocalFile(file!)];
}

final class _LocalFile extends PlatformFile {
  _LocalFile(this.file);
  final File file;
  @override
  String get name => file.uri.pathSegments.last;
  @override
  Uri get uri => file.absolute.uri;
  @override
  XFile get xFile => XFile(file.path);
  @override
  int? lengthSync() => file.lengthSync();
  @override
  Future<int?> length() => file.length();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late _Picker picker;
  List<String> shared = [];
  setUpAll(() async {
    await (FontLoader(
      'Karla',
    )..addFont(rootBundle.load('assets/fonts/Karla.ttf'))).load();
    await (FontLoader(
      'Fraunces',
    )..addFont(rootBundle.load('assets/fonts/Fraunces.ttf'))).load();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dir = Directory.systemTemp.createTempSync('plano-fase2-tests-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            shared = List<String>.from(
              (call.arguments as Map)['paths'] as List? ?? [],
            );
            return 'com.test.local';
          },
        );
    for (final channel in [
      'br.com.waldirdev01.plano_cuidado/incoming-files',
      'dexterous.com/flutter/local_notifications',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(channel),
            (call) async => true,
          );
    }
    Lembretes.configurarParaTestes(
      FlutterLocalNotificationsPlugin.private(
        TestPlatform.native(operatingSystem: 'ios'),
      ),
    );
    await Lembretes.instance.inicializar();
    await Armazenamento.instance.db;
  });
  setUp(() async {
    final db = await Armazenamento.instance.db;
    for (final table in ['planos', 'registros', 'envios', 'config']) {
      await db.delete(table);
    }
    picker = _Picker();
    FilePickerPlatform.instance = picker;
    shared = [];
  });
  tearDownAll(() async {
    await (await Armazenamento.instance.db).close();
    dir.deleteSync(recursive: true);
  });
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 920));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Karla'),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    for (
      var i = 0;
      i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  Finder label(String text) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == text,
  );
  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 16));
    for (
      var i = 0;
      i < 30 &&
          (find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
              find.text('Salvando…').evaluate().isNotEmpty);
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editor cria todos os tipos, seção, PDF, salva e exporta um arquivo importável',
    (tester) async {
      final data = novoPlano('Médica Teste', 'CRM Teste');
      data['paciente']['nascimento'] = '1990-01-01';
      await pump(tester, EditorPlanoPage(data: data));
      await tester.enterText(label('Nome do paciente'), 'Paciente Teste');
      await tester.enterText(label('Data de nascimento'), '01/01/1990');
      Future<void> add(
        String model, {
        bool diario = false,
        String? tipo,
      }) async {
        await tap(
          tester,
          find.text(diario ? 'Adicionar anotação diária' : 'Adicionar meta'),
        );
        await tap(tester, find.text(model).last);
        if (model == 'Criar do zero') {
          await tester.enterText(label('Título'), 'Pergunta de teste');
        }
        if (tipo != null) {
          await tap(tester, find.byType(DropdownButtonFormField<String>));
          await tap(tester, find.text(tipo).last);
        }
        if (model == 'Água') {
          await tester.enterText(label('Quantidade-alvo'), '4');
        }
        await tap(tester, find.text('Salvar campo'));
      }

      await add('Refeições à mesa');
      await add('Água');
      await add('Criar do zero', tipo: 'Sim ou não');
      await add('Atividade física', diario: true);
      await add('Nota do dia', diario: true);
      await tap(tester, find.text('Adicionar seção'));
      await tester.enterText(label('Título da seção'), 'Texto profissional');
      await tester.enterText(label('Texto da seção'), 'Orientação de teste.');
      await tap(tester, find.text('Salvar seção'));
      picker.file = File('test/fixtures/documento-teste.pdf');
      await tap(tester, find.text('Anexar PDF'));
      await tap(tester, find.text('Salvar plano'));
      final saved = (await tester.runAsync(
        () => Armazenamento.instance.planosCriados(),
      ))!.single;
      expect(saved.nomePaciente, 'Paciente Teste');
      expect(saved.metas.map((m) => m['tipo']), [
        'checklist',
        'contador',
        'sim_nao',
      ]);
      expect(saved.camposDiarios.map((m) => m['tipo']), ['texto', 'escala']);
      expect(saved.data['pdf'], isNotNull);
      await tap(tester, find.text('Exportar .plano'));
      expect(shared, hasLength(1));
      final exported = await tester.runAsync(
        () => File(shared.single).readAsBytes(),
      );
      expect(Plano.parseBytes(exported!).id, saved.id);
      expect(
        File(shared.single).uri.pathSegments.last,
        startsWith('plano-paciente-'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('checklist, água, texto e notas salvam sem conversão indevida', (
    tester,
  ) async {
    final data = novoPlano('Médica Teste', 'CRM Teste');
    data['paciente']['nascimento'] = '1990-01-01';
    data['paciente']['nome'] = 'Teste';
    data['metas'] = [modeloCampo('Refeições à mesa'), modeloCampo('Água')];
    data['camposDiarios'] = [
      modeloCampo('Atividade física'),
      modeloCampo('Nota do dia'),
    ];
    final p = Plano.parse(jsonEncode(data));
    await pump(
      tester,
      Scaffold(
        body: HojePage(plano: p, refresh: () async {}),
      ),
    );
    await tap(tester, find.text('Café'));
    await tap(tester, find.text('Almoço'));
    await tap(tester, find.byTooltip('Aumentar Água'));
    await tap(tester, find.byTooltip('Aumentar Água'));
    await tap(tester, find.byTooltip('Diminuir Água'));
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'Caminhada');
    await tester.pumpAndSettle();
    await tap(tester, find.text('8'));
    final records = await tester.runAsync(
      () => Armazenamento.instance.registros(
        p.id,
        Plano.formatDia(DateTime.now()),
      ),
    );
    expect(records![p.metas[0]['id']], ['Café', 'Almoço']);
    expect(records[p.metas[1]['id']], 1);
    expect(records[p.camposDiarios[0]['id']], 'Caminhada');
    expect(records[p.camposDiarios[1]['id']], 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semana edita dia passado e bloqueia futuro', (tester) async {
    final data = novoPlano('Médica Teste', 'CRM Teste');
    data['paciente']['nascimento'] = '1990-01-01';
    data['paciente']['nome'] = 'Teste';
    final today = DateTime.now();
    final yesterday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    data['inicio'] = Plano.formatDia(yesterday);
    data['metas'] = [modeloCampo('Refeições à mesa')];
    final p = Plano.parse(jsonEncode(data));
    await pump(tester, Scaffold(body: SemanaPage(plano: p)));
    final date =
        '${['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'][yesterday.weekday - 1]} ${fmtDia.format(yesterday)}';
    if (today.weekday == DateTime.monday) {
      await tap(tester, find.byTooltip('Semana anterior'));
    }
    await tap(tester, find.text(date));
    await tap(tester, find.text('Jantar'));
    await tap(tester, find.text('Concluir'));
    final records = await tester.runAsync(
      () => Armazenamento.instance.registros(p.id, Plano.formatDia(yesterday)),
    );
    expect(records![p.metas[0]['id']], ['Jantar']);
    final tomorrow = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));
    final future =
        '${['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'][tomorrow.weekday - 1]} ${fmtDia.format(tomorrow)}';
    if (find.text(future).evaluate().isNotEmpty) {
      await tap(tester, find.text(future));
      expect(
        find.text('Registros de ${fmtDia.format(tomorrow)}'),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('prévia não salva marcações e telas aceitam fonte grande', (
    tester,
  ) async {
    final data = novoPlano('Médica Teste', 'CRM Teste');
    data['paciente']['nascimento'] = '1990-01-01';
    data['paciente']['nome'] = 'Teste';
    data['metas'] = [modeloCampo('Refeições à mesa')];
    final p = Plano.parse(jsonEncode(data));
    await pump(tester, PreviaPlanoPage(plano: p), scale: 3.2);
    await tap(tester, find.text('Café'));
    expect(tester.takeException(), isNull);
    expect(
      await tester.runAsync(
        () => Armazenamento.instance.registros(
          p.id,
          Plano.formatDia(DateTime.now()),
        ),
      ),
      isEmpty,
    );
    await pump(tester, EditorPlanoPage(data: data), scale: 3.2);
    await tap(tester, find.text('Adicionar meta'));
    await tap(tester, find.text('Nota do dia').last);
    expect(tester.takeException(), isNull);
  });
  testWidgets('enviar semana gera PNG e registra período compartilhado', (
    tester,
  ) async {
    final data = novoPlano('Médica Teste', 'CRM Teste');
    data['paciente']['nascimento'] = '1990-01-01';
    data['paciente']['nome'] = 'Teste';
    final today = DateTime.now();
    data['inicio'] = Plano.formatDia(today.subtract(const Duration(days: 2)));
    data['metas'] = [modeloCampo('Refeições à mesa'), modeloCampo('Água')];
    data['camposDiarios'] = [
      modeloCampo('Atividade física'),
      modeloCampo('Nota do dia'),
    ];
    final p = Plano.parse(jsonEncode(data));
    await tester.runAsync(
      () => Armazenamento.instance.salvarRegistro(
        p.id,
        Plano.formatDia(today),
        p.metas[0]['id'] as String,
        ['Café'],
      ),
    );
    await pump(tester, Scaffold(body: SemanaPage(plano: p)));
    await tap(tester, find.text('Enviar semana'));
    for (var attempt = 0; attempt < 50 && shared.isEmpty; attempt++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    final bytes = await tester.runAsync(
      () => File(shared.single).readAsBytes(),
    );
    expect(bytes!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    await tester.runAsync(
      () => File('${dir.path}/fase2-semana-teste.png').writeAsBytes(bytes),
    );
    expect(
      await tester.runAsync(() => Armazenamento.instance.ultimoEnvio(p.id)),
      Plano.formatDia(today),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('escolher outro dia carrega suas próprias anotações', (
    tester,
  ) async {
    final data = novoPlano('Médica Teste', 'CRM Teste');
    data['paciente']['nascimento'] = '1990-01-01';
    data['paciente']['nome'] = 'Teste';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    data['inicio'] = Plano.formatDia(yesterday);
    data['camposDiarios'] = [modeloCampo('Atividade física')];
    final p = Plano.parse(jsonEncode(data));
    final id = p.camposDiarios.single['id'] as String;
    await tester.runAsync(() async {
      await Armazenamento.instance.salvarRegistro(
        p.id,
        Plano.formatDia(today),
        id,
        'Hoje',
      );
      await Armazenamento.instance.salvarRegistro(
        p.id,
        Plano.formatDia(yesterday),
        id,
        'Ontem',
      );
    });
    await pump(
      tester,
      Scaffold(
        body: HojePage(plano: p, refresh: () async {}),
      ),
    );
    expect(find.text('Hoje'), findsOneWidget);
    await tap(tester, find.text('Escolher dia para marcar'));
    await tap(
      tester,
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('${yesterday.day}'),
      ),
    );
    await tap(tester, find.text('OK'));
    expect(find.text('Ontem'), findsOneWidget);
    expect(find.text('Hoje'), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'Ontem corrigido');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    final previous = await tester.runAsync(
      () => Armazenamento.instance.registros(p.id, Plano.formatDia(yesterday)),
    );
    expect(previous![id], 'Ontem corrigido');
    expect(
      (await tester.runAsync(
        () => Armazenamento.instance.registros(p.id, Plano.formatDia(today)),
      ))![id],
      'Hoje',
    );
  });

  testWidgets('cadastro pede dados independentes e valida nascimento', (
    tester,
  ) async {
    var salvo = false;
    await pump(
      tester,
      CadastroPacientePage(
        onSaved: () async {
          salvo = true;
        },
      ),
    );
    expect(
      (tester.widget<TextField>(label('Nome completo'))).controller!.text,
      isEmpty,
    );
    expect(
      (tester.widget<TextField>(label('Data de nascimento'))).controller!.text,
      isEmpty,
    );
    await tap(tester, find.text('Salvar cadastro'));
    expect(salvo, isFalse);
    await tester.enterText(label('Nome completo'), 'Paciente Certo');
    await tester.enterText(label('Data de nascimento'), '29022025');
    expect(
      (tester.widget<TextField>(label('Data de nascimento'))).controller!.text,
      '29/02/2025',
    );
    await tap(tester, find.text('Salvar cadastro'));
    expect(find.text('Data de nascimento inválida.'), findsOneWidget);
    await tester.enterText(label('Data de nascimento'), '29/02/2000');
    await tap(tester, find.text('Salvar cadastro'));
    expect(salvo, isTrue);
    final perfil = await tester.runAsync(
      () => Armazenamento.instance.perfilPaciente(),
    );
    expect(perfil!.nome, 'Paciente Certo');
    expect(perfil.nascimento, '2000-02-29');
  });

  testWidgets('médica não salva nem exporta plano sem nascimento', (
    tester,
  ) async {
    final d = novoPlano('Médica Teste', 'CRM Teste');
    await pump(tester, EditorPlanoPage(data: d));
    await tester.enterText(label('Nome do paciente'), 'Paciente Certo');
    await tap(tester, find.byType(PopupMenuButton<String>));
    await tap(tester, find.text('Exportar .plano').last);
    expect(find.text('Use DD/MM/AAAA.'), findsOneWidget);
    expect(
      await tester.runAsync(() => Armazenamento.instance.planosCriados()),
      isEmpty,
    );
    expect(shared, isEmpty);
  });

  testWidgets(
    'receber arquivo sem cadastro pede dados em branco e cancelar não importa',
    (tester) async {
      await pump(tester, const PlanoCuidadoApp());
      final d = novoPlano('Médica Teste', 'CRM Teste');
      d['paciente'] = {'nome': 'IDENTIDADE ALHEIA', 'nascimento': '1980-02-01'};
      final f = File('${dir.path}/sem-cadastro.plano')
        ..writeAsStringSync(jsonEncode(d));
      Future<void>? pendente;
      await tester.runAsync(() async {
        pendente = processarArquivoRecebido!(f);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('IDENTIDADE ALHEIA'), findsNothing);
      expect(find.text('Importar plano?'), findsNothing);
      expect(
        (tester.widget<TextField>(label('Nome completo'))).controller!.text,
        isEmpty,
      );
      expect(
        (tester.widget<TextField>(
          label('Data de nascimento'),
        )).controller!.text,
        isEmpty,
      );
      await tap(tester, find.byType(BackButton));
      await tester.runAsync(() => pendente!);
      expect(
        await tester.runAsync(() => Armazenamento.instance.planos()),
        isEmpty,
      );
      expect(
        await tester.runAsync(() => Armazenamento.instance.perfilPaciente()),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  Future<Plano> prepararImportacao(WidgetTester tester) async {
    final d = novoPlano('Médica Teste', 'CRM Teste');
    d['paciente'] = {'nome': 'Paciente Certo', 'nascimento': '1990-01-01'};
    final p = Plano.parse(jsonEncode(d));
    await tester.runAsync(() async {
      final db = Armazenamento.instance;
      await db.salvarPerfilPaciente(
        PerfilPaciente(nome: 'Paciente Certo', nascimento: '1990-01-01'),
      );
      await db.setConfig('papel', 'paciente');
      await db.setConfig('permissao_notificacoes_pedida', 'sim');
      await db.importar(p);
      await db.salvarRegistro(
        p.id,
        Plano.formatDia(DateTime.now()),
        'teste',
        'Preservar',
      );
    });
    await pump(tester, const PlanoCuidadoApp());
    return p;
  }

  testWidgets(
    'arquivo errado recebido bloqueia antes do resumo e não mostra identidade alheia',
    (tester) async {
      final correto = await prepararImportacao(tester);
      final antes = await tester.runAsync(
        () => Armazenamento.instance.backupConteudo(),
      );
      final d = copiarDados(correto.data);
      d['id'] = novoId();
      d['paciente']['nome'] = 'NOME CONFIDENCIAL ALHEIO';
      final f = File('${dir.path}/errado.plano')
        ..writeAsStringSync(jsonEncode(d));
      await tester.runAsync(() => processarArquivoRecebido!(f));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Este plano não corresponde ao seu cadastro'),
        findsOneWidget,
      );
      expect(find.textContaining('NOME CONFIDENCIAL ALHEIO'), findsNothing);
      expect(find.text('Importar plano?'), findsNothing);
      expect(
        await tester.runAsync(() => Armazenamento.instance.backupConteudo()),
        antes,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nome correto com nascimento errado também bloqueia na interface',
    (tester) async {
      final correto = await prepararImportacao(tester);
      final d = copiarDados(correto.data);
      d['paciente']['nascimento'] = '1990-01-02';
      final f = File('${dir.path}/nascimento-errado.plano')
        ..writeAsStringSync(jsonEncode(d));
      await tester.runAsync(() => processarArquivoRecebido!(f));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Este plano não corresponde ao seu cadastro'),
        findsOneWidget,
      );
      expect(find.text('Importar plano?'), findsNothing);
      expect(
        (await tester.runAsync(
          () => Armazenamento.instance.planoAtivo(),
        ))!.nascimentoPaciente,
        '1990-01-01',
      );
    },
  );

  testWidgets(
    'correspondente permite confirmar importação e conserva registros',
    (tester) async {
      final correto = await prepararImportacao(tester);
      final f = File('${dir.path}/correto.plano')
        ..writeAsStringSync(jsonEncode(correto.data));
      Future<void>? pendente;
      await tester.runAsync(() async {
        pendente = processarArquivoRecebido!(f);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Importar plano?'), findsOneWidget);
      expect(find.textContaining('Paciente Certo'), findsOneWidget);
      await tap(tester, find.text('Importar'));
      await tester.runAsync(() => pendente!);
      await tester.pumpAndSettle();
      expect(find.text('Plano importado.'), findsOneWidget);
      expect(
        (await tester.runAsync(
          () => Armazenamento.instance.registros(
            correto.id,
            Plano.formatDia(DateTime.now()),
          ),
        ))!['teste'],
        'Preservar',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'troca de cadastro oculta plano incompatível e histórico do paciente anterior',
    (tester) async {
      await prepararImportacao(tester);
      await tester.runAsync(() async {
        final d = novoPlano('Médica Teste', 'CRM Teste');
        d['paciente'] = {'nome': 'Paciente Certo', 'nascimento': '1990-01-01'};
        await (await Armazenamento.instance.db).insert('planos', {
          'id': d['id'],
          'json': jsonEncode(d),
          'status': 'arquivado',
          'origem': 'importado',
          'atualizado_em': DateTime.now().toIso8601String(),
        });
      });
      await tap(tester, find.text('Ajustes').last);
      await tap(tester, find.text('Meu cadastro'));
      await tester.enterText(label('Nome completo'), 'Outro Paciente');
      await tap(tester, find.text('Salvar cadastro'));
      expect(
        (await tester.runAsync(
          () => Armazenamento.instance.perfilPaciente(),
        ))!.nome,
        'Outro Paciente',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Este plano não corresponde ao seu cadastro'),
        findsOneWidget,
      );
      await tap(tester, find.text('Histórico'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ainda não há planos anteriores.'), findsOneWidget);
      expect(find.text('Paciente Certo'), findsNothing);
    },
  );
  test(
    'lembretes locais respeitam janela de 60 e desligamento cancela tudo',
    () async {
      final reminders = Lembretes.testing(
        FlutterLocalNotificationsPlugin.private(
          TestPlatform.native(operatingSystem: 'ios'),
        ),
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              calls.add(call);
              return true;
            },
          );
      try {
        await reminders.inicializar();
        final data = novoPlano('Médica Teste', 'CRM Teste');
        data['paciente']['nascimento'] = '1990-01-01';
        data['paciente']['nome'] = 'Teste';
        data['retorno']['data'] = Plano.formatDia(
          DateTime.now().add(const Duration(days: 90)),
        );
        final field = modeloCampo('Água');
        field['lembretes'] = ['10:00', '12:00', '15:00'];
        data['metas'] = [field];
        await reminders.reagendar(Plano.parse(jsonEncode(data)));
        expect(calls.where((c) => c.method == 'zonedSchedule'), hasLength(60));
        calls.clear();
        await reminders.reagendar(Plano.parse(jsonEncode(data)), ativo: false);
        expect(calls.map((c) => c.method), ['cancelAll']);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('dexterous.com/flutter/local_notifications'),
              null,
            );
      }
    },
  );
}
