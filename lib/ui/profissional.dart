part of 'app.dart';

const _diasSemana = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];
const _tiposCampos = {
  'checklist': 'Lista de marcações',
  'contador': 'Contador',
  'sim_nao': 'Sim ou não',
  'texto': 'Texto livre',
  'escala': 'Escala de notas',
};

class ProfissionalPage extends StatefulWidget {
  const ProfissionalPage({super.key, required this.refresh, this.planoAtivo});
  final Future<void> Function() refresh;
  final Plano? planoAtivo;
  @override
  State<ProfissionalPage> createState() => _ProfissionalPageState();
}

class _ProfissionalPageState extends State<ProfissionalPage> {
  List<Plano> plans = [];
  String search = '', nome = '', registro = '';
  bool loading = true;
  bool importandoPdf = false;
  final arquivosPdf = ArquivosRascunhoPdf();
  List<RascunhoPdf> rascunhosPdf = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = Armazenamento.instance;
    final list = await db.planosCriados();
    final name = await db.config('profissional_nome') ?? '';
    final reg = await db.config('profissional_registro') ?? '';
    final drafts = await arquivosPdf.listar();
    if (!mounted) return;
    setState(() {
      plans = list;
      nome = name;
      registro = reg;
      loading = false;
      rascunhosPdf = drafts;
    });
    if (nome.isEmpty || registro.isEmpty) await _perfil();
  }

  Future<void> _perfil() async {
    final n = TextEditingController(text: nome),
        r = TextEditingController(text: registro);
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perfil profissional'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: n,
                  decoration: const InputDecoration(
                    labelText: 'Nome profissional',
                  ),
                  validator: _obrigatorio,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: r,
                  decoration: const InputDecoration(
                    labelText: 'Registro profissional (CRM, CRN...)',
                  ),
                  validator: _obrigatorio,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Salvar perfil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      nome = n.text.trim();
      registro = r.text.trim();
      await Armazenamento.instance.setConfig('profissional_nome', nome);
      await Armazenamento.instance.setConfig('profissional_registro', registro);
      if (mounted) setState(() {});
    }
    // Dialog exit animation still reads its text controllers.
  }

  Future<void> _editar({Plano? plano, bool duplicar = false}) async {
    if (plano?.data['versao'] == 4) {
      _message(
        context,
        'Este plano veio de uma conferência de PDF. Edite o rascunho em Rascunhos de PDF e conclua novamente antes de exportar. Para outro paciente, preencha e importe um novo PDF.',
      );
      return;
    }
    if (nome.isEmpty || registro.isEmpty) {
      await _perfil();
      if (nome.isEmpty || registro.isEmpty) return;
    }
    if (!mounted) return;
    final data = plano == null
        ? novoPlano(nome, registro)
        : duplicar
        ? duplicarPlano(plano, nome, registro)
        : copiarDados(plano.data);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorPlanoPage(data: data)),
    );
    await _load();
    await widget.refresh();
  }

  Future<void> _conferirPdf(RascunhoPdf draft) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ConferenciaPdfPage(rascunho: draft, arquivos: arquivosPdf),
      ),
    );
    await _load();
  }

  Future<void> _importarPdf() async {
    setState(() => importandoPdf = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final file = files.single;
      if ((await file.length() ?? 0) > 10 * 1024 * 1024) {
        throw const FormatException('Selecione um PDF de até 10 MB.');
      }
      final bytes = await file.readAsBytes();
      final texto = await TextoPdf.ler(bytes);
      final draft = RascunhoPdf.analisar(
        texto,
        nomeArquivo: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      await _conferirPdf(draft);
    } on FormatException catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PDF fora do padrão'),
            content: SingleChildScrollView(child: Text(e.message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'Não foi possível importar este PDF. Os planos existentes não foram alterados.',
        );
      }
    } finally {
      if (mounted) setState(() => importandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = plans
        .where(
          (p) => p.nomePaciente.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus planos'),
        actions: [
          IconButton(
            tooltip: 'Editar perfil profissional',
            onPressed: _perfil,
            icon: const Icon(Icons.badge_outlined),
          ),
          IconButton(
            tooltip: 'Configurações',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Ajustes')),
                    body: AjustesPage(
                      refresh: widget.refresh,
                      plano: widget.planoAtivo,
                    ),
                  ),
                ),
              );
              await _load();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '$nome · $registro',
                  style: const TextStyle(color: apoio, fontSize: 17),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar pelo nome do paciente',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Acompanhamentos recebidos'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RetornosRecebidosPage(),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: importandoPdf ? null : _importarPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    importandoPdf
                        ? 'Lendo PDF neste aparelho…'
                        : 'Importar PDF do plano',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Use o modelo PLANO-CUIDADO/1 com texto selecionável. Importe, confira, conclua e exporte o .plano para o paciente com o app atualizado.',
                    style: TextStyle(color: apoio),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Regras do modelo PDF'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Modelo PLANO-CUIDADO/1'),
                      content: const SingleChildScrollView(
                        child: Text(
                          'Preencha uma cópia do modelo editável e exporte como PDF com texto selecionável. Não renomeie os rótulos ou marcadores.\n\n'
                          'Datas: DD/MM/AAAA. Horários: HH:MM. Identifique o paciente pelo nome completo e nascimento.\n\n'
                          'Metas diárias: REFEICOES, CONTAGEM ou CONFIRMACAO. De uma a oito metas e até oito refeições.\n\n'
                          'Na CONTAGEM, a soma de HH:MM=quantidade deve igualar a quantidade diária. Use LIVRE se não houver distribuição fixa. Lembretes são horários separados, ou NENHUM.\n\n'
                          'Refeição OBRIGATORIA usa condição NAO SE APLICA. Refeição CONDICIONAL exige a condição de dispensa.\n\n'
                          'Link pessoal: endereço completo com https e #p=..., ou NENHUM.\n\n'
                          'Textos em ORIENTACOES LIVRES são somente referência. Não viram tarefas, doses ou alarmes. Não há interpretação clínica ou IA.\n\n'
                          'Após concluir e salvar a conferência, use Exportar .plano conferido. O paciente importa no app atualizado e permite os lembretes. Sem confirmação não é prova de que a ação não foi feita.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Entendi'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (rascunhosPdf.isNotEmpty) ...[
                  Text(
                    'Rascunhos de PDF',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...rascunhosPdf.map(
                    (r) => Card(
                      child: ListTile(
                        title: Text(
                          r.nome.isEmpty ? 'Paciente a conferir' : r.nome,
                        ),
                        subtitle: Text(
                          '${r.estado == 'conferido' ? 'Conferência concluída' : 'Em conferência'} · ${r.data['pdf']['nome']}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _conferirPdf(r),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: () => _editar(),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar plano'),
                ),
                if (widget.planoAtivo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _editar(plano: widget.planoAtivo, duplicar: true),
                      icon: const Icon(Icons.copy),
                      label: const Text('Usar plano importado como modelo'),
                    ),
                  ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Crie um plano para começar. Os planos ficam salvos neste aparelho.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...filtered.map(
                  (p) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nomePaciente,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${fmtDia.format(p.inicio)} a ${fmtDia.format(p.retorno)} · ${p.metas.length} metas',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () => _editar(plano: p),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar'),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _editar(plano: p, duplicar: true),
                                icon: const Icon(Icons.copy),
                                label: const Text('Duplicar'),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PreviaPlanoPage(plano: p),
                                  ),
                                ),
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text('Pré-visualizar'),
                              ),
                              TextButton.icon(
                                onPressed: () => _exportarPlano(context, p),
                                icon: const Icon(Icons.ios_share),
                                label: const Text('Exportar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const EmergencyNotice(),
              ],
            ),
    );
  }
}

String? _obrigatorio(String? v) =>
    v == null || v.trim().isEmpty ? 'Preencha este campo.' : null;

Future<void> _exportarPlano(BuildContext context, Plano plano) async {
  try {
    // Never downgrade a contract: v4 semantics must not be ignored by old apps.
    final dados = copiarDados(plano.data);
    Plano.parse(jsonEncode(dados));
    final dir = await getTemporaryDirectory();
    final file = await File(
      '${dir.path}/${nomeArquivoPlano(plano)}',
    ).writeAsString(jsonEncode(dados), encoding: utf8);
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } on FormatException catch (e) {
    if (context.mounted) _message(context, e.message);
  } catch (_) {
    if (context.mounted) {
      _message(
        context,
        'Não foi possível exportar o plano. O plano salvo continua neste aparelho.',
      );
    }
  }
}

class EditorPlanoPage extends StatefulWidget {
  const EditorPlanoPage({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  State<EditorPlanoPage> createState() => _EditorPlanoPageState();
}

class _EditorPlanoPageState extends State<EditorPlanoPage> {
  final form = GlobalKey<FormState>();
  late Map<String, dynamic> data;
  late TextEditingController paciente, nascimento, profissional, registro;
  late String baseline;
  bool saving = false, leaving = false;
  List<Map<String, dynamic>> get metas =>
      (data['metas'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get diarios =>
      (data['camposDiarios'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get secoes =>
      (data['secoes'] as List).cast<Map<String, dynamic>>();
  AlimentacaoPlano? get alimentacao {
    final raw = data['alimentacao'];
    return raw is Map ? AlimentacaoPlano.fromMap(raw) : null;
  }

  @override
  void initState() {
    super.initState();
    data = copiarDados(widget.data);
    data.putIfAbsent('metas', () => <Map<String, dynamic>>[]);
    data.putIfAbsent('camposDiarios', () => <Map<String, dynamic>>[]);
    data.putIfAbsent('secoes', () => <Map<String, dynamic>>[]);
    data.putIfAbsent('envioSemanal', () => {'diaDaSemana': 5, 'ate': '18:00'});
    paciente = TextEditingController(text: data['paciente']['nome'] as String);
    final birth = data['paciente']['nascimento'] as String?;
    nascimento = TextEditingController(
      text: birth == null || birth.isEmpty
          ? ''
          : DateFormat('dd/MM/yyyy').format(Plano.parseDia(birth)),
    );
    profissional = TextEditingController(
      text: data['profissional']['nome'] as String,
    );
    registro = TextEditingController(
      text: data['profissional']['registro'] as String,
    );
    baseline = jsonEncode(data);
  }

  @override
  void dispose() {
    paciente.dispose();
    nascimento.dispose();
    profissional.dispose();
    registro.dispose();
    super.dispose();
  }

  void _sync() {
    data['paciente']['nome'] = paciente.text.trim();
    data['versao'] = 3;
    try {
      data['paciente']['nascimento'] = _nascimentoIso(nascimento.text);
    } on FormatException {
      data['paciente']['nascimento'] = nascimento.text;
    }
    data['profissional'] = {
      'nome': profissional.text.trim(),
      'registro': registro.text.trim(),
    };
  }

  Plano? _validar() {
    _sync();
    if (!form.currentState!.validate()) {
      _message(context, 'Confira os campos obrigatórios.');
      return null;
    }
    try {
      return Plano.parse(jsonEncode(data));
    } on FormatException catch (e) {
      _message(context, e.message);
      return null;
    }
  }

  Future<Plano?> _salvar() async {
    final p = _validar();
    if (p == null) return null;
    setState(() => saving = true);
    try {
      await Armazenamento.instance.salvarCriado(p);
      baseline = jsonEncode(data);
      if (mounted) _message(context, 'Plano salvo neste aparelho.');
      return p;
    } catch (_) {
      if (mounted) {
        _message(context, 'Não foi possível salvar. Tente novamente.');
      }
      return null;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _sair() async {
    _sync();
    if (jsonEncode(data) != baseline) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sair sem salvar?'),
          content: const Text(
            'As alterações desde o último salvamento serão descartadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar alterações'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _data(bool inicio) async {
    final old = Plano.parseDia(
      inicio ? data['inicio'] as String : data['retorno']['data'] as String,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: old,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked != null) {
      setState(() {
        if (inicio) {
          data['inicio'] = Plano.formatDia(picked);
        } else {
          data['retorno']['data'] = Plano.formatDia(picked);
        }
      });
    }
  }

  Future<void> _hora(bool retorno) async {
    final old =
        (retorno
                ? data['retorno']['hora'] ?? '13:30'
                : data['envioSemanal']['ate'])
            as String;
    final parts = old.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (picked != null) {
      setState(() {
        final hour =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (retorno) {
          data['retorno']['hora'] = hour;
        } else {
          data['envioSemanal']['ate'] = hour;
        }
      });
    }
  }

  Future<void> _campo(bool diario, {int? index}) async {
    final list = diario ? diarios : metas;
    Map<String, dynamic>? field;
    if (index != null) {
      field = list[index];
    } else {
      final model = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  [
                        'Criar do zero',
                        'Refeições à mesa',
                        'Água',
                        'Atividade física',
                        'Emoção ao comer',
                        'Nota do dia',
                      ]
                      .map(
                        (m) => ListTile(
                          title: Text(m),
                          onTap: () => Navigator.pop(ctx, m),
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
      );
      if (model == null) return;
      field = modeloCampo(model);
    }
    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CampoEditor(field: field!, diario: diario),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        (data[diario ? 'camposDiarios' : 'metas'] as List).add(result);
      } else {
        (data[diario ? 'camposDiarios' : 'metas'] as List)[index] = result;
      }
    });
  }

  Future<void> _secao({int? index}) async {
    final old = index == null ? null : secoes[index];
    final title = TextEditingController(text: old?['titulo'] as String? ?? '');
    final text = TextEditingController(text: old?['texto'] as String? ?? '');
    bool highlight = old?['destaque'] == true;
    final key = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Seção do plano'),
          content: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Título da seção',
                    ),
                    validator: _obrigatorio,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: text,
                    decoration: const InputDecoration(
                      labelText: 'Texto da seção',
                    ),
                    minLines: 3,
                    maxLines: 12,
                    validator: _obrigatorio,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Destacar como alerta'),
                    value: highlight,
                    onChanged: (v) => update(() => highlight = v),
                  ),
                ],
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
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Salvar seção'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      setState(() {
        final s = {
          'titulo': title.text.trim(),
          'texto': text.text.trim(),
          'destaque': highlight,
        };
        if (index == null) {
          (data['secoes'] as List).add(s);
        } else {
          (data['secoes'] as List)[index] = s;
        }
      });
    }
  }

  Future<void> _pdf() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty) return;
      final file = result.single;
      if (file.path == null) {
        throw const FormatException('Não foi possível ler o arquivo.');
      }
      final bytes = await File(file.path!).readAsBytes();
      if (bytes.length < 5 ||
          ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-') {
        throw const FormatException('Selecione um documento PDF válido.');
      }
      if (mounted) {
        setState(
          () =>
              data['pdf'] = {'nome': file.name, 'base64': base64Encode(bytes)},
        );
      }
    } catch (e) {
      if (mounted) {
        _message(
          context,
          e is FormatException ? e.message : 'Não foi possível anexar o PDF.',
        );
      }
    }
  }

  Future<void> _importarAlimentacao() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty) return;
      final file = result.single;
      if (file.path == null) {
        throw const FormatException('Não foi possível ler o arquivo.');
      }
      final raw = jsonDecode(utf8.decode(await File(file.path!).readAsBytes()));
      if (raw is! Map) {
        throw const FormatException(
          'O arquivo de alimentação não é um JSON válido.',
        );
      }
      final block = raw['alimentacao'] is Map ? raw['alimentacao'] : raw;
      if (block is! Map) {
        throw const FormatException('Bloco de alimentação ausente.');
      }
      AlimentacaoPlano.fromMap(block);
      setState(
        () =>
            data['alimentacao'] = copiarDados(Map<String, dynamic>.from(block)),
      );
      if (mounted) _message(context, 'Rotina alimentar importada.');
    } catch (e) {
      if (mounted) {
        _message(
          context,
          e is FormatException
              ? e.message
              : 'Não foi possível importar a alimentação.',
        );
      }
    }
  }

  void _modeloAlimentacao() {
    final sample = AlimentacaoPlano.modeloTeste();
    setState(() => data['alimentacao'] = sample);
    _message(
      context,
      'Modelo de alimentação de teste carregado. Revise antes de exportar.',
    );
  }

  Future<void> _remover(String key, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover do plano?'),
        content: const Text(
          'A remoção será aplicada quando você salvar o plano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => (data[key] as List).removeAt(index));
  }

  Widget _blocoCampos(String key, String title, bool diario) {
    final list = (data[key] as List).cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        ...list.asMap().entries.map(
          (e) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.value['titulo'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(_tiposCampos[e.value['tipo']]!),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _campo(diario, index: e.key),
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                      ),
                      TextButton.icon(
                        onPressed: () => _remover(key, e.key),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remover'),
                      ),
                      IconButton(
                        tooltip: 'Mover para cima',
                        onPressed: e.key == 0
                            ? null
                            : () => setState(() {
                                final items = data[key] as List;
                                final item = items.removeAt(e.key);
                                items.insert(e.key - 1, item);
                              }),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: 'Mover para baixo',
                        onPressed: e.key == list.length - 1
                            ? null
                            : () => setState(() {
                                final items = data[key] as List;
                                final item = items.removeAt(e.key);
                                items.insert(e.key + 1, item);
                              }),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _campo(diario),
          icon: const Icon(Icons.add),
          label: Text(diario ? 'Adicionar anotação diária' : 'Adicionar meta'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _sair();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Editar plano'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opções do plano',
            onSelected: (action) async {
              if (saving) return;
              if (action == 'salvar') {
                await _salvar();
              }
              if (action == 'previa') {
                final p = _validar();
                if (p != null && context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PreviaPlanoPage(plano: p),
                    ),
                  );
                }
              }
              if (action == 'exportar') {
                final p = await _salvar();
                if (p != null && context.mounted) {
                  await _exportarPlano(context, p);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'salvar', child: Text('Salvar plano')),
              PopupMenuItem(value: 'previa', child: Text('Pré-visualizar')),
              PopupMenuItem(value: 'exportar', child: Text('Exportar .plano')),
            ],
          ),
        ],
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Paciente e profissional',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextFormField(
              controller: paciente,
              decoration: const InputDecoration(
                labelText: 'Nome do paciente',
                helperText: 'Nome completo, igual ao cadastro do paciente',
              ),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 12),
            CampoNascimento(controller: nascimento),
            const SizedBox(height: 12),
            TextFormField(
              controller: profissional,
              decoration: const InputDecoration(
                labelText: 'Nome da profissional',
              ),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: registro,
              decoration: const InputDecoration(
                labelText: 'Registro profissional',
              ),
              validator: _obrigatorio,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Início do plano'),
              subtitle: Text(
                DateFormat(
                  'dd/MM/yyyy',
                ).format(Plano.parseDia(data['inicio'] as String)),
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _data(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data do retorno'),
              subtitle: Text(
                DateFormat(
                  'dd/MM/yyyy',
                ).format(Plano.parseDia(data['retorno']['data'] as String)),
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _data(false),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora do retorno'),
              subtitle: Text(data['retorno']['hora'] as String? ?? '13:30'),
              trailing: const Icon(Icons.schedule),
              onTap: () => _hora(true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: data['envioSemanal']['diaDaSemana'] as int,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Dia do envio semanal',
              ),
              items: List.generate(
                7,
                (i) => DropdownMenuItem(value: i, child: Text(_diasSemana[i])),
              ),
              onChanged: (v) =>
                  setState(() => data['envioSemanal']['diaDaSemana'] = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Horário-limite do envio'),
              subtitle: Text(data['envioSemanal']['ate'] as String),
              trailing: const Icon(Icons.schedule),
              onTap: () => _hora(false),
            ),
            const SizedBox(height: 24),
            _blocoCampos('metas', 'Metas', false),
            _blocoCampos('camposDiarios', 'Anotações do dia', true),
            Text(
              'Seções de texto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...secoes.asMap().entries.map(
              (e) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.value['titulo'] as String,
                        style: const TextStyle(fontSize: 18),
                      ),
                      if (e.value['destaque'] == true)
                        const Text(
                          'Destaque de alerta',
                          style: TextStyle(color: alerta),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _secao(index: e.key),
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar'),
                          ),
                          TextButton.icon(
                            onPressed: () => _remover('secoes', e.key),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remover'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _secao,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar seção'),
            ),
            const SizedBox(height: 24),
            Text(
              'Documento completo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (data['pdf'] != null) ...[
              Text(data['pdf']['nome'] as String),
              TextButton.icon(
                onPressed: () => setState(() => data.remove('pdf')),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover PDF'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _pdf,
              icon: const Icon(Icons.attach_file),
              label: Text(data['pdf'] == null ? 'Anexar PDF' : 'Trocar PDF'),
            ),
            const SizedBox(height: 24),
            Text(
              'Rotina alimentar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (alimentacao != null) ...[
              Text(alimentacao!.titulo),
              Text(
                '${alimentacao!.refeicoes.length} refeições · rotina mensal',
              ),
              TextButton.icon(
                onPressed: () => setState(() => data.remove('alimentacao')),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover rotina alimentar'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _importarAlimentacao,
              icon: const Icon(Icons.file_open),
              label: const Text('Importar JSON da calculadora'),
            ),
            OutlinedButton.icon(
              onPressed: _modeloAlimentacao,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Carregar modelo de teste'),
            ),
            const Text(
              'O JSON pode ser gerado a partir do material revisado pela profissional. O modelo de teste serve apenas para experimentar o fluxo.',
              style: TextStyle(color: apoio, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: saving ? null : _salvar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar plano'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () {
                      final p = _validar();
                      if (p != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreviaPlanoPage(plano: p),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Pré-visualizar como paciente'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final p = await _salvar();
                      if (p != null && context.mounted) {
                        await _exportarPlano(context, p);
                      }
                    },
              icon: const Icon(Icons.ios_share),
              label: const Text('Exportar .plano'),
            ),
            const SizedBox(height: 16),
            const EmergencyNotice(),
          ],
        ),
      ),
    ),
  );
}

class _CampoEditor extends StatefulWidget {
  const _CampoEditor({required this.field, required this.diario});
  final Map<String, dynamic> field;
  final bool diario;
  @override
  State<_CampoEditor> createState() => _CampoEditorState();
}

class _CampoEditorState extends State<_CampoEditor> {
  final form = GlobalKey<FormState>();
  late String tipo;
  late TextEditingController title,
      description,
      rules,
      items,
      hours,
      target,
      unit,
      min,
      max,
      help;
  @override
  void initState() {
    super.initState();
    final f = widget.field;
    tipo = f['tipo'] as String;
    title = TextEditingController(text: f['titulo'] as String? ?? '');
    description = TextEditingController(text: f['descricao'] as String? ?? '');
    help = TextEditingController(text: f['ajuda'] as String? ?? '');
    rules = TextEditingController(
      text: (f['seEntao'] as List? ?? []).join('\n'),
    );
    items = TextEditingController(text: (f['itens'] as List? ?? []).join('\n'));
    hours = TextEditingController(
      text: (f['lembretes'] as List? ?? []).join('\n'),
    );
    target = TextEditingController(text: '${f['alvo'] ?? 0}');
    unit = TextEditingController(text: f['unidade'] as String? ?? '');
    min = TextEditingController(text: '${f['min'] ?? 1}');
    max = TextEditingController(text: '${f['max'] ?? 10}');
  }

  @override
  void dispose() {
    for (final c in [
      title,
      description,
      rules,
      items,
      hours,
      target,
      unit,
      min,
      max,
      help,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _linhas(TextEditingController c) => c.text
      .split(RegExp(r'[\n;,]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  void _salvar() {
    if (!form.currentState!.validate()) return;
    final f = <String, dynamic>{
      'id': tipo == widget.field['tipo'] ? widget.field['id'] : novoId(),
      'titulo': title.text.trim(),
      'tipo': tipo,
      'descricao': description.text.trim(),
      'ajuda': help.text.trim(),
    };
    if (!widget.diario) {
      f['seEntao'] = rules.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      f['lembretes'] = _linhas(hours);
    }
    if (tipo == 'checklist') f['itens'] = _linhas(items);
    if (tipo == 'contador') {
      f['alvo'] = num.parse(target.text.replaceAll(',', '.'));
      f['unidade'] = unit.text.trim();
    }
    if (tipo == 'escala') {
      f['min'] = int.parse(min.text);
      f['max'] = int.parse(max.text);
    }
    Navigator.pop(context, f);
  }

  Widget _texto(
    TextEditingController c,
    String label, {
    bool required = false,
    int lines = 1,
    String? hint,
  }) => TextFormField(
    controller: c,
    decoration: InputDecoration(
      labelText: label,
      helperText: hint,
      helperMaxLines: 4,
    ),
    minLines: lines,
    maxLines: lines == 1 ? 1 : 8,
    validator: required ? _obrigatorio : null,
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.diario ? 'Anotação diária' : 'Meta'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _texto(title, 'Título', required: true),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de campo'),
                items: _tiposCampos.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => tipo = v!),
              ),
              if (tipo != widget.field['tipo'])
                const Text(
                  'O novo tipo terá registros próprios. As anotações anteriores continuam no backup.',
                  style: TextStyle(color: apoio),
                ),
              const SizedBox(height: 14),
              _texto(description, 'Descrição', lines: 2),
              const SizedBox(height: 14),
              _texto(help, 'Texto de ajuda', lines: 2),
              if (tipo == 'checklist')
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextFormField(
                    controller: items,
                    decoration: const InputDecoration(
                      labelText: 'Itens (um por linha)',
                    ),
                    minLines: 3,
                    maxLines: 8,
                    validator: (_) => _linhas(items).isEmpty
                        ? 'Informe pelo menos um item.'
                        : _linhas(items).toSet().length != _linhas(items).length
                        ? 'Use itens diferentes.'
                        : null,
                  ),
                ),
              if (tipo == 'contador') ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextFormField(
                    controller: target,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade-alvo',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                      return n == null || !n.isFinite || n < 0
                          ? 'Informe um número positivo ou zero.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _texto(unit, 'Unidade (copos, minutos...)', required: true),
              ],
              if (tipo == 'escala') ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextFormField(
                    controller: min,
                    decoration: const InputDecoration(labelText: 'Nota mínima'),
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v ?? '') == null
                        ? 'Informe um número inteiro.'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: max,
                  decoration: const InputDecoration(labelText: 'Nota máxima'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final a = int.tryParse(min.text), b = int.tryParse(v ?? '');
                    return a == null || b == null || b < a || b - a > 100
                        ? 'Use uma escala crescente com até 101 notas.'
                        : null;
                  },
                ),
              ],
              if (!widget.diario) ...[
                _texto(
                  rules,
                  'Frases Se... então... (uma por linha)',
                  lines: 3,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: hours,
                  decoration: const InputDecoration(
                    labelText: 'Lembretes HH:MM (um por linha)',
                    helperText: 'Exemplo: 10:00\n12:00',
                    helperMaxLines: 2,
                  ),
                  minLines: 2,
                  maxLines: 6,
                  validator: (_) =>
                      _linhas(hours).any((h) {
                        final p = h.split(':');
                        return !RegExp(r'^\d{2}:\d{2}$').hasMatch(h) ||
                            p.length != 2 ||
                            int.parse(p[0]) > 23 ||
                            int.parse(p[1]) > 59;
                      })
                      ? 'Use horários válidos, como 10:00.'
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _salvar, child: const Text('Salvar campo')),
    ],
  );
}

class PreviaPlanoPage extends StatefulWidget {
  const PreviaPlanoPage({super.key, required this.plano});
  final Plano plano;
  @override
  State<PreviaPlanoPage> createState() => _PreviaPlanoPageState();
}

class _PreviaPlanoPageState extends State<PreviaPlanoPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final hasFood =
        widget.plano.alimentacao != null ||
        widget.plano.refeicoesPrescritas.isNotEmpty;
    final pages = <Widget>[
      HojePage(plano: widget.plano, refresh: () async {}, preview: true),
      SemanaPage(plano: widget.plano, preview: true),
      MeuPlanoPage(plano: widget.plano),
      if (hasFood)
        if (widget.plano.refeicoesPrescritas.isNotEmpty)
          RotinaPrescritaPage(plano: widget.plano)
        else
          AlimentacaoPage(plano: widget.plano, preview: true),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.today), label: 'Hoje'),
      const NavigationDestination(
        icon: Icon(Icons.view_week_outlined),
        label: 'Semana',
      ),
      const NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        label: 'Meu plano',
      ),
      if (hasFood)
        const NavigationDestination(
          icon: Icon(Icons.restaurant_menu_outlined),
          label: 'Alimentação',
        ),
    ];
    final selected = tab >= pages.length ? 0 : tab;
    return Scaffold(
      appBar: AppBar(title: const Text('Prévia do paciente')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Pré-visualização: as marcações não são salvas.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: IndexedStack(index: selected, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: destinations,
      ),
    );
  }
}
