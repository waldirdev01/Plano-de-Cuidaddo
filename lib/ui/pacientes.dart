part of 'app.dart';

/// Professional side: receives pre-consultations and reassessments and shows
/// each patient's local history. Nothing here is sent anywhere.

Future<void> _receberPreConsulta(
  BuildContext context,
  PreConsulta p,
) => _receberNoHistorico(
  context,
  titulo: 'Receber pré-consulta?',
  nome: p.nomePaciente,
  nascimento: p.nascimentoPaciente,
  detalhe:
      'Preenchida em ${DateFormat('dd/MM/yyyy').format(p.criadoEm)}\nTermo aceito: versão ${p.data['termo']['versao']}',
  guardar: () => Armazenamento.instance.guardarPreConsulta(p),
);

Future<void> _receberReavaliacao(
  BuildContext context,
  Reavaliacao r,
) => _receberNoHistorico(
  context,
  titulo: 'Receber reavaliação?',
  nome: r.nomePaciente,
  nascimento: r.nascimentoPaciente,
  detalhe:
      'Preenchida em ${DateFormat('dd/MM/yyyy').format(r.criadoEm)}\nItens: ${r.itens.join(', ')}',
  guardar: () => Armazenamento.instance.guardarReavaliacao(r),
);

Future<void> _receberNoHistorico(
  BuildContext context, {
  required String titulo,
  required String nome,
  required String nascimento,
  required String detalhe,
  required Future<bool> Function() guardar,
}) async {
  final db = Armazenamento.instance;
  if (await db.papel() != 'profissional') {
    throw const FormatException(
      'Este arquivo é para a médica, não um plano. Troque para o modo profissional para abri-lo.',
    );
  }
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: SingleChildScrollView(
        child: Text(
          '$nome\nNascimento: ${DateFormat('dd/MM/yyyy').format(Plano.parseDia(nascimento))}\n$detalhe\n\n'
          'São informações declaradas pela paciente, sem assinatura digital. Ficam guardadas na ficha dela, neste aparelho, e entram no backup.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Receber e abrir a ficha'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final novo = await guardar();
  final paciente = await db.pacienteDe(nome, nascimento);
  if (!context.mounted || paciente == null) return;
  if (!novo) {
    _message(context, 'Este arquivo já foi recebido. Abrindo a ficha.');
  }
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          FichaPacientePage(nome: paciente.nome, nascimento: nascimento),
    ),
  );
}

/// Opens a picked file as pre-consultation or reassessment.
Future<void> _abrirArquivoDaPaciente(BuildContext context) async {
  try {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    if ((await files.single.length() ?? 0) > PreConsulta.limiteBytes) {
      throw const FormatException('Selecione um arquivo de até 1 MB.');
    }
    final source = utf8.decode(await files.single.readAsBytes());
    final formato = (jsonDecode(source) as Map)['formato'];
    if (!context.mounted) return;
    if (formato == PreConsulta.formato) {
      await _receberPreConsulta(context, PreConsulta.parse(source));
    } else if (formato == Reavaliacao.formato) {
      await _receberReavaliacao(context, Reavaliacao.parse(source));
    } else {
      throw const FormatException(
        'Selecione um arquivo de pré-consulta ou de reavaliação da paciente.',
      );
    }
  } on FormatException catch (e) {
    if (context.mounted) _message(context, e.message);
  } catch (_) {
    if (context.mounted) {
      _message(context, 'Não foi possível abrir o arquivo. Nada foi alterado.');
    }
  }
}

/// One entry in a patient's history, newest first.
class _ItemFicha {
  const _ItemFicha(
    this.data,
    this.icone,
    this.titulo,
    this.subtitulo,
    this.abrir,
  );
  final DateTime data;
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final Widget Function() abrir;
}

class _FichaCarregada {
  _FichaCarregada(this.nome, this.nascimento);
  String nome;
  final String nascimento;
  final itens = <_ItemFicha>[];

  /// (date, measures) from pre-consultations and reassessments.
  final medidas = <(DateTime, Map<String, dynamic>)>[];
}

/// Everything on this device grouped by name + birth date. Plans, PDF drafts
/// and received follow-ups are matched at read time; nothing is migrated.
Future<Map<String, _FichaCarregada>> _carregarFichas() async {
  final db = Armazenamento.instance;
  final fichas = <String, _FichaCarregada>{};
  _FichaCarregada ficha(String nome, String nascimento) => fichas.putIfAbsent(
    PacienteHistorico.chave(nome, nascimento),
    () => _FichaCarregada(nome.trim(), nascimento),
  );
  final fmt = DateFormat('dd/MM/yyyy');
  for (final p in await db.pacientes()) {
    final f = ficha(p.nome, p.nascimento)..nome = p.nome;
    for (final pc in await db.preConsultasDoPaciente(p.id)) {
      f.itens.add(
        _ItemFicha(
          pc.criadoEm,
          Icons.assignment_outlined,
          'Pré-consulta',
          'Preenchida em ${fmt.format(pc.criadoEm)}',
          () =>
              _ResumoPage(titulo: 'Pré-consulta', texto: resumoPreConsulta(pc)),
        ),
      );
      f.medidas.add((pc.criadoEm, pc.medidas));
    }
    for (final r in await db.reavaliacoesDoPaciente(p.id)) {
      f.itens.add(
        _ItemFicha(
          r.criadoEm,
          Icons.update,
          'Reavaliação',
          '${fmt.format(r.criadoEm)} · ${r.itens.join(', ')}',
          () => _ResumoPage(titulo: 'Reavaliação', texto: resumoReavaliacao(r)),
        ),
      );
      if (r.medidas != null) f.medidas.add((r.criadoEm, r.medidas!));
    }
  }
  for (final p in await db.planosCriados()) {
    final nascimento = p.nascimentoPaciente;
    if (nascimento == null) continue;
    ficha(p.nomePaciente, nascimento).itens.add(
      _ItemFicha(
        p.inicio,
        Icons.edit_note,
        'Plano criado no app',
        '${fmtDia.format(p.inicio)} a ${fmtDia.format(p.retorno)} · ${p.metas.length} metas',
        () => PreviaPlanoPage(plano: p),
      ),
    );
  }
  for (final r in await db.rascunhosPdf?.listar() ?? const <RascunhoPdf>[]) {
    final nascimento = r.campos['nascimento'] as String;
    try {
      PerfilPaciente(nome: r.nome, nascimento: nascimento);
    } on FormatException {
      continue; // Identity not reviewed yet; it cannot be matched safely.
    }
    final quando = DateTime.parse(
      (r.data['criadoEm'] ?? r.data['atualizadoEm']) as String,
    );
    ficha(r.nome, nascimento).itens.add(
      _ItemFicha(
        quando,
        Icons.picture_as_pdf_outlined,
        'Plano do PDF',
        '${fmt.format(quando)} · ${r.estado == 'conferido' ? 'conferência concluída' : 'em conferência'}',
        () => ConferenciaPdfPage(rascunho: r),
      ),
    );
  }
  for (final r in await db.retornosRecebidos()) {
    final nascimento = r.plano.nascimentoPaciente;
    if (nascimento == null) continue;
    ficha(r.plano.nomePaciente, nascimento).itens.add(
      _ItemFicha(
        r.exportadoEm,
        Icons.fact_check_outlined,
        'Acompanhamento recebido',
        '${fmtDia.format(r.plano.inicio)} a ${fmtDia.format(r.ate)}',
        () => DetalheRetornoPage(retorno: r),
      ),
    );
  }
  for (final f in fichas.values) {
    f.itens.sort((a, b) => b.data.compareTo(a.data));
    f.medidas.sort((a, b) => a.$1.compareTo(b.$1));
  }
  return fichas;
}

class PacientesPage extends StatefulWidget {
  const PacientesPage({super.key});
  @override
  State<PacientesPage> createState() => _PacientesPageState();
}

class _PacientesPageState extends State<PacientesPage> {
  List<_FichaCarregada> fichas = [];
  bool loading = true;
  String busca = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final todas = (await _carregarFichas()).values.toList()
        ..sort(
          (a, b) => PerfilPaciente.normalizarNome(
            a.nome,
          ).compareTo(PerfilPaciente.normalizarNome(b.nome)),
        );
      if (mounted) {
        setState(() {
          fichas = todas;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        _message(context, 'Não foi possível carregar as pacientes.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final termo = PerfilPaciente.normalizarNome(busca);
    final visiveis = fichas
        .where((f) => PerfilPaciente.normalizarNome(f.nome).contains(termo))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await _abrirArquivoDaPaciente(context);
                    await _load();
                  },
                  icon: const Icon(Icons.file_open),
                  label: const Text('Abrir pré-consulta ou reavaliação'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Também é possível tocar no anexo recebido por e-mail ou WhatsApp e escolher Plano de Cuidado.',
                  style: TextStyle(color: apoio),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar paciente',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => busca = v),
                ),
                const SizedBox(height: 8),
                if (visiveis.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhuma paciente encontrada. A ficha é criada ao receber uma pré-consulta ou ao criar um plano.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final f in visiveis)
                  Card(
                    child: ListTile(
                      title: Text(f.nome),
                      subtitle: Text(
                        'Nascimento: ${DateFormat('dd/MM/yyyy').format(Plano.parseDia(f.nascimento))} · ${f.itens.length} registro(s)',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => FichaPacientePage(
                              nome: f.nome,
                              nascimento: f.nascimento,
                            ),
                          ),
                        );
                        await _load();
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'A ficha serve para acompanhar a paciente neste aparelho. Não substitui o prontuário eletrônico.',
                  style: TextStyle(color: apoio),
                ),
              ],
            ),
    );
  }
}

class FichaPacientePage extends StatefulWidget {
  const FichaPacientePage({
    super.key,
    required this.nome,
    required this.nascimento,
  });
  final String nome;
  final String nascimento;
  @override
  State<FichaPacientePage> createState() => _FichaPacientePageState();
}

class _FichaPacientePageState extends State<FichaPacientePage> {
  _FichaCarregada? ficha;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f =
          (await _carregarFichas())[PacienteHistorico.chave(
            widget.nome,
            widget.nascimento,
          )];
      if (mounted) {
        setState(() {
          ficha = f;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        _message(context, 'Não foi possível carregar a ficha.');
      }
    }
  }

  /// New plan with this patient's identity already filled in.
  Future<void> _criarPlano() async {
    final db = Armazenamento.instance;
    final nome = await db.config('profissional_nome') ?? '';
    final registro = await db.config('profissional_registro') ?? '';
    if (!mounted) return;
    if (nome.trim().isEmpty || registro.trim().isEmpty) {
      _message(
        context,
        'Complete seu nome e registro no perfil profissional, em Meus planos, antes de criar um plano.',
      );
      return;
    }
    final data = novoPlano(nome, registro)
      ..['paciente'] = {
        'nome': ficha?.nome ?? widget.nome,
        'nascimento': widget.nascimento,
      };
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => EditorPlanoPage(data: data)),
    );
    await _load();
  }

  int _idade(DateTime nascimento) {
    final hoje = DateTime.now();
    var anos = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      anos--;
    }
    return anos;
  }

  Widget _evolucao(List<(DateTime, Map<String, dynamic>)> medidas) {
    String v(Object? x) => x == null ? '—' : numeroBr(x as num);
    String d(double? x) => x == null ? '—' : numeroBr(x);
    final linhas = [
      for (final (data, m) in medidas)
        if (m.values.any((x) => x != null))
          [
            DateFormat('dd/MM/yy').format(data),
            v(m['peso']),
            v(m['cintura']),
            d(calcularImc(m)),
            d(calcularRcq(m)),
          ],
    ];
    if (linhas.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolução das medidas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Autorreferidas. IMC e relação cintura-quadril só como número.',
              style: TextStyle(color: apoio),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Data')),
                  DataColumn(label: Text('Peso (kg)'), numeric: true),
                  DataColumn(label: Text('Cintura (cm)'), numeric: true),
                  DataColumn(label: Text('IMC'), numeric: true),
                  DataColumn(label: Text('RCQ'), numeric: true),
                ],
                rows: [
                  for (final l in linhas)
                    DataRow(cells: [for (final c in l) DataCell(Text(c))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = ficha;
    final nascimento = Plano.parseDia(widget.nascimento);
    return Scaffold(
      appBar: AppBar(title: Text(f?.nome ?? widget.nome)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Nascimento: ${DateFormat('dd/MM/yyyy').format(nascimento)} · ${_idade(nascimento)} anos',
                  style: const TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _criarPlano,
                  icon: const Icon(Icons.add),
                  label: const Text('Criar plano para esta paciente'),
                ),
                const Text(
                  'Nome e nascimento já vêm preenchidos. Para um plano em PDF, use Importar PDF do plano em Meus planos.',
                  style: TextStyle(color: apoio),
                ),
                const SizedBox(height: 12),
                if (f != null) _evolucao(f.medidas),
                const SizedBox(height: 8),
                Text(
                  'Histórico',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (f == null || f.itens.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nada registrado para esta paciente.'),
                  ),
                for (final item in f?.itens ?? const <_ItemFicha>[])
                  Card(
                    child: ListTile(
                      leading: Icon(item.icone, color: verde),
                      title: Text(item.titulo),
                      subtitle: Text(item.subtitulo),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => item.abrir()),
                        );
                        await _load();
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Read-only summary with a copy button, to paste into the medical record.
class _ResumoPage extends StatelessWidget {
  const _ResumoPage({required this.titulo, required this.texto});
  final String titulo;
  final String texto;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titulo)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: texto));
            if (context.mounted) {
              _message(context, 'Resumo copiado. Cole no prontuário.');
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar resumo'),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(texto, style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Informações declaradas pela paciente, sem interpretação automática.',
          style: TextStyle(color: apoio),
        ),
      ],
    ),
  );
}
