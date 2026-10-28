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
import 'package:plano_de_cuidado/core/exportacao_pdf.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:plano_de_cuidado/core/pre_consulta.dart';
import 'package:plano_de_cuidado/core/retorno_acompanhamento.dart';
import 'package:plano_de_cuidado/core/importacao_pdf.dart';
import 'package:plano_de_cuidado/ui/app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures/pdf_texto.dart';
import 'fixtures/rascunho_conferido.dart';

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
  String shareResult = 'com.test.local';
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
            return shareResult;
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
    for (final table in [
      'planos',
      'registros',
      'envios',
      'config',
      'pacientes',
      'pre_consultas',
      'reavaliacoes',
    ]) {
      await db.delete(table);
    }
    picker = _Picker();
    FilePickerPlatform.instance = picker;
    shared = [];
    shareResult = 'com.test.local';
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
      expect(Plano.parseBytes(exported).data['versao'], 3);
      expect(
        File(shared.single).uri.pathSegments.last,
        startsWith('plano-paciente-'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  RascunhoPdf rascunhoTeste() => RascunhoPdf.analisar(
    TextoPdf(paginas: [textoPlanoPdfTeste], links: const [linkPdfTeste]),
    nomeArquivo: 'documento-ficticio.pdf',
    bytes: Uint8List.fromList(utf8.encode('%PDF-ficticio')),
  );

  testWidgets(
    'PDF: rascunho com pendências salva e reabre sem alterar planos',
    (tester) async {
      final store = ArquivosRascunhoPdf(
        diretorio: Directory('${dir.path}/pdf-salvar'),
      );
      final r = rascunhoTeste();
      await pump(tester, ConferenciaPdfPage(rascunho: r, arquivos: store));
      expect(find.text('Conferir PDF'), findsOneWidget);
      expect(find.text('Exportar .plano'), findsNothing);
      await tester.enterText(
        label('Nome completo do paciente'),
        'Ana Exemplo Completo',
      );
      await tap(tester, find.text('Salvar rascunho com pendências'));
      final saved = (await tester.runAsync(store.listar))!.single;
      expect(saved.nome, 'Ana Exemplo Completo');
      expect(saved.campos['nascimento'], '1990-01-01');
      expect(saved.estado, 'rascunho');
      expect(
        await tester.runAsync(() => Armazenamento.instance.planosCriados()),
        isEmpty,
      );
      await pump(
        tester,
        ConferenciaPdfPage(
          key: const ValueKey('reaberto'),
          rascunho: saved,
          arquivos: store,
        ),
      );
      expect(label('Nome completo do paciente'), findsOneWidget);
      expect(find.text('Ana Exemplo Completo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PDF: padrão válido conclui sem decisões extras e edição invalida confirmações',
    (tester) async {
      final store = ArquivosRascunhoPdf(
        diretorio: Directory('${dir.path}/pdf-concluir'),
      );
      final r = rascunhoTeste();
      await pump(tester, ConferenciaPdfPage(rascunho: r, arquivos: store));
      await tap(tester, find.text('Concluir conferência'));
      expect(find.text('Ainda falta conferir'), findsOneWidget);
      expect(await tester.runAsync(store.listar), isEmpty);
      await tap(tester, find.text('Continuar conferindo'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
      await tester.pumpAndSettle();
      await tester.ensureVisible(label('Nascimento do paciente'));
      await tester.enterText(label('Nascimento do paciente'), '01011990');
      for (final title in [
        'Conferi o destinatário, o nome completo e o nascimento.',
        'Conferi o período, retorno, envio e horários propostos.',
        'Conferi a fidelidade das metas, refeições e textos e registrei as decisões necessárias.',
      ]) {
        await tap(tester, find.text(title));
      }
      await tap(tester, find.text('Concluir conferência'));
      expect(find.text('Ainda falta conferir'), findsNothing);
      final saved = (await tester.runAsync(store.listar))!.single;
      expect(saved.estado, 'conferido');
      expect(saved.campos['nascimento'], '1990-01-01');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
      await tester.pumpAndSettle();
      await tester.ensureVisible(label('Nome completo do paciente'));
      await tester.enterText(
        label('Nome completo do paciente'),
        'Nome Corrigido',
      );
      await tap(tester, find.text('Salvar rascunho com pendências'));
      final edited = (await tester.runAsync(store.listar))!.single;
      expect(edited.estado, 'rascunho');
      expect(
        (edited.data['confirmacoes'] as Map).values.every((v) => v == false),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PDF: incluir treino na conferência desfaz confirmações e vai no .plano',
    (tester) async {
      final store = ArquivosRascunhoPdf(
        diretorio: Directory('${dir.path}/pdf-treino'),
      );
      await pump(
        tester,
        ConferenciaPdfPage(rascunho: rascunhoConferido(), arquivos: store),
      );
      await tap(tester, find.text('Não incluído. Toque para incluir.'));
      await tap(tester, find.text('Incluir treino neste plano'));
      await tap(tester, find.text('Aplicar na conferência'));
      expect(
        find.text('Confirme a triagem de segurança negativa.'),
        findsOneWidget,
      );
      await tap(tester, find.textContaining('Triagem de segurança negativa'));
      await tap(tester, find.text('Aplicar na conferência'));
      expect(
        find.text('Incluído: Iniciante · Perda de gordura e de peso'),
        findsOneWidget,
      );
      final exportar = find.widgetWithText(
        FilledButton,
        'Exportar .plano conferido',
      );
      await tester.ensureVisible(exportar);
      expect(tester.widget<FilledButton>(exportar).onPressed, isNull);
      await tap(tester, find.text('Concluir conferência'));
      expect(find.text('Ainda falta conferir'), findsOneWidget);
      await tap(tester, find.text('Continuar conferindo'));
      for (final title in [
        'Conferi o destinatário, o nome completo e o nascimento.',
        'Conferi o período, retorno, envio e horários propostos.',
        'Conferi a fidelidade das metas, refeições e textos e registrei as decisões necessárias.',
      ]) {
        await tap(tester, find.text(title));
      }
      await tap(tester, find.text('Concluir conferência'));
      final saved = (await tester.runAsync(store.listar))!.single;
      expect(saved.estado, 'conferido');
      final plano = planoDoPdfConferido(
        saved,
        profissional: 'Médica Exemplo',
        registro: 'CRM TESTE',
      );
      expect(plano.treino!.nivel, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PDF: rotina alimentar com metas de macro substitui as refeições do PDF',
    (tester) async {
      final store = ArquivosRascunhoPdf(
        diretorio: Directory('${dir.path}/pdf-alimentacao'),
      );
      await pump(
        tester,
        ConferenciaPdfPage(rascunho: rascunhoConferido(), arquivos: store),
      );
      await tap(
        tester,
        find.text(
          'Não incluída. Toque para incluir metas de calorias e macros.',
        ),
      );
      expect(
        find.textContaining('substitui as 4 refeições lidas do PDF'),
        findsOneWidget,
      );
      await tap(tester, find.text('Carregar modelo de teste'));
      final kcal = find.widgetWithText(TextField, 'Calorias (kcal)');
      expect(tester.widget<TextField>(kcal).controller!.text, '1800');
      await tester.enterText(kcal, 'muito');
      await tap(tester, find.text('Aplicar'));
      expect(
        find.text('Informe calorias (kcal) com um número.'),
        findsOneWidget,
      );
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.enterText(kcal, '2270');
      await tester.enterText(
        find.widgetWithText(TextField, 'Proteína (g)'),
        '104,5',
      );
      await tap(tester, find.text('Aplicar'));
      expect(
        find.text(
          'Incluída: 2270 kcal · proteína 104,5 g. Substitui as refeições do PDF.',
        ),
        findsOneWidget,
      );
      for (final title in [
        'Conferi o destinatário, o nome completo e o nascimento.',
        'Conferi o período, retorno, envio e horários propostos.',
        'Conferi a fidelidade das metas, refeições e textos e registrei as decisões necessárias.',
      ]) {
        await tap(tester, find.text(title));
      }
      await tap(tester, find.text('Concluir conferência'));
      final saved = (await tester.runAsync(store.listar))!.single;
      final plano = planoDoPdfConferido(
        saved,
        profissional: 'Médica Exemplo',
        registro: 'CRM TESTE',
      );
      expect(plano.alimentacao!.meta.kcal, 2270);
      expect(plano.alimentacao!.meta.proteina, 104.5);
      expect(plano.refeicoesPrescritas, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('PDF: tela de conferência aceita fonte ampliada', (tester) async {
    await pump(
      tester,
      ConferenciaPdfPage(rascunho: rascunhoTeste()),
      scale: 3.2,
    );
    await tap(tester, find.text('Metas reconhecidas (2)'));
    await tap(tester, find.text('Refeições reconhecidas (4)'));
    await tap(tester, find.text('Salvar rascunho com pendências'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'PDF conferido exporta arquivo real, paciente importa e acompanha refeições',
    (tester) async {
      final r = rascunhoConferido();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      r.campos['inicio'] = Plano.formatDia(
        today.subtract(const Duration(days: 1)),
      );
      r.campos['fim'] = Plano.formatDia(today.add(const Duration(days: 1)));
      r.campos['retorno'] = Plano.formatDia(today.add(const Duration(days: 2)));
      await tester.runAsync(() async {
        await Armazenamento.instance.setConfig(
          'profissional_nome',
          'Médica Exemplo',
        );
        await Armazenamento.instance.setConfig(
          'profissional_registro',
          'CRM TESTE',
        );
      });
      final store = ArquivosRascunhoPdf(
        diretorio: Directory('${dir.path}/exportar-pdf'),
      );
      await pump(tester, ConferenciaPdfPage(rascunho: r, arquivos: store));
      await tap(tester, find.text('Exportar .plano conferido'));
      expect(find.text('Conferir destinatário da exportação'), findsOneWidget);
      expect(find.textContaining('Ana Exemplo Completo'), findsOneWidget);
      await tap(tester, find.text('Compartilhar .plano'));
      expect(shared, hasLength(1));
      final file = File(shared.single);
      final bytes = await tester.runAsync(file.readAsBytes);
      final p = Plano.parseBytes(bytes!);
      expect(p.data['versao'], 4);
      expect(p.id, r.id);
      expect(p.refeicoesPrescritas, hasLength(4));
      expect(
        await tester.runAsync(() => Armazenamento.instance.planosCriados()),
        isEmpty,
      );
      await tester.runAsync(() async {
        await Armazenamento.instance.setConfig('papel', 'paciente');
        await Armazenamento.instance.salvarPerfilPaciente(
          PerfilPaciente(
            nome: 'Ana Exemplo Completo',
            nascimento: '1990-01-01',
          ),
        );
        await Armazenamento.instance.setConfig(
          'permissao_notificacoes_pedida',
          'sim',
        );
      });
      await pump(tester, const PlanoCuidadoApp());
      Future<void>? pending;
      await tester.runAsync(() async {
        pending = processarArquivoRecebido!(file);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Importar plano?'), findsOneWidget);
      await tap(tester, find.text('Importar'));
      await tester.runAsync(() => pending!);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Fiz').first);
      var records = (await tester.runAsync(
        () => Armazenamento.instance.registros(p.id, Plano.formatDia(today)),
      ))!;
      expect(records[p.refeicoesPrescritas.first['id']], 'feito');
      await tap(tester, find.text('Dispensado conforme plano').first);
      records = (await tester.runAsync(
        () => Armazenamento.instance.registros(p.id, Plano.formatDia(today)),
      ))!;
      expect(records[p.refeicoesPrescritas[2]['id']], 'dispensado');
      await tap(tester, find.text('Alimentação').last);
      expect(find.text('Minha rotina alimentar'), findsOneWidget);
      expect(
        find.textContaining('Não há cálculo de nutrientes'),
        findsOneWidget,
      );
      await tap(tester, find.text('Semana').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dispensado conforme plano'), findsOneWidget);
      expect(find.text('Não confirmado'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PDF sem conferência não permite exportar e prévia v4 não grava marcações',
    (tester) async {
      final r = rascunhoTeste();
      await pump(tester, ConferenciaPdfPage(rascunho: r));
      await tester.scrollUntilVisible(
        find.text('Exportar .plano conferido'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Exportar .plano conferido'),
      );
      expect(button.onPressed, isNull);
      expect(shared, isEmpty);
      final p = planoPdfTeste();
      await pump(tester, PreviaPlanoPage(plano: p));
      await tap(tester, find.text('Dispensado conforme plano'));
      expect(
        await tester.runAsync(
          () => Armazenamento.instance.registros(p.id, '2026-10-17'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('PDF: contagem editada incompatível bloqueia conclusão', (
    tester,
  ) async {
    final store = ArquivosRascunhoPdf(
      diretorio: Directory('${dir.path}/pdf-soma'),
    );
    final r = rascunhoTeste();
    for (final key in (r.data['confirmacoes'] as Map).keys) {
      r.data['confirmacoes'][key] = true;
    }
    r.lista('metas').last['alvo'] = '5';
    await pump(tester, ConferenciaPdfPage(rascunho: r, arquivos: store));
    await tap(tester, find.text('Concluir conferência'));
    expect(find.text('Ainda falta conferir'), findsOneWidget);
    expect(find.textContaining('soma 4'), findsOneWidget);
    expect(await tester.runAsync(store.listar), isEmpty);
  });

  testWidgets(
    'paciente v4 aceita contagem decimal e seis refeições com fonte ampliada',
    (tester) async {
      final p = planoPdfTeste(refeicoes: 6);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      p.data['inicio'] = Plano.formatDia(today);
      p.data['fim'] = Plano.formatDia(today.add(const Duration(days: 1)));
      p.data['retorno']['data'] = Plano.formatDia(
        today.add(const Duration(days: 2)),
      );
      await pump(
        tester,
        Scaffold(
          body: HojePage(plano: p, refresh: () async {}),
        ),
        scale: 3.2,
      );
      await tap(tester, find.text('Informar quantidade'));
      await tester.enterText(label('Quantidade realizada'), '0,5');
      await tap(tester, find.text('Registrar quantidade'));
      final records = (await tester.runAsync(
        () => Armazenamento.instance.registros(p.id, Plano.formatDia(today)),
      ))!;
      expect(records[p.metas[1]['id']], 0.5);
      await tester.scrollUntilVisible(
        find.text('Refeição de exemplo 6'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Refeição de exemplo 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('PDF: regra condicional é visível e editável na conferência', (
    tester,
  ) async {
    await pump(tester, ConferenciaPdfPage(rascunho: rascunhoTeste()));
    await tap(tester, find.text('Refeições reconhecidas (4)'));
    final condition = label('Condição para dispensar').at(2);
    await tester.scrollUntilVisible(
      condition,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(condition);
    expect(
      find.text('Quando não sentir fome, conforme orientação da profissional.'),
      findsOneWidget,
    );
    await tester.enterText(
      condition,
      'Condição revisada na conferência fictícia.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'PDF: modelo antigo recusado mostra orientação sem alterar paciente',
    (tester) async {
      await tester.runAsync(() async {
        await Armazenamento.instance.setConfig(
          'profissional_nome',
          'Médica Exemplo',
        );
        await Armazenamento.instance.setConfig(
          'profissional_registro',
          'CRM Teste',
        );
      });
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        canalLeituraPdf,
        (_) async => {
          'paginas': [
            textoPlanoPdfTeste.replaceAll(
              'PADRAO DO APLICATIVO: PLANO-CUIDADO/1',
              '',
            ),
          ],
          'links': <String>[],
        },
      );
      picker.file = File('test/fixtures/documento-teste.pdf');
      try {
        await pump(tester, ProfissionalPage(refresh: () async {}));
        await tap(tester, find.text('Regras do modelo PDF'));
        expect(find.text('Modelo PLANO-CUIDADO/1'), findsOneWidget);
        await tap(tester, find.text('Entendi'));
        await tap(tester, find.text('Importar PDF do plano'));
        expect(find.text('PDF fora do padrão'), findsOneWidget);
        expect(find.textContaining('Use o novo modelo'), findsOneWidget);
        expect(
          await tester.runAsync(() => Armazenamento.instance.planosCriados()),
          isEmpty,
        );
      } finally {
        messenger.setMockMethodCallHandler(canalLeituraPdf, null);
      }
    },
  );

  testWidgets('PDF: botão da médica lê documento e mantém paciente intocado', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await Armazenamento.instance.setConfig(
        'profissional_nome',
        'Médica Exemplo',
      );
      await Armazenamento.instance.setConfig(
        'profissional_registro',
        'CRM Teste',
      );
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      canalLeituraPdf,
      (_) async => {
        'paginas': [textoPlanoPdfTeste],
        'links': [linkPdfTeste],
      },
    );
    picker.file = File('test/fixtures/documento-teste.pdf');
    try {
      await pump(tester, ProfissionalPage(refresh: () async {}));
      await tap(tester, find.text('Importar PDF do plano'));
      expect(find.text('Conferir PDF'), findsOneWidget);
      expect(find.text('Paciente e datas'), findsOneWidget);
      expect(
        await tester.runAsync(() => Armazenamento.instance.perfilPaciente()),
        isNull,
      );
      expect(
        await tester.runAsync(() => Armazenamento.instance.planosCriados()),
        isEmpty,
      );
      await tap(tester, find.byTooltip('Voltar'));
      expect(find.text('Guardar esta conferência?'), findsOneWidget);
      await tap(tester, find.text('Sair sem salvar'));
      expect(find.text('Meus planos'), findsOneWidget);
    } finally {
      messenger.setMockMethodCallHandler(canalLeituraPdf, null);
    }
  });

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
    await tap(tester, find.text('Enviar imagem da semana'));
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
  Plano planoRetornoTeste() {
    final p = planoPdfTeste();
    final now = DateTime.now();
    p.data['inicio'] = Plano.formatDia(now.subtract(const Duration(days: 1)));
    p.data['fim'] = Plano.formatDia(now.add(const Duration(days: 2)));
    p.data['retorno']['data'] = Plano.formatDia(
      now.add(const Duration(days: 3)),
    );
    return Plano.parse(jsonEncode(p.data));
  }

  testWidgets(
    'devolução: arquivo real abre na médica sem alterar paciente; salvar não registra envio',
    (tester) async {
      final p = planoRetornoTeste();
      final hoje = Plano.formatDia(DateTime.now());
      final agua = p.metas.last['id'] as String;
      final refeicao = p.camposRefeicoes.first['id'] as String;
      await tester.runAsync(() async {
        await Armazenamento.instance.salvarPerfilPaciente(
          PerfilPaciente(
            nome: p.nomePaciente,
            nascimento: p.nascimentoPaciente!,
          ),
        );
        await Armazenamento.instance.importar(p);
        await Armazenamento.instance.salvarRegistro(p.id, hoje, agua, 1.5);
        await Armazenamento.instance.salvarRegistro(
          p.id,
          hoje,
          refeicao,
          'nao_feito',
        );
      });
      await pump(
        tester,
        Scaffold(
          body: HojePage(plano: p, refresh: () async {}),
        ),
      );
      await tap(tester, find.text('Exportar acompanhamento'));
      expect(find.text('Conferir acompanhamento'), findsOneWidget);
      await tap(tester, find.text('Compartilhar acompanhamento .plano'));
      expect(shared, hasLength(1));
      final arquivo = File(shared.single);
      final retorno = RetornoAcompanhamento.parse(arquivo.readAsStringSync());
      expect(retorno.registros[hoje][agua], 1.5);
      expect(retorno.registros[hoje][refeicao], 'nao_feito');
      expect(retorno.plano.data.containsKey('pdf'), false);
      await tap(tester, find.text('Só salvei / ainda não enviei'));
      expect(
        await tester.runAsync(() => Armazenamento.instance.ultimoEnvio(p.id)),
        isNull,
      );
      await tap(tester, find.byType(BackButton));
      await tester.runAsync(() async {
        await Armazenamento.instance.setConfig('papel', 'profissional');
        await Armazenamento.instance.setConfig(
          'profissional_nome',
          p.nomeProfissional,
        );
        await Armazenamento.instance.setConfig(
          'profissional_registro',
          'CRM TESTE',
        );
      });
      await pump(tester, const PlanoCuidadoApp());
      Future<void>? pendente;
      await tester.runAsync(() async {
        pendente = processarArquivoRecebido!(arquivo);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Receber acompanhamento?'), findsOneWidget);
      await tap(tester, find.text('Receber e visualizar'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Acompanhamento do paciente'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      await tap(tester, find.byKey(ValueKey('retorno-dia-$hoje')));
      expect(find.text('Não feito'), findsOneWidget);
      expect(find.text('Não confirmado'), findsWidgets);
      expect(find.text('1.5 ${p.metas.last['unidade']}'), findsOneWidget);
      expect(find.text('Compartilhar acompanhamento .plano'), findsNothing);
      await tap(tester, find.byType(BackButton));
      await tester.runAsync(() => pendente!);
      expect(
        await tester.runAsync(() => Armazenamento.instance.retornosRecebidos()),
        hasLength(1),
      );
      expect(
        (await tester.runAsync(() => Armazenamento.instance.planoAtivo()))!.id,
        p.id,
      );
      expect(
        (await tester.runAsync(
          () => Armazenamento.instance.registros(p.id, hoje),
        ))![agua],
        1.5,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'devolução: cancelar não registra envio; confirmação explícita registra',
    (tester) async {
      final p = planoRetornoTeste();
      final r = RetornoAcompanhamento.criar(p, {});
      await tester.runAsync(() async {
        await Armazenamento.instance.salvarPerfilPaciente(
          PerfilPaciente(
            nome: p.nomePaciente,
            nascimento: p.nascimentoPaciente!,
          ),
        );
        await Armazenamento.instance.importar(p);
      });
      shareResult = '';
      await pump(
        tester,
        DetalheRetornoPage(retorno: r, exportar: true),
        scale: 2,
      );
      await tap(tester, find.text('Compartilhar acompanhamento .plano'));
      expect(find.text('Você enviou à médica?'), findsNothing);
      expect(
        await tester.runAsync(() => Armazenamento.instance.ultimoEnvio(p.id)),
        isNull,
      );
      shareResult = 'com.test.local';
      await tap(tester, find.text('Compartilhar acompanhamento .plano'));
      await tap(tester, find.text('Já enviei à médica'));
      expect(
        await tester.runAsync(() => Armazenamento.instance.ultimoEnvio(p.id)),
        Plano.formatDia(r.ate),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'devolução: paciente e profissional errado bloqueiam antes de revelar nome',
    (tester) async {
      final p = planoRetornoTeste();
      p.data['paciente']['nome'] = 'NOME RESERVADO DO RETORNO';
      final r = RetornoAcompanhamento.criar(p, {});
      final f = File('${dir.path}/retorno-errado.plano')
        ..writeAsStringSync(jsonEncode(r.data));
      await tester.runAsync(
        () => Armazenamento.instance.setConfig('papel', 'paciente'),
      );
      await pump(tester, const PlanoCuidadoApp());
      await tester.runAsync(() => processarArquivoRecebido!(f));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Troque para o modo profissional'),
        findsOneWidget,
      );
      expect(find.textContaining('NOME RESERVADO DO RETORNO'), findsNothing);
      await tester.runAsync(() async {
        await Armazenamento.instance.setConfig('papel', 'profissional');
        await Armazenamento.instance.setConfig('profissional_nome', 'Outra');
        await Armazenamento.instance.setConfig(
          'profissional_registro',
          'OUTRO',
        );
      });
      await tester.runAsync(() => processarArquivoRecebido!(f));
      await tester.pumpAndSettle();
      expect(find.textContaining('NOME RESERVADO DO RETORNO'), findsNothing);
      expect(
        await tester.runAsync(() => Armazenamento.instance.retornosRecebidos()),
        isEmpty,
      );
      expect(
        await tester.runAsync(() => Armazenamento.instance.perfilPaciente()),
        isNull,
      );
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

  test(
    'PDF v4 agenda refeições e metas somente até o fim dos registros',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      try {
        final p = planoPdfTeste();
        final now = DateTime.now();
        final first = DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 1));
        final last = first.add(const Duration(days: 1));
        p.data['inicio'] = Plano.formatDia(first);
        p.data['fim'] = Plano.formatDia(last);
        p.data['retorno']['data'] = Plano.formatDia(
          first.add(const Duration(days: 6)),
        );
        await Lembretes.instance.reagendar(Plano.parse(jsonEncode(p.data)));
        final scheduled = calls
            .where((c) => c.method == 'zonedSchedule')
            .map((c) => c.arguments as Map)
            .toList();
        final daily = scheduled
            .where(
              (c) => ![
                'Enviar semana',
                'Retorno amanhã',
                'Enviar acompanhamento final',
              ].contains(c['title']),
            )
            .toList();
        expect(daily, hasLength(12));
        expect(
          daily.where((c) => c['title'] == 'Lanche da tarde'),
          hasLength(2),
        );
        expect(
          daily
              .where((c) => c['title'] == 'Lanche da tarde')
              .every(
                (c) => (c['body'] as String).contains('condição de dispensa'),
              ),
          true,
        );
        for (final item in daily) {
          final at = DateTime.parse(item['scheduledDateTime'] as String);
          expect(at.isBefore(first), false);
          expect(at.isBefore(last.add(const Duration(days: 1))), true);
        }
        expect(scheduled.any((c) => c['title'] == 'Retorno amanhã'), true);
      } finally {
        messenger.setMockMethodCallHandler(channel, (_) async => true);
      }
    },
  );

  group('pré-consulta da paciente', () {
    final ana = PerfilPaciente(
      nome: 'Ana Exemplo Completo',
      nascimento: '1990-01-01',
    );
    Future<void> escrever(
      WidgetTester tester,
      String rotulo,
      String texto,
    ) async {
      final campo = label(rotulo);
      if (campo.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          campo,
          300,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(campo);
      await tester.enterText(campo, texto);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> continuar(WidgetTester tester) =>
        tap(tester, find.widgetWithText(FilledButton, 'Continuar'));

    testWidgets('preenche todas as etapas e exporta um arquivo válido', (
      tester,
    ) async {
      await tester.runAsync(
        () => Armazenamento.instance.salvarPerfilPaciente(ana),
      );
      await pump(tester, const PreConsultaPage());
      expect(find.text('1 / 7'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continuar'),
            )
            .onPressed,
        isNull,
      );
      await tap(
        tester,
        find.text('Li e concordo com o termo de consentimento.'),
      );
      await continuar(tester);
      expect(find.text('Ana Exemplo Completo'), findsOneWidget);
      await escrever(tester, 'CPF', '12345678900');
      expect(find.text('123.456.789-00'), findsOneWidget);
      await tap(tester, find.text('Feminino'));
      await escrever(tester, 'CEP', '70000000');
      await continuar(tester);
      await tap(tester, find.text('Problema nos rins'));
      await escrever(tester, 'Problema nos rins — detalhes', 'cálculo, 2019');
      await tap(tester, find.text(comorbidadeSop));
      await continuar(tester);
      await escrever(tester, 'Peso (kg)', '7850');
      expect(find.text('Use um número de 20 a 400.'), findsOneWidget);
      await continuar(tester);
      expect(find.text('Suas medidas'), findsOneWidget);
      await escrever(tester, 'Peso (kg)', '78,5');
      await escrever(tester, 'Altura (cm)', '165');
      await continuar(tester);
      await tap(tester, find.text('2–3x/semana'));
      await continuar(tester);
      await tap(tester, find.text('Vários dias').first);
      await continuar(tester);
      expect(find.text('Saúde hormonal'), findsOneWidget);
      await tap(tester, find.text('Regular'));
      await continuar(tester);
      expect(find.text('8 / 8'), findsOneWidget);
      expect(find.text('Enviar por e-mail para a médica'), findsNothing);
      await tap(tester, find.text('Compartilhar arquivo (WhatsApp e outros)'));
      expect(shared.single, endsWith('.plano'));
      expect(shared.single, contains('pre-consulta-ana-exemplo-completo-'));
      final p = PreConsulta.parse(File(shared.single).readAsStringSync());
      expect(p.nomePaciente, 'Ana Exemplo Completo');
      expect(p.respostas['ident']['cpf'], '123.456.789-00');
      expect(p.respostas['ident']['cep'], '70000-000');
      expect(p.respostas['saude']['detalhes'], {
        'Problema nos rins': 'cálculo, 2019',
      });
      expect(p.medidas['peso'], 78.5);
      expect(p.imc, 28.8);
      expect(p.respostas['habitos']['alcool'], 3);
      expect(p.respostas['emocional']['phq2'], [1, null]);
      expect(p.respostas['hormonal']['ciclo'], 'Regular');
      await tap(tester, find.text('Já enviei à médica'));
      expect(
        await tester.runAsync(
          () => Armazenamento.instance.config('pre_consulta_enviada_em'),
        ),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'retoma o rascunho; trocar para masculino limpa SOP e hormonal',
      (tester) async {
        await tester.runAsync(
          () => Armazenamento.instance.salvarPerfilPaciente(ana),
        );
        await pump(tester, const PreConsultaPage());
        await tap(
          tester,
          find.text('Li e concordo com o termo de consentimento.'),
        );
        await continuar(tester);
        await tap(tester, find.text('Feminino'));
        await continuar(tester);
        await tap(tester, find.text(comorbidadeSop));
        await pump(tester, const PreConsultaPage(key: ValueKey('reaberta')));
        expect(find.text('Antes de começar'), findsOneWidget);
        await tap(tester, find.text('Continuar de onde parei'));
        expect(find.text('Sua saúde até hoje'), findsWidgets);
        final sop = find.widgetWithText(CheckboxListTile, comorbidadeSop);
        await tester.ensureVisible(sop);
        expect(tester.widget<CheckboxListTile>(sop).value, isTrue);
        await tap(tester, find.widgetWithText(OutlinedButton, 'Voltar'));
        await tap(tester, find.text('Masculino'));
        expect(find.text('2 / 7'), findsOneWidget);
        await continuar(tester);
        expect(find.text(comorbidadeSop), findsNothing);
        final raw = await tester.runAsync(
          () => Armazenamento.instance.config('pre_consulta_rascunho'),
        );
        final r = (jsonDecode(raw!) as Map)['respostas'] as Map;
        expect(r['saude']['comorbidades'], isEmpty);
        await pump(tester, const PreConsultaPage(key: ValueKey('zero')));
        await tap(tester, find.text('Começar do zero'));
        expect(
          await tester.runAsync(
            () => Armazenamento.instance.config('pre_consulta_rascunho'),
          ),
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'e-mail vai para o consultório com o arquivo e registra envio',
      (tester) async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const canal = MethodChannel('br.com.waldirdev01.plano_cuidado/email');
        Map<Object?, Object?>? pedido;
        var status = 'cancelado';
        messenger.setMockMethodCallHandler(canal, (call) async {
          if (call.method == 'disponivel') return true;
          pedido = call.arguments as Map<Object?, Object?>;
          return status;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(canal, null));
        await tester.runAsync(
          () => Armazenamento.instance.salvarPerfilPaciente(ana),
        );
        await pump(tester, const PreConsultaPage());
        await tap(
          tester,
          find.text('Li e concordo com o termo de consentimento.'),
        );
        for (var i = 0; i < 6; i++) {
          await continuar(tester);
        }
        await tap(tester, find.text('Enviar por e-mail para a médica'));
        expect(pedido!['para'], emailConsultorio);
        expect(
          pedido!['corpo'] as String,
          contains('FORMULÁRIO DE PRÉ-CONSULTA — Ana Exemplo Completo'),
        );
        final p = PreConsulta.parse(
          File(pedido!['arquivo'] as String).readAsStringSync(),
        );
        expect(p.nomePaciente, 'Ana Exemplo Completo');
        expect(
          await tester.runAsync(
            () => Armazenamento.instance.config('pre_consulta_enviada_em'),
          ),
          isNull,
        );
        status = 'enviado';
        await tap(tester, find.text('Enviar por e-mail para a médica'));
        expect(find.text('E-mail enviado à médica.'), findsOneWidget);
        expect(
          await tester.runAsync(
            () => Armazenamento.instance.config('pre_consulta_enviada_em'),
          ),
          isNotNull,
        );
        expect(shared, isEmpty);
      },
    );

    testWidgets('teclado fecha pela tecla de retorno e ao tocar fora', (
      tester,
    ) async {
      await tester.runAsync(
        () => Armazenamento.instance.salvarPerfilPaciente(ana),
      );
      await pump(tester, const PreConsultaPage());
      await tap(
        tester,
        find.text('Li e concordo com o termo de consentimento.'),
      );
      await continuar(tester);
      await escrever(tester, 'Endereço completo', 'Quadra 1');
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await escrever(tester, 'Endereço completo', 'Quadra 1, casa 2');
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.text('Endereço'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('sem plano, a tela inicial oferece a pré-consulta', (
      tester,
    ) async {
      await tester.runAsync(
        () => Armazenamento.instance.salvarPerfilPaciente(ana),
      );
      await pump(tester, HojePage(plano: null, refresh: () async {}));
      await tester.ensureVisible(find.text('Fazer a pré-consulta'));
      await tester.tap(find.text('Fazer a pré-consulta'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Antes de começar'), findsOneWidget);
    });

    testWidgets('etapas aceitam fonte ampliada', (tester) async {
      await tester.runAsync(
        () => Armazenamento.instance.salvarPerfilPaciente(ana),
      );
      await pump(tester, const PreConsultaPage(), scale: 2.6);
      await tap(
        tester,
        find.text('Li e concordo com o termo de consentimento.'),
      );
      for (var i = 0; i < 6; i++) {
        await continuar(tester);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Revisar e enviar'), findsOneWidget);
    });
  });

  group('pacientes da médica', () {
    final ana = PerfilPaciente(
      nome: 'Ana Exemplo Completo',
      nascimento: '1990-01-01',
    );
    File arquivo(String nome, Map<String, dynamic> data) =>
        File('${dir.path}/$nome')..writeAsStringSync(jsonEncode(data));
    PreConsulta preConsulta() {
      final r = PreConsulta.respostasVazias();
      r['medidas'] = {
        'peso': 78.5,
        'altura': 165,
        'cintura': 92,
        'quadril': 104,
      };
      return PreConsulta.criar(ana, r, termoAceitoEm: DateTime.now());
    }

    Future<void> receber(WidgetTester tester, File f) async {
      await tester.runAsync(() async {
        processarArquivoRecebido!(f);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
    }

    Future<void> esperar(WidgetTester tester) async {
      for (
        var i = 0;
        i < 60 &&
            (i < 6 ||
                find.byType(CircularProgressIndicator).evaluate().isNotEmpty);
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    setUp(() {
      final rascunhos = Directory('${dir.path}/rascunhos_pdf');
      if (rascunhos.existsSync()) rascunhos.deleteSync(recursive: true);
    });

    testWidgets('anexo tocado no modo profissional entra na ficha', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final db = Armazenamento.instance;
        await db.setConfig('papel', 'profissional');
        await db.setConfig('profissional_nome', 'Médica Exemplo');
        await db.setConfig('profissional_registro', 'CRM TESTE');
      });
      final f = arquivo('pre-consulta-ana.plano', preConsulta().data);
      await pump(tester, const PlanoCuidadoApp());
      await receber(tester, f);
      expect(find.text('Receber pré-consulta?'), findsOneWidget);
      await tester.tap(find.text('Receber e abrir a ficha'));
      await esperar(tester);
      expect(find.text('Ana Exemplo Completo'), findsOneWidget);
      expect(find.text('Evolução das medidas'), findsOneWidget);
      expect(find.text('28,8'), findsOneWidget);
      expect(find.text('0,88'), findsOneWidget);
      await tap(tester, find.text('Pré-consulta'));
      await esperar(tester);
      expect(find.text('Copiar resumo'), findsOneWidget);
      expect(
        find.textContaining(
          'FORMULÁRIO DE PRÉ-CONSULTA — Ana Exemplo Completo',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await esperar(tester);
      await tester.tap(find.byType(BackButton));
      await esperar(tester);
      await receber(tester, f);
      await tester.tap(find.text('Receber e abrir a ficha'));
      await esperar(tester);
      expect(
        find.text('Este arquivo já foi recebido. Abrindo a ficha.'),
        findsOneWidget,
      );
      final pacientes = await tester.runAsync(
        () => Armazenamento.instance.pacientes(),
      );
      expect(pacientes, hasLength(1));
      expect(
        await tester.runAsync(
          () => Armazenamento.instance.preConsultasDoPaciente(
            pacientes!.single.id,
          ),
        ),
        hasLength(1),
      );
    });

    testWidgets('no modo paciente o arquivo não é aberto', (tester) async {
      await tester.runAsync(() async {
        await Armazenamento.instance.setConfig('papel', 'paciente');
        await Armazenamento.instance.salvarPerfilPaciente(ana);
      });
      final f = arquivo('pre-consulta-ana.plano', preConsulta().data);
      await pump(tester, const PlanoCuidadoApp());
      await receber(tester, f);
      expect(find.text('Receber pré-consulta?'), findsNothing);
      expect(
        find.text(
          'Este arquivo é para a médica, não um plano. Troque para o modo profissional para abri-lo.',
        ),
        findsOneWidget,
      );
      expect(
        await tester.runAsync(() => Armazenamento.instance.pacientes()),
        isEmpty,
      );
    });

    testWidgets('ficha junta plano do PDF e reavaliação aberta pelo seletor', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await Armazenamento.instance.setConfig('papel', 'profissional');
        await ArquivosRascunhoPdf().salvar(rascunhoConferido());
      });
      final reavaliacao = Reavaliacao.criar(
        ana,
        planoId: 'plano-ana',
        itens: ['medidas'],
        respostas: {
          'medidas': {
            'peso': 75,
            'altura': 165,
            'cintura': null,
            'quadril': null,
          },
        },
      );
      picker.file = arquivo('reavaliacao-ana.plano', reavaliacao.data);
      await pump(tester, const PacientesPage());
      expect(find.text('Ana Exemplo Completo'), findsOneWidget);
      expect(find.textContaining('1 registro(s)'), findsOneWidget);
      await tap(tester, find.text('Abrir pré-consulta ou reavaliação'));
      await esperar(tester);
      expect(find.text('Receber reavaliação?'), findsOneWidget);
      await tester.tap(find.text('Receber e abrir a ficha'));
      await esperar(tester);
      expect(find.text('Plano do PDF'), findsOneWidget);
      expect(find.text('Reavaliação'), findsOneWidget);
      expect(find.text('27,5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
