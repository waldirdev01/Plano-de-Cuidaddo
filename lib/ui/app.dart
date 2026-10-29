import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../core/armazenamento.dart';
import '../core/alimentacao.dart';
import '../core/alimentos.dart';
import '../core/edicao_plano.dart';
import '../core/lembretes.dart';
import '../core/native_bridge.dart';
import '../core/importacao_pdf.dart';
import '../core/exportacao_pdf.dart';
import '../core/padrao_pdf.dart';
import '../core/plano.dart';
import '../core/pre_consulta.dart';
import '../core/treino.dart';
import '../core/retorno_acompanhamento.dart';

part 'profissional.dart';
part 'paciente.dart';
part 'alimentacao.dart';
part 'importacao_pdf.dart';
part 'retorno_acompanhamento.dart';
part 'treino.dart';
part 'pre_consulta.dart';
part 'pacientes.dart';
part 'reavaliacao.dart';

const fundo = Color(0xFFF6F4EF);
const verde = Color(0xFF4A5541);
const titulo = Color(0xFF2F3A2A);
const apoio = Color(0xFF6B6A63);
const borda = Color(0xFFE4E1D6);
const alerta = Color(0xFF9C4A3C);
final entradaKey = GlobalKey<_EntradaScreenState>();
Future<void> Function(File)? processarArquivoRecebido;
final fmtDia = DateFormat('dd/MM');
final fmtCompleta = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

class PlanoCuidadoApp extends StatefulWidget {
  const PlanoCuidadoApp({super.key});
  @override
  State<PlanoCuidadoApp> createState() => _PlanoCuidadoAppState();
}

class _PlanoCuidadoAppState extends State<PlanoCuidadoApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Object?>? sub;
  bool importando = false;
  @override
  void initState() {
    super.initState();
    processarArquivoRecebido = _importarArquivo;
    sub = incomingFiles.receiveBroadcastStream().listen((value) {
      if (value is String && mounted) _importarArquivo(File(value));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    sub?.cancel();
    processarArquivoRecebido = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    title: 'Plano de Cuidado',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: fundo,
      colorScheme: ColorScheme.fromSeed(
        seedColor: verde,
        surface: fundo,
        error: alerta,
      ),
      fontFamily: 'Karla',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w600,
          color: titulo,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w600,
          color: titulo,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: fundo,
        foregroundColor: titulo,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: verde,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: verde,
          side: const BorderSide(color: verde),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: verde,
        ),
      ),
    ),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: EntradaScreen(key: entradaKey),
  );

  Future<void> _importarArquivo(File file) async {
    if (importando) return;
    importando = true;
    try {
      final raw = await file.readAsBytes();
      if (raw.length > 20 * 1024 * 1024) {
        throw const FormatException('Selecione um arquivo de até 20 MB.');
      }
      dynamic envelope;
      try {
        envelope = jsonDecode(utf8.decode(raw));
      } on FormatException {
        // Keep the existing PDF/encoding diagnostics in Plano.parseBytes.
      }
      if (envelope is Map &&
          envelope['formato'] == RetornoAcompanhamento.formato) {
        final retorno = RetornoAcompanhamento.parse(utf8.decode(raw));
        if (!mounted) return;
        await _receberRetorno(navigatorKey.currentContext!, retorno);
        return;
      }
      if (envelope is Map && envelope['formato'] == PreConsulta.formato) {
        final p = PreConsulta.parse(utf8.decode(raw));
        if (!mounted) return;
        await _receberPreConsulta(navigatorKey.currentContext!, p);
        return;
      }
      if (envelope is Map && envelope['formato'] == Reavaliacao.formato) {
        final r = Reavaliacao.parse(utf8.decode(raw));
        if (!mounted) return;
        await _receberReavaliacao(navigatorKey.currentContext!, r);
        return;
      }
      final plano = Plano.parseBytes(raw);
      if (await Armazenamento.instance.perfilPaciente() == null) {
        if (!mounted) return;
        await navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (ctx) =>
                CadastroPacientePage(onSaved: () async => Navigator.pop(ctx)),
          ),
        );
      }
      await Armazenamento.instance.conferirDestinatario(plano);
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: navigatorKey.currentContext!,
        builder: (ctx) => AlertDialog(
          title: const Text('Importar plano?'),
          content: Text(
            'Plano de ${plano.nomeProfissional} para ${plano.nomePaciente}. Registros de ${fmtDia.format(plano.inicio)} a ${fmtDia.format(plano.fim)}. Retorno: ${fmtDia.format(plano.retorno)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      await Armazenamento.instance.importar(plano);
      final papel = await Armazenamento.instance.papel();
      if (papel == null || papel.isEmpty) {
        await Armazenamento.instance.setConfig('papel', 'paciente');
      }
      await Lembretes.instance.reagendar(
        plano,
        ativo: await Armazenamento.instance.config('lembretes') != 'nao',
      );
      final asked = await Armazenamento.instance.config(
        'permissao_notificacoes_pedida',
      );
      if (asked != 'sim') {
        await Armazenamento.instance.setConfig(
          'permissao_notificacoes_pedida',
          'sim',
        );
        if (navigatorKey.currentContext!.mounted) {
          await showDialog<void>(
            context: navigatorKey.currentContext!,
            builder: (ctx) => AlertDialog(
              title: const Text('Lembretes do plano'),
              content: const Text(
                'Se você permitir, o app avisa nos horários definidos pela profissional e no dia de enviar a semana. Os lembretes ficam neste aparelho.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
          await Lembretes.instance.pedirPermissao();
        }
      }
      _snack('Plano importado.');
      await entradaKey.currentState?.recarregar();
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(
        'Não foi possível abrir este arquivo. Seus dados não foram alterados.',
      );
    } finally {
      importando = false;
    }
  }

  void _snack(String message) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class EntradaScreen extends StatefulWidget {
  const EntradaScreen({super.key});
  @override
  State<EntradaScreen> createState() => _EntradaScreenState();
}

class _EntradaScreenState extends State<EntradaScreen> {
  String? role;
  Plano? plano;
  int tab = 0;
  bool loading = true;
  bool needsUnlock = false;
  PerfilPaciente? perfil;
  String? bloqueioPlano;
  @override
  void initState() {
    super.initState();
    recarregar();
  }

  Future<void> recarregar() async {
    if (mounted) setState(() => loading = true);
    final db = Armazenamento.instance;
    final stored = await db.papel();
    final active = await db.planoAtivo();
    final patient = await db.perfilPaciente();
    Plano? permitido;
    String? motivo;
    if (active != null && patient != null) {
      try {
        patient.conferir(active);
        permitido = active;
      } on FormatException catch (e) {
        motivo = e.message;
      }
    }
    final shouldLock = await db.config('bloqueio') == 'sim';
    var unlocked = !shouldLock;
    if (shouldLock) {
      try {
        unlocked = await LocalAuthentication().authenticate(
          localizedReason: 'Desbloqueie para abrir seu Plano de Cuidado.',
        );
      } catch (_) {
        unlocked = false;
      }
    }
    await Lembretes.instance.reagendar(
      permitido,
      ativo: await db.config('lembretes') != 'nao',
    );
    if (mounted) {
      setState(() {
        role = stored == '' ? null : stored;
        perfil = patient;
        plano = permitido;
        bloqueioPlano = motivo;
        needsUnlock = !unlocked;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (needsUnlock) {
      return Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              final ok = await LocalAuthentication().authenticate(
                localizedReason: 'Desbloqueie para abrir seu Plano de Cuidado.',
              );
              if (ok && mounted) setState(() => needsUnlock = false);
            },
            icon: const Icon(Icons.lock_open),
            label: const Text('Desbloquear'),
          ),
        ),
      );
    }
    if (role == null) {
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.spa_outlined,
                        size: 68,
                        color: verde,
                        semanticLabel: 'Plano de Cuidado',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Plano de Cuidado',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Seu plano e seus registros ficam neste aparelho.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await Armazenamento.instance.setConfig(
                              'papel',
                              'paciente',
                            );
                            await recarregar();
                          },
                          child: const Text('Sou paciente'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _escolherProfissional(),
                          child: const Text('Sou profissional de saúde'),
                        ),
                      ),
                      const SizedBox(height: 28),
                      OutlinedButton.icon(
                        onPressed: _escolherPlano,
                        icon: const Icon(Icons.file_open),
                        label: const Text('Importar plano'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (role == 'profissional') {
      return ProfissionalPage(refresh: recarregar, planoAtivo: plano);
    }
    if (perfil == null) {
      return CadastroPacientePage(
        onSaved: recarregar,
        onCancel: () async {
          await Armazenamento.instance.setConfig('papel', '');
          await recarregar();
        },
      );
    }
    final hasFood =
        plano?.alimentacao != null ||
        plano?.metasMacro != null ||
        (plano?.refeicoesPrescritas.isNotEmpty ?? false);
    final hasTreino = plano?.data['treino'] != null;
    final abas = <({Widget pagina, NavigationDestination destino})>[
      (
        pagina: HojePage(plano: plano, refresh: recarregar),
        destino: const NavigationDestination(
          icon: Icon(Icons.today_outlined),
          label: 'Hoje',
        ),
      ),
      if (hasFood)
        (
          pagina: plano!.data['alimentacao'] == null
              ? RotinaPrescritaPage(plano: plano!)
              : AlimentacaoPage(plano: plano),
          destino: const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            label: 'Alimentação',
          ),
        ),
      if (hasTreino)
        (
          pagina: TreinoPage(plano: plano!),
          destino: const NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            label: 'Treino',
          ),
        ),
      (
        pagina: SemanaPage(plano: plano),
        destino: const NavigationDestination(
          icon: Icon(Icons.view_week_outlined),
          label: 'Semana',
        ),
      ),
      (
        pagina: MeuPlanoPage(plano: plano),
        destino: const NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: 'Meu plano',
        ),
      ),
      (
        pagina: AjustesPage(refresh: recarregar, plano: plano),
        destino: const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Ajustes',
        ),
      ),
    ];
    final pages = [for (final a in abas) a.pagina];
    final selectedTab = tab >= pages.length ? 0 : tab;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de Cuidado'),
        actions: [
          IconButton(
            tooltip: 'Importar plano',
            onPressed: _escolherPlano,
            icon: const Icon(Icons.file_open),
          ),
        ],
      ),
      body: Column(
        children: [
          if (bloqueioPlano != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                bloqueioPlano!,
                style: const TextStyle(color: alerta),
              ),
            ),
          Expanded(child: pages[selectedTab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [for (final a in abas) a.destino],
      ),
    );
  }

  Future<void> _escolherProfissional() async {
    final nome = TextEditingController(), registro = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perfil profissional'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: registro,
              decoration: const InputDecoration(
                labelText: 'Registro profissional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok == true &&
        nome.text.trim().isNotEmpty &&
        registro.text.trim().isNotEmpty) {
      await Armazenamento.instance.setConfig('papel', 'profissional');
      await Armazenamento.instance.setConfig(
        'profissional_nome',
        nome.text.trim(),
      );
      await Armazenamento.instance.setConfig(
        'profissional_registro',
        registro.text.trim(),
      );
      await recarregar();
    }
  }

  Future<void> _escolherPlano() async {
    try {
      final r = await FilePicker.pickFiles(type: FileType.any);
      if (r.isEmpty) return;
      final f = r.single;
      final bytes = await f.readAsBytes();
      final temp = File(
        '${(await getTemporaryDirectory()).path}/${DateTime.now().microsecondsSinceEpoch}.plano',
      );
      await temp.writeAsBytes(bytes);
      await processarArquivoRecebido?.call(temp);
    } on FormatException catch (e) {
      if (mounted) _message(context, e.message);
    } catch (_) {
      if (mounted) _message(context, 'Não foi possível ler o arquivo.');
    }
  }
}

class HojePage extends StatefulWidget {
  const HojePage({
    super.key,
    required this.plano,
    required this.refresh,
    this.preview = false,
  });
  final Plano? plano;
  final bool preview;
  final Future<void> Function() refresh;
  @override
  State<HojePage> createState() => _HojePageState();
}

class _HojePageState extends State<HojePage> {
  Map<String, dynamic> values = {};
  DateTime day = DateTime.now();
  bool loading = false;
  @override
  void didUpdateWidget(covariant HojePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plano?.id != widget.plano?.id) _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({DateTime? selected}) async {
    if (widget.plano == null) return;
    if (mounted) setState(() => loading = true);
    final p = widget.plano!;
    final today = DateTime.now();
    day = selected ?? DateTime(today.year, today.month, today.day);
    final activeDay = day.isBefore(p.inicio)
        ? p.inicio
        : day.isAfter(p.fim)
        ? p.fim
        : day;
    values = widget.preview
        ? {}
        : await Armazenamento.instance.registros(
            p.id,
            Plano.formatDia(activeDay),
          );
    if (mounted) {
      setState(() {
        day = activeDay;
        loading = false;
      });
    }
  }

  Future<void> _save(String id, Object? value) async {
    final p = widget.plano;
    if (p == null) return;
    setState(() => values[id] = value);
    if (widget.preview) return;
    await Armazenamento.instance.salvarRegistro(
      p.id,
      Plano.formatDia(day),
      id,
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plano;
    if (p == null) return _Vazio(onImport: () => _pickImport(context));
    if (loading) return const Center(child: CircularProgressIndicator());
    final days = Plano.diasEntre(day, p.retorno);
    final readOnly = day.isAfter(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          toBeginningOfSentenceCase(fmtCompleta.format(day))!,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month),
          label: const Text('Escolher dia para marcar'),
          onPressed: DateTime.now().isBefore(p.inicio)
              ? null
              : () async {
                  final now = DateTime.now();
                  final last = now.isBefore(p.fim)
                      ? DateTime(now.year, now.month, now.day)
                      : p.fim;
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: p.inicio,
                    lastDate: last,
                  );
                  if (selected != null) await _load(selected: selected);
                },
        ),
        const Text(
          'Você pode marcar hoje e corrigir os dias anteriores. Dias futuros ficam bloqueados.',
          style: TextStyle(color: apoio),
        ),
        const SizedBox(height: 4),
        Text(
          days >= 0
              ? 'Faltam $days ${days == 1 ? 'dia' : 'dias'} para o retorno'
              : 'Retorno em ${fmtDia.format(p.retorno)}',
          style: const TextStyle(color: apoio, fontSize: 16),
        ),
        const SizedBox(height: 16),
        if (p.data['versao'] == 4)
          OutlinedButton.icon(
            onPressed: widget.preview
                ? null
                : () => _abrirExportacaoAcompanhamento(context, p),
            icon: const Icon(Icons.ios_share),
            label: const Text('Exportar acompanhamento'),
          ),
        if (p.data['versao'] == 4)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Registros até ${fmtDia.format(p.fim)}. Sem marcação significa não confirmado, não prova de que você não fez. Refeições condicionais podem ser dispensadas somente pela regra do plano.',
              style: const TextStyle(color: apoio),
            ),
          ),
        if (p.reavaliacao != null)
          _CartaoReavaliacao(
            key: ValueKey('reavaliacao-${p.id}'),
            plano: p,
            preview: widget.preview,
          ),
        ...p.metas.map(
          (m) => _CampoCard(
            key: ValueKey('${p.id}-${Plano.formatDia(day)}-${m['id']}'),
            field: m,
            value: values[m['id']],
            enabled: !readOnly,
            onChange: (v) => _save(m['id'] as String, v),
          ),
        ),
        ...p.camposDiarios.map(
          (m) => _CampoCard(
            key: ValueKey('${p.id}-${Plano.formatDia(day)}-${m['id']}'),
            field: m,
            value: values[m['id']],
            enabled: !readOnly,
            onChange: (v) => _save(m['id'] as String, v),
          ),
        ),
        ...p.camposRefeicoes.map(
          (m) => _CampoCard(
            key: ValueKey('${p.id}-${Plano.formatDia(day)}-${m['id']}'),
            field: m,
            value: values[m['id']],
            enabled: !readOnly,
            onChange: (v) => _save(m['id'] as String, v),
          ),
        ),
        if (p.metas.isEmpty && p.camposDiarios.isEmpty)
          const Text('Este plano não tem registros diários.'),
        if (readOnly)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Dias futuros ficam bloqueados.',
              style: TextStyle(color: apoio),
            ),
          ),
      ],
    );
  }
}

class SemanaPage extends StatefulWidget {
  const SemanaPage({super.key, required this.plano, this.preview = false});
  final Plano? plano;
  final bool preview;
  @override
  State<SemanaPage> createState() => _SemanaPageState();
}

class _SemanaPageState extends State<SemanaPage> {
  final keyShot = GlobalKey();
  DateTime anchor = DateTime.now();
  Map<String, Map<String, dynamic>> records = {};
  bool busy = false;
  @override
  void didUpdateWidget(covariant SemanaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plano?.id != widget.plano?.id) {
      anchor = widget.plano?.inicio ?? DateTime.now();
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.plano == null) return;
    final p = widget.plano!;
    final range = semanaDoPlano(anchor, p.inicio, p.fim);
    records = widget.preview
        ? {}
        : await Armazenamento.instance.registrosPeriodo(
            p.id,
            range.de,
            range.ate,
          );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plano;
    if (p == null) return _Vazio(onImport: () => _pickImport(context));
    final range = semanaDoPlano(anchor, p.inicio, p.fim);
    final days = diasDoPlano(range.de, range.ate);
    final fields = p.camposRegistraveis;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                onPressed: range.de.isAfter(p.inicio)
                    ? () {
                        anchor = range.de.subtract(const Duration(days: 1));
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${fmtDia.format(range.de)}–${fmtDia.format(range.ate)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Próxima semana',
                onPressed: range.ate.isBefore(p.fim)
                    ? () {
                        anchor = range.ate.add(const Duration(days: 1));
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Toque na data de hoje ou de um dia anterior para marcar. Dias futuros ficam bloqueados.',
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: keyShot,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Semana de ${p.nomePaciente} • ${p.nomeProfissional}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        border: TableBorder.all(color: borda),
                        children: [
                          TableRow(
                            children: [
                              const _Cell('Dia', head: true),
                              ...fields.map(
                                (f) => _Cell(f['titulo'] as String, head: true),
                              ),
                            ],
                          ),
                          ...days.map(
                            (d) => TableRow(
                              children: [
                                _Cell(
                                  '${['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'][d.weekday - 1]} ${fmtDia.format(d)}',
                                  head: true,
                                  onTap: d.isAfter(DateTime.now())
                                      ? null
                                      : () => _editarDia(d, fields),
                                ),
                                ...fields.map(
                                  (f) => _Cell(
                                    _display(
                                      records[Plano.formatDia(d)]?[f['id']
                                          as String],
                                      f,
                                      dia: d,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.data['versao'] == 4)
                  FilledButton.icon(
                    onPressed: widget.preview
                        ? null
                        : () => _abrirExportacaoAcompanhamento(context, p),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Exportar acompanhamento'),
                  ),
                TextButton.icon(
                  onPressed: busy || widget.preview ? null : _sendWeek,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Enviar imagem da semana'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editarDia(
    DateTime day,
    List<Map<String, dynamic>> fields,
  ) async {
    final plan = widget.plano;
    if (plan == null) return;
    final dateKey = Plano.formatDia(day);
    final values = widget.preview
        ? <String, dynamic>{}
        : await Armazenamento.instance.registros(plan.id, dateKey);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Registros de ${fmtDia.format(day)}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fields
                    .map(
                      (field) => _CampoCard(
                        key: ValueKey('$dateKey-${field['id']}'),
                        field: field,
                        value: values[field['id']],
                        enabled: true,
                        onChange: (value) async {
                          update(() => values[field['id'] as String] = value);
                          if (!widget.preview) {
                            await Armazenamento.instance.salvarRegistro(
                              plan.id,
                              dateKey,
                              field['id'] as String,
                              value,
                            );
                          }
                          await _load();
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Concluir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWeek() async {
    final p = widget.plano;
    if (p == null) return;
    setState(() => busy = true);
    try {
      final last = await Armazenamento.instance.ultimoEnvio(p.id);
      final from = last == null
          ? p.inicio
          : Plano.parseDia(last).add(const Duration(days: 1));
      final now = DateTime.now();
      final until = DateTime(now.year, now.month, now.day).isAfter(p.fim)
          ? p.fim
          : DateTime(now.year, now.month, now.day);
      if (from.isAfter(until)) {
        if (!mounted) return;
        _message(context, 'Não há dias novos para enviar.');
        return;
      }
      final map = await Armazenamento.instance.registrosPeriodo(
        p.id,
        from,
        until,
      );
      final days = diasDoPlano(from, until);
      final fields = p.camposRegistraveis;
      final rows = <TableRow>[
        TableRow(
          children: [
            const _Cell('Dia', head: true, fontSize: 20),
            ...fields.map(
              (f) => _Cell(f['titulo'] as String, head: true, fontSize: 20),
            ),
          ],
        ),
        ...days.map(
          (d) => TableRow(
            children: [
              _Cell(fmtDia.format(d), head: true, fontSize: 20),
              ...fields.map(
                (f) => _Cell(
                  _display(
                    map[Plano.formatDia(d)]?[f['id'] as String],
                    f,
                    dia: d,
                  ),
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ];
      final key = GlobalKey();
      final widgetImage = Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Material(
          color: Colors.white,
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: 760,
              color: Colors.white,
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plano de Cuidado',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 26,
                      color: titulo,
                    ),
                  ),
                  Text('Paciente: ${p.nomePaciente}'),
                  Text('Profissional: ${p.nomeProfissional}'),
                  Text(
                    'Período: ${fmtDia.format(from)} a ${fmtDia.format(until)}',
                  ),
                  const SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(color: borda),
                    defaultColumnWidth: const FlexColumnWidth(),
                    columnWidths: const {0: FixedColumnWidth(76)},
                    children: rows,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;
      final overlay = Overlay.of(context);
      final entry = OverlayEntry(
        builder: (_) => Positioned(
          left: -10000,
          top: 0,
          child: Material(child: widgetImage),
        ),
      );
      overlay.insert(entry);
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      entry.remove();
      image.dispose();
      if (bytes == null) throw Exception('Imagem indisponível.');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/semana-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text:
              'Semana de ${p.nomePaciente}, ${fmtDia.format(from)} a ${fmtDia.format(until)}',
        ),
      );
      if (result.status == ShareResultStatus.success && p.data['versao'] != 4) {
        await Armazenamento.instance.registrarEnvio(
          p.id,
          DateTime.now(),
          from,
          until,
        );
      }
    } catch (error, stack) {
      if (mounted) {
        debugPrint('Falha ao gerar imagem da semana: $error\n$stack');
        _message(context, 'Não foi possível preparar a imagem da semana.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class MeuPlanoPage extends StatelessWidget {
  const MeuPlanoPage({super.key, required this.plano});
  final Plano? plano;
  @override
  Widget build(BuildContext context) {
    final p = plano;
    if (p == null) return _Vazio(onImport: () => _pickImport(context));
    final sections = (p.data['secoes'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Meu plano', style: Theme.of(context).textTheme.headlineMedium),
        Text(
          'Para ${p.nomePaciente} • ${p.nomeProfissional}',
          style: const TextStyle(color: apoio, fontSize: 17),
        ),
        const SizedBox(height: 12),
        if (p.data['versao'] == 4)
          Text(
            'Registros de ${fmtDia.format(p.inicio)} a ${fmtDia.format(p.fim)}. Retorno em ${fmtDia.format(p.retorno)}. O PDF é o original importado; as correções da conferência aparecem nos campos do aplicativo, sem reescrever o documento.',
            style: const TextStyle(color: apoio),
          ),
        ...sections
            .where((s) => s['destaque'] == true)
            .map(
              (s) => Card(
                color: const Color(0xFFFFF1EE),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber, color: alerta),
                  title: Text(
                    s['titulo'] as String,
                    style: const TextStyle(
                      color: alerta,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    s['texto'] as String,
                    style: const TextStyle(color: titulo, fontSize: 17),
                  ),
                ),
              ),
            ),
        ...p.metas.map(
          (m) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['titulo'] as String,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (m['descricao'] != null)
                    Text(
                      m['descricao'] as String,
                      style: const TextStyle(fontSize: 17),
                    ),
                  for (final rule in (m['seEntao'] as List? ?? const []))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        rule as String,
                        style: const TextStyle(fontSize: 17, color: verde),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ...sections
            .where((s) => s['destaque'] != true)
            .map(
              (s) => Card(
                child: ListTile(
                  title: Text(
                    s['titulo'] as String,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(
                    s['texto'] as String,
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ),
        if (p.data['pdf'] is Map &&
            (p.data['pdf']['base64'] as String?)?.isNotEmpty == true)
          OutlinedButton.icon(
            onPressed: () => _openPdf(context, p),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Abrir PDF da profissional'),
          ),
        const SizedBox(height: 12),
        const EmergencyNotice(),
      ],
    );
  }
}

const chaveBackupFeito = 'backup_feito_em';

/// The history lives only on this device, so the professional home asks for
/// a copy after this many days.
const diasLembreteBackup = 7;

/// Shares the backup file. Anything but dismissing the sheet (saving to Files
/// included) counts as a copy made.
Future<bool> _exportarBackup(BuildContext context) async {
  final f = await Armazenamento.instance.backup();
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(f.path, mimeType: 'application/octet-stream')],
      text: 'Cópia de segurança do Plano de Cuidado',
    ),
  );
  if (result.status == ShareResultStatus.dismissed) return false;
  await Armazenamento.instance.setConfig(
    chaveBackupFeito,
    DateTime.now().toIso8601String(),
  );
  return true;
}

class AjustesPage extends StatefulWidget {
  const AjustesPage({super.key, required this.refresh, required this.plano});
  final Future<void> Function() refresh;
  final Plano? plano;
  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  bool reminders = true, lock = false;
  PerfilPaciente? perfil;
  List<AcompanhamentoGuardado> savedPlans = [];
  String? selectedPlanId;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    reminders = await Armazenamento.instance.config('lembretes') != 'nao';
    lock = await Armazenamento.instance.config('bloqueio') == 'sim';
    perfil = await Armazenamento.instance.perfilPaciente();
    savedPlans = await Armazenamento.instance.acompanhamentosPaciente();
    selectedPlanId = await Armazenamento.instance.config(
      'acompanhamento_selecionado',
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Configurações', style: Theme.of(context).textTheme.headlineMedium),
      if (savedPlans.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          'Meus acompanhamentos',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('Os registros de cada acompanhamento ficam separados.'),
        ...savedPlans.map((entry) {
          final saved = entry.plano;
          final state = entry.estado;
          return ListTile(
            leading: Icon(
              saved.id == (widget.plano?.id ?? selectedPlanId)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            title: Text('Plano de ${saved.nomeProfissional}'),
            subtitle: Text(
              '${fmtDia.format(saved.inicio)} · ${state == 'encerrado' ? 'Encerrado' : 'Em andamento'}',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Ações do acompanhamento',
              onSelected: (action) async {
                final db = Armazenamento.instance;
                if (action == 'encerrar') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Encerrar acompanhamento?'),
                      content: const Text(
                        'As marcações serão mantidas. Você poderá reativar este acompanhamento depois.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Voltar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Encerrar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await db.encerrarAcompanhamento(saved.id);
                } else if (action == 'reativar') {
                  await db.reativarAcompanhamento(saved.id);
                  await db.selecionarPlano(saved.id);
                } else if (action == 'selecionar') {
                  await db.selecionarPlano(saved.id);
                }
                await widget.refresh();
              },
              itemBuilder: (_) => [
                if (state == 'encerrado')
                  const PopupMenuItem(
                    value: 'reativar',
                    child: Text('Reativar'),
                  )
                else ...[
                  if (saved.id != widget.plano?.id)
                    const PopupMenuItem(
                      value: 'selecionar',
                      child: Text('Selecionar'),
                    ),
                  const PopupMenuItem(
                    value: 'encerrar',
                    child: Text('Encerrar'),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: const Text('Meu cadastro'),
        subtitle: Text(
          perfil == null
              ? 'Nome completo e nascimento'
              : '${perfil!.nome} • ${DateFormat('dd/MM/yyyy').format(Plano.parseDia(perfil!.nascimento))}',
        ),
        onTap: () async {
          final atual = await Armazenamento.instance.perfilPaciente();
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (ctx) => CadastroPacientePage(
                perfil: atual,
                onSaved: () async => Navigator.pop(ctx),
              ),
            ),
          );
          await widget.refresh();
        },
      ),
      ListTile(
        leading: const Icon(Icons.assignment_outlined),
        title: const Text('Pré-consulta', style: TextStyle(fontSize: 17)),
        subtitle: const Text('Formulário para a médica antes da consulta'),
        onTap: () => _abrirPreConsulta(context),
      ),
      if (widget.plano?.reavaliacao != null)
        ListTile(
          leading: const Icon(Icons.event_repeat_outlined),
          title: const Text('Reavaliação', style: TextStyle(fontSize: 17)),
          subtitle: const Text('Atualizar o que a médica pediu'),
          onTap: () => _abrirReavaliacao(context, widget.plano!),
        ),
      SwitchListTile(
        title: const Text('Lembretes locais', style: TextStyle(fontSize: 17)),
        subtitle: const Text('Os horários do plano e os avisos de retorno'),
        value: reminders,
        onChanged: (v) async {
          setState(() => reminders = v);
          await Armazenamento.instance.setConfig(
            'lembretes',
            v ? 'sim' : 'nao',
          );
          if (v) {
            await Lembretes.instance.pedirPermissao();
          }
          await Lembretes.instance.reagendar(widget.plano, ativo: v);
        },
      ),
      SwitchListTile(
        title: const Text(
          'Bloquear com biometria',
          style: TextStyle(fontSize: 17),
        ),
        subtitle: const Text('Usa Face ID ou Touch ID quando disponível'),
        value: lock,
        onChanged: _lock,
      ),
      if (widget.plano != null)
        ...widget.plano!.metas.map(
          (meta) => _EditorLembretes(
            key: ValueKey(meta['id']),
            meta: meta,
            changed: _reschedule,
          ),
        ),
      ListTile(
        leading: const Icon(Icons.history),
        title: const Text('Histórico', style: TextStyle(fontSize: 17)),
        subtitle: const Text('Planos anteriores, somente leitura'),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const _HistoricoPage())),
      ),
      ListTile(
        leading: const Icon(Icons.download_outlined),
        title: const Text(
          'Exportar cópia de segurança',
          style: TextStyle(fontSize: 17),
        ),
        subtitle: const Text('Inclui planos e anotações neste aparelho'),
        onTap: _backup,
      ),
      ListTile(
        leading: const Icon(Icons.restore),
        title: const Text(
          'Restaurar cópia de segurança',
          style: TextStyle(fontSize: 17),
        ),
        onTap: _restore,
      ),
      ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: const Text('Trocar de modo', style: TextStyle(fontSize: 17)),
        onTap: _role,
      ),
      const SizedBox(height: 16),
      const EmergencyNotice(),
    ],
  );
  Future<void> _reschedule() async {
    await Lembretes.instance.reagendar(widget.plano, ativo: reminders);
  }

  Future<void> _lock(bool v) async {
    if (v) {
      try {
        final auth = LocalAuthentication();
        if (!await auth.canCheckBiometrics && !await auth.isDeviceSupported()) {
          throw Exception();
        }
        if (!await auth.authenticate(
          localizedReason: 'Desbloqueie para abrir seu Plano de Cuidado.',
        )) {
          return;
        }
      } catch (_) {
        if (mounted) {
          _message(context, 'Este aparelho não oferece biometria compatível.');
        }
        return;
      }
    }
    await Armazenamento.instance.setConfig('bloqueio', v ? 'sim' : 'nao');
    setState(() => lock = v);
  }

  Future<void> _backup() => _exportarBackup(context);

  Future<void> _restore() async {
    final r = await FilePicker.pickFiles();
    if (r.isEmpty) return;
    try {
      final f = r.single;
      final b = await File(f.path!).readAsBytes();
      await Armazenamento.instance.restaurar(utf8.decode(b));
      await widget.refresh();
      if (mounted) _message(context, 'Cópia restaurada.');
    } catch (_) {
      if (mounted) _message(context, 'Arquivo inválido. Nada foi restaurado.');
    }
  }

  Future<void> _role() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Sou paciente'),
              onTap: () => Navigator.pop(ctx, 'paciente'),
            ),
            ListTile(
              title: const Text('Sou profissional de saúde'),
              onTap: () => Navigator.pop(ctx, 'profissional'),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await Armazenamento.instance.setConfig('papel', selected);
      await widget.refresh();
    }
  }
}

class _EditorLembretes extends StatefulWidget {
  const _EditorLembretes({
    super.key,
    required this.meta,
    required this.changed,
  });
  final Map<String, dynamic> meta;
  final Future<void> Function() changed;
  @override
  State<_EditorLembretes> createState() => _EditorLembretesState();
}

class _EditorLembretesState extends State<_EditorLembretes> {
  List<String> hours = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await Armazenamento.instance.config(
      'horarios_meta_${widget.meta['id']}',
    );
    hours = stored == null
        ? (widget.meta['lembretes'] as List? ?? const []).cast<String>()
        : (jsonDecode(stored) as List).cast<String>();
    if (mounted) setState(() {});
  }

  Future<void> _edit([String? old]) async {
    final p = old?.split(':') ?? const ['09', '00'];
    final start = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    final selected = await showTimePicker(context: context, initialTime: start);
    if (selected == null) return;
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (old != null) hours.remove(old);
      if (!hours.contains(value)) hours.add(value);
      hours.sort();
    });
    await Armazenamento.instance.setConfig(
      'horarios_meta_${widget.meta['id']}',
      jsonEncode(hours),
    );
    await widget.changed();
  }

  Future<void> _remove(String value) async {
    setState(() => hours.remove(value));
    await Armazenamento.instance.setConfig(
      'horarios_meta_${widget.meta['id']}',
      jsonEncode(hours),
    );
    await widget.changed();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.meta['titulo'] as String,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ...hours.map(
                (hour) => InputChip(
                  avatar: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(hour, style: const TextStyle(fontSize: 16)),
                  onPressed: () => _edit(hour),
                  onDeleted: () => _remove(hour),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.add_alarm, size: 18),
                label: const Text('Adicionar horário'),
                onPressed: () => _edit(),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _HistoricoPage extends StatefulWidget {
  const _HistoricoPage();
  @override
  State<_HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<_HistoricoPage> {
  List<Map<String, Object?>> rows = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = Armazenamento.instance;
    final perfil = await db.perfilPaciente();
    final value = await db.planosEncerrados();
    final permitidos = value
        .where(
          (r) => perfil?.corresponde(Plano.parse(r['json'] as String)) == true,
        )
        .toList();
    if (mounted) setState(() => rows = permitidos);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histórico')),
    body: rows.isEmpty
        ? const Center(child: Text('Ainda não há planos anteriores.'))
        : ListView(
            padding: const EdgeInsets.all(12),
            children: rows.map((row) {
              final p = Plano.parse(row['json']! as String);
              return Card(
                child: ListTile(
                  title: Text(
                    p.nomePaciente,
                    style: const TextStyle(fontSize: 17),
                  ),
                  subtitle: Text(
                    '${fmtDia.format(p.inicio)} a ${fmtDia.format(p.fim)} • ${p.nomeProfissional}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Plano anterior')),
                        body: MeuPlanoPage(plano: p),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
  );
}

class _CampoCard extends StatelessWidget {
  const _CampoCard({
    super.key,
    required this.field,
    required this.value,
    required this.enabled,
    required this.onChange,
  });
  final Map<String, dynamic> field;
  final dynamic value;
  final bool enabled;
  final ValueChanged<dynamic> onChange;
  @override
  Widget build(BuildContext context) {
    final type = field['tipo'];
    final count = type == 'contador' && value is num ? value as num : 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field['titulo'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (field['descricao'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  field['descricao'] as String,
                  style: const TextStyle(color: apoio, fontSize: 16),
                ),
              ),
            const SizedBox(height: 8),
            if (type == 'checklist') ..._checklist(context),
            if (field['controleConfirmacao'] == true &&
                value == null &&
                ['contador', 'sim_nao'].contains(type))
              const Text(
                'Ainda não confirmado',
                style: TextStyle(color: apoio),
              ),
            if (type == 'contador')
              Row(
                children: [
                  IconButton(
                    tooltip: 'Diminuir ${field['titulo']}',
                    onPressed: enabled
                        ? () => onChange(count > 0 ? count - 1 : 0)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      '${value ?? 0} ${field['unidade'] ?? ''} (alvo ${field['alvo']})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aumentar ${field['titulo']}',
                    onPressed: enabled ? () => onChange(count + 1) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            if (type == 'contador' && field['controleConfirmacao'] == true)
              TextButton(
                onPressed: enabled ? () => _informarContagem(context) : null,
                child: const Text('Informar quantidade'),
              ),
            if (type == 'sim_nao')
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Sim'),
                    selected: value == true,
                    onSelected: enabled
                        ? (v) => onChange(v ? true : null)
                        : null,
                  ),
                  ChoiceChip(
                    label: const Text('Não'),
                    selected: value == false,
                    onSelected: enabled
                        ? (v) => onChange(v ? false : null)
                        : null,
                  ),
                ],
              ),
            if (type == 'refeicao') ...[
              if (value == 'dispensado' && field['regra'] != 'condicional')
                const Text(
                  'Dispensa registrada anteriormente. A regra atual é obrigatória.',
                  style: TextStyle(color: apoio),
                ),
              Text(
                'Horário: ${field['horario']} · ${field['regra'] == 'condicional' ? 'Condicional' : 'Obrigatória'}',
              ),
              if (field['regra'] == 'condicional')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Pode dispensar: ${field['condicao']}',
                    style: const TextStyle(color: verde),
                  ),
                ),
              if (value == null)
                const Text(
                  'Ainda não confirmado',
                  style: TextStyle(color: apoio),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in {
                    'feito': 'Fiz',
                    'nao_feito': 'Não fiz',
                    if (field['regra'] == 'condicional')
                      'dispensado': 'Dispensado conforme plano',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: value == entry.key,
                      onSelected: enabled
                          ? (selected) => onChange(selected ? entry.key : null)
                          : null,
                    ),
                ],
              ),
            ],
            if (type == 'texto')
              TextFormField(
                initialValue: value as String?,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: field['ajuda'] as String? ?? 'Toque para anotar',
                  hintMaxLines: 3,
                ),
                onChanged: onChange,
              ),
            if (type == 'escala')
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (
                    var n = (field['min'] as num).toInt();
                    n <= (field['max'] as num).toInt();
                    n++
                  )
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: ChoiceChip(
                        label: Text('$n'),
                        selected: value == n,
                        onSelected: enabled ? (_) => onChange(n) : null,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _informarContagem(BuildContext context) async {
    final controller = TextEditingController(
      text: value == null ? '' : '$value',
    );
    final form = GlobalKey<FormState>();
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(field['titulo'] as String),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quantidade realizada',
                helperText: field['unidade'] as String,
              ),
              validator: (value) {
                final n = num.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );
                return n == null || !n.isFinite || n < 0
                    ? 'Informe um número válido, maior ou igual a zero.'
                    : null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  ctx,
                  num.parse(controller.text.trim().replaceAll(',', '.')),
                );
              }
            },
            child: const Text('Registrar quantidade'),
          ),
        ],
      ),
    );
    if (result != null) onChange(result);
  }

  List<Widget> _checklist(BuildContext context) {
    final items = (field['itens'] as List).cast<String>();
    final values = (value as List? ?? const []).cast<String>();
    return items
        .map<Widget>(
          (item) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item, style: const TextStyle(fontSize: 17)),
              value: values.contains(item),
              onChanged: enabled
                  ? (v) {
                      final next = [...values];
                      v == true ? next.add(item) : next.remove(item);
                      onChange(next);
                    }
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        )
        .toList();
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.head = false, this.onTap, this.fontSize = 15});
  final String text;
  final bool head;
  final VoidCallback? onTap;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 68, minHeight: 48),
    color: head ? const Color(0xFFF1F0EA) : Colors.white,
    padding: const EdgeInsets.all(8),
    alignment: Alignment.centerLeft,
    child: InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: head ? FontWeight.w700 : FontWeight.normal,
          color: titulo,
        ),
      ),
    ),
  );
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.onImport});
  final VoidCallback onImport;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description_outlined, size: 60, color: verde),
          const SizedBox(height: 12),
          Text(
            'Importe seu plano',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'A profissional enviou um arquivo .plano? Abra por aqui ou toque no arquivo recebido.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.file_open),
            label: const Text('Importar plano'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ainda não teve a primeira consulta?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _abrirPreConsulta(context),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Fazer a pré-consulta'),
          ),
        ],
      ),
    ),
  );
}

class EmergencyNotice extends StatelessWidget {
  const EmergencyNotice({super.key});
  @override
  Widget build(BuildContext context) => const Card(
    color: Color(0xFFFFF1EE),
    child: Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'Este app não é canal de urgência. Em emergência, ligue 192.',
        style: TextStyle(
          color: alerta,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

String _display(dynamic v, Map<String, dynamic> f, {DateTime? dia}) {
  if (v == null && dia != null && dia.isAfter(DateTime.now())) return '—';
  if (f['tipo'] == 'refeicao') {
    return switch (v) {
      'feito' => 'Feito',
      'nao_feito' => 'Não feito',
      'dispensado' =>
        f['regra'] == 'condicional'
            ? 'Dispensado conforme plano'
            : 'Dispensado (regra anterior)',
      _ => 'Não confirmado',
    };
  }
  if (v == null) {
    return f['controleConfirmacao'] == true ? 'Não confirmado' : '—';
  }
  if (v is List) return v.join(', ');
  if (v is bool) return v ? 'Sim' : 'Não';
  if (f['tipo'] == 'contador') return '$v ${f['unidade'] ?? ''}';
  return '$v';
}

Future<void> _pickImport(BuildContext context) async {
  try {
    final r = await FilePicker.pickFiles();
    if (r.isEmpty) return;
    final file = r.single;
    final bytes = await file.readAsBytes();
    final temp = File(
      '${(await getTemporaryDirectory()).path}/${DateTime.now().microsecondsSinceEpoch}.plano',
    );
    await temp.writeAsBytes(bytes);
    await processarArquivoRecebido?.call(temp);
  } catch (e) {
    if (context.mounted) {
      _message(
        context,
        e is FormatException
            ? e.message
            : 'Arquivo inválido. Nada foi alterado.',
      );
    }
  }
}

void _message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<void> _openPdf(BuildContext context, Plano p) async {
  File? file;
  try {
    final raw = p.data['pdf'] as Map;
    final bytes = base64Decode(raw['base64'] as String);
    final dir = await getApplicationSupportDirectory();
    file = File('${dir.path}/${raw['nome'] ?? 'plano.pdf'}');
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _PdfPage(path: file!.path)));
  } catch (_) {
    if (file != null && await file.exists()) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
      );
    } else if (context.mounted) {
      _message(context, 'Não foi possível preparar o PDF deste plano.');
    }
  }
}

class _PdfPage extends StatefulWidget {
  const _PdfPage({required this.path});
  final String path;
  @override
  State<_PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<_PdfPage> {
  late final controller = PdfControllerPinch(
    document: PdfDocument.openFile(widget.path),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PDF do plano')),
    body: PdfViewPinch(controller: controller),
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
