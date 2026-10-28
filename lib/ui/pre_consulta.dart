part of 'app.dart';

/// Patient-side pre-consultation: same steps as the clinic's web form.
/// The draft stays in config on this device until the patient deletes it.
const _chaveRascunhoPreConsulta = 'pre_consulta_rascunho';
const canalEmail = MethodChannel('br.com.waldirdev01.plano_cuidado/email');

Future<void> _abrirPreConsulta(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const PreConsultaPage()),
);

Future<void> _abrirReavaliacao(BuildContext context, Plano plano) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PreConsultaPage.reavaliacao(plano: plano),
      ),
    );

/// Same page in two modes: the full pre-consultation, or the reassessment the
/// physician requested in [plano] (only the requested items, no consent step).
class PreConsultaPage extends StatefulWidget {
  const PreConsultaPage({super.key}) : plano = null;
  const PreConsultaPage.reavaliacao({super.key, required Plano this.plano});
  final Plano? plano;
  @override
  State<PreConsultaPage> createState() => _PreConsultaPageState();
}

class _PreConsultaPageState extends State<PreConsultaPage> {
  PerfilPaciente? perfil;
  late Map<String, dynamic> r = _vazias();
  DateTime? termoAceitoEm;
  int etapa = 0;
  bool loading = true, busy = false;

  /// The system mail composer needs an account set up in the Mail app.
  bool emailDisponivel = false;

  /// Draft found on this device, waiting for "continue" or "start over".
  Map<String, dynamic>? pendente;
  final _controllers = <String, TextEditingController>{};
  final _erros = <String, String>{};
  final _scroll = ScrollController();

  static const _etapas = [
    'intro',
    'ident',
    'saude',
    'medidas',
    'habitos',
    'sonohumor',
    'hormonal',
    'revisao',
  ];
  static const _titulos = {
    'intro': 'Antes de começar',
    'ident': 'Você',
    'saude': 'Sua saúde até hoje',
    'medidas': 'Suas medidas',
    'habitos': 'Hábitos',
    'sonohumor': 'Sono e humor',
    'hormonal': 'Saúde hormonal',
    'revisao': 'Revisar e enviar',
  };

  static const _titulosReavaliacao = {
    'reav': 'Reavaliação',
    'medidas': 'Suas medidas',
    'sono': 'Sono',
    'humor': 'Humor',
    'revisao': 'Revisar e enviar',
  };

  PedidoReavaliacao? get _pedido => widget.plano?.reavaliacao;
  bool get _reav => widget.plano != null;

  /// The reassessment has no consent step: it continues the same care.
  bool get _liberado => _reav || termoAceitoEm != null;
  String get _chaveRascunho => _reav
      ? 'reavaliacao_rascunho_${widget.plano!.id}'
      : _chaveRascunhoPreConsulta;
  Map<String, dynamic> _vazias() =>
      _reav ? _pedido!.respostasVazias() : PreConsulta.respostasVazias();

  Map<String, dynamic> _secao(String s) => r[s] as Map<String, dynamic>;
  bool get _feminino => _secao('ident')['sexo'] == 'F';
  List<String> get _visiveis => _reav
      ? ['reav', for (final i in _pedido!.itens) i, 'revisao']
      : [
          for (final e in _etapas)
            if (e != 'hormonal' || _feminino) e,
        ];
  String get _atual => _visiveis[etapa.clamp(0, _visiveis.length - 1)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = Armazenamento.instance;
    try {
      emailDisponivel =
          await canalEmail.invokeMethod<bool>('disponivel') ?? false;
    } catch (_) {
      emailDisponivel = false;
    }
    final p = await db.perfilPaciente();
    Map<String, dynamic>? rascunho;
    try {
      final raw = await db.config(_chaveRascunho);
      if (raw != null && p != null && _reav) {
        final d = jsonDecode(raw) as Map<String, dynamic>;
        _criarReavaliacao(p, d['respostas'] as Map<String, dynamic>);
        rascunho = {'respostas': d['respostas'], 'etapa': d['etapa'] as int};
      } else if (raw != null && p != null) {
        final d = jsonDecode(raw) as Map<String, dynamic>;
        final aceito = d['termoAceitoEm'] == null
            ? null
            : DateTime.parse(d['termoAceitoEm'] as String);
        // Only drafts the parser still accepts are offered back.
        PreConsulta.criar(
          p,
          d['respostas'] as Map<String, dynamic>,
          termoAceitoEm: aceito ?? DateTime.now(),
        );
        rascunho = {
          'respostas': d['respostas'],
          'etapa': d['etapa'] as int,
          // A new term version must be accepted again.
          'termoAceitoEm': d['termoVersao'] == termoPreConsultaVersao
              ? aceito
              : null,
        };
      }
    } catch (_) {
      rascunho = null;
    }
    if (!mounted) return;
    setState(() {
      perfil = p;
      pendente = rascunho;
      loading = false;
    });
  }

  Future<void> _salvar() async {
    if (pendente != null) return;
    try {
      await Armazenamento.instance.setConfig(
        _chaveRascunho,
        jsonEncode({
          'respostas': r,
          'etapa': etapa,
          'termoVersao': termoPreConsultaVersao,
          'termoAceitoEm': termoAceitoEm?.toIso8601String(),
        }),
      );
    } catch (_) {
      // The form keeps working; the draft is saved again on the next change.
    }
  }

  void _mudar(VoidCallback action) {
    setState(action);
    _salvar();
  }

  void _limparControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _erros.clear();
  }

  void _continuarRascunho() {
    final p = pendente!;
    _limparControllers();
    setState(() {
      r = jsonDecode(jsonEncode(p['respostas'])) as Map<String, dynamic>;
      termoAceitoEm = p['termoAceitoEm'] as DateTime?;
      etapa = _liberado ? p['etapa'] as int : 0;
      pendente = null;
    });
    _salvar();
  }

  Future<void> _comecarDoZero() async {
    _limparControllers();
    setState(() {
      r = _vazias();
      termoAceitoEm = null;
      etapa = 0;
      pendente = null;
    });
    await Armazenamento.instance.removerConfig(_chaveRascunho);
  }

  void _irPara(int nova) {
    FocusScope.of(context).unfocus();
    if (nova > etapa && _erros.isNotEmpty) {
      _message(context, 'Confira os campos destacados antes de continuar.');
      return;
    }
    setState(() => etapa = nova.clamp(0, _visiveis.length - 1));
    _salvar();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _definirSexo(String? sexo) => _mudar(() {
    _secao('ident')['sexo'] = sexo;
    if (sexo != 'F') {
      final saude = _secao('saude');
      (saude['comorbidades'] as List).remove(comorbidadeSop);
      (saude['detalhes'] as Map).remove(comorbidadeSop);
      r['hormonal'] = PreConsulta.respostasVazias()['hormonal'];
      for (final k in [
        'hormonal.hormonio',
        'hormonal.dum',
        'saude.detalhes.$comorbidadeSop',
      ]) {
        _controllers.remove(k)?.dispose();
        _erros.remove(k);
      }
    }
  });

  void _definirAcordaNoite(String? v) => _mudar(() {
    final sono = _secao('sono');
    sono['acordaNoite'] = v;
    if (v != 'Sim') {
      sono['acordaVezes'] = null;
      sono['acordaMotivo'] = '';
      for (final k in ['sono.acordaVezes', 'sono.acordaMotivo']) {
        _controllers.remove(k)?.dispose();
        _erros.remove(k);
      }
    }
  });

  // ---------- fields ----------

  TextEditingController _controller(String chave, String inicial) =>
      _controllers.putIfAbsent(
        chave,
        () => TextEditingController(text: inicial),
      );

  Widget _texto(
    String secao,
    String campo,
    String rotulo, {
    String? dica,
    String? ajuda,
    int linhas = 1,
    int max = 2000,
    TextInputType? teclado,
    TextInputFormatter? mascara,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: _controller('$secao.$campo', _secao(secao)[campo] as String),
      keyboardType: teclado,
      textInputAction: TextInputAction.done,
      minLines: linhas,
      maxLines: linhas == 1 ? 1 : linhas + 4,
      inputFormatters: [LengthLimitingTextInputFormatter(max), ?mascara],
      decoration: InputDecoration(
        labelText: rotulo,
        hintText: dica,
        helperText: ajuda,
        helperMaxLines: 3,
      ),
      onChanged: (v) {
        _secao(secao)[campo] = v;
        _salvar();
      },
    ),
  );

  String _numeroTexto(Object? v) {
    if (v is! num) return '';
    return v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toString().replaceAll('.', ',');
  }

  /// Number or blank; anything else stays highlighted and blocks "Continuar".
  Widget _numero(
    String secao,
    String campo,
    String rotulo, {
    required double min,
    required double max,
    bool inteiro = false,
    String? dica,
    String? ajuda,
  }) {
    final chave = '$secao.$campo';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _controller(chave, _numeroTexto(_secao(secao)[campo])),
        keyboardType: TextInputType.numberWithOptions(decimal: !inteiro),
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(6)],
        decoration: InputDecoration(
          labelText: rotulo,
          hintText: dica,
          helperText: ajuda,
          helperMaxLines: 3,
          errorText: _erros[chave],
          errorMaxLines: 2,
        ),
        onChanged: (texto) => _mudar(() {
          final t = texto.trim().replaceAll(',', '.');
          final n = num.tryParse(t);
          if (t.isEmpty) {
            _secao(secao)[campo] = null;
            _erros.remove(chave);
          } else if (n == null ||
              n < min ||
              n > max ||
              (inteiro && n != n.roundToDouble())) {
            _secao(secao)[campo] = null;
            final faixa = '${_numeroTexto(min)} a ${_numeroTexto(max)}';
            _erros[chave] = inteiro
                ? 'Use um número inteiro de $faixa.'
                : 'Use um número de $faixa.';
          } else {
            _secao(secao)[campo] = inteiro ? n.toInt() : n;
            _erros.remove(chave);
          }
        }),
      ),
    );
  }

  Widget _escolha(
    String rotulo,
    Object? atual,
    List<(Object, String)> opcoes,
    void Function(Object?) aoMudar,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (valor, texto) in opcoes)
              ChoiceChip(
                label: Text(texto),
                selected: atual == valor,
                // Tapping the chosen option again leaves it blank.
                onSelected: (sim) => aoMudar(sim ? valor : null),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _escolhaTexto(
    String secao,
    String campo,
    String rotulo,
    List<String> opcoes,
  ) => _escolha(rotulo, _secao(secao)[campo], [
    for (final o in opcoes) (o, o),
  ], (v) => _mudar(() => _secao(secao)[campo] = v));

  Widget _nota(
    String secao,
    String campo,
    String rotulo,
    String minimo,
    String maximo,
  ) {
    final v = _secao(secao)[campo] as int?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: const TextStyle(fontSize: 17)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: (v ?? 5).toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: v?.toString(),
                  semanticFormatterCallback: (x) =>
                      v == null ? 'Sem resposta' : '${x.round()}',
                  onChanged: (x) =>
                      _mudar(() => _secao(secao)[campo] = x.round()),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  v?.toString() ?? '—',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minimo, style: const TextStyle(color: apoio)),
              Text(maximo, style: const TextStyle(color: apoio)),
            ],
          ),
          Text(
            v == null
                ? 'Toque ou deslize o marcador para responder. Se preferir, deixe em branco.'
                : 'Resposta: $v.',
            style: const TextStyle(color: apoio),
          ),
          if (v != null)
            TextButton(
              onPressed: () => _mudar(() => _secao(secao)[campo] = null),
              child: const Text('Deixar em branco'),
            ),
        ],
      ),
    );
  }

  Widget _marcar(
    String lista,
    String detalhes,
    List<String> opcoes,
    Map<String, String> perguntas,
  ) {
    final saude = _secao('saude');
    final marcados = saude[lista] as List;
    final det = saude[detalhes] as Map;
    return Column(
      children: [
        for (final o in opcoes) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(o),
            value: marcados.contains(o),
            onChanged: (v) => _mudar(() {
              if (v == true) {
                if (!marcados.contains(o)) marcados.add(o);
              } else {
                marcados.remove(o);
                det.remove(o);
                _controllers.remove('saude.$detalhes.$o')?.dispose();
              }
            }),
          ),
          if (marcados.contains(o) && perguntas.containsKey(o))
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 12),
              child: TextField(
                controller: _controller(
                  'saude.$detalhes.$o',
                  det[o] as String? ?? '',
                ),
                minLines: 2,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                decoration: InputDecoration(
                  labelText: '$o — detalhes',
                  hintText: perguntas[o],
                ),
                onChanged: (v) {
                  if (v.trim().isEmpty) {
                    det.remove(o);
                  } else {
                    det[o] = v;
                  }
                  _salvar();
                },
              ),
            ),
        ],
      ],
    );
  }

  Widget _grupo(String titulo, {String? sub}) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        if (sub != null) Text(sub, style: const TextStyle(color: apoio)),
      ],
    ),
  );

  Widget _aviso(Widget child, {Color cor = verde}) => Card(
    color: cor == alerta ? const Color(0xFFFFF1EE) : const Color(0xFFEFF1EA),
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );

  // ---------- steps ----------

  Widget _cartaoRascunho() => _aviso(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Você já começou este formulário neste aparelho. Quer continuar de onde parou ou começar do zero?',
          style: TextStyle(fontSize: 17),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _continuarRascunho,
          child: const Text('Continuar de onde parei'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _comecarDoZero,
          child: const Text('Começar do zero'),
        ),
      ],
    ),
  );

  List<Widget> _intro() => [
    if (pendente != null) _cartaoRascunho(),
    Text(
      'Vamos adiantar parte da sua consulta',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: 8),
    const Text(
      'Leva cerca de 8 minutos para responder, fora o tempo de tirar as suas medidas. Você pode parar e voltar depois: o que você já respondeu fica salvo neste aparelho.',
      style: TextStyle(fontSize: 17),
    ),
    const SizedBox(height: 12),
    for (final (n, t) in [
      ('1', 'Responda com calma, sem pressa. Não existe resposta errada.'),
      (
        '2',
        'Separe uma fita métrica e, se tiver, uma balança para a etapa de medidas.',
      ),
      (
        '3',
        'No fim, o app gera um arquivo da pré-consulta para você enviar à médica pelo WhatsApp, e-mail ou outro app.',
      ),
    ])
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: verde,
          foregroundColor: Colors.white,
          child: Text(n),
        ),
        title: Text(t),
      ),
    _grupo(
      'Termo de consentimento',
      sub: 'Leia com calma. Para continuar, é preciso concordar.',
    ),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borda),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (titulo, texto) in termoPreConsultaParagrafos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: texto),
                  ],
                ),
              ),
            ),
          Text(
            'Versão de $termoPreConsultaVersao.',
            style: const TextStyle(color: apoio),
          ),
        ],
      ),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Li e concordo com o termo de consentimento.'),
      value: termoAceitoEm != null,
      onChanged: pendente != null
          ? null
          : (v) =>
                _mudar(() => termoAceitoEm = v == true ? DateTime.now() : null),
    ),
  ];

  List<Widget> _ident() => [
    const Text(
      'Esses dados são para abrir seu prontuário. Só a médica recebe.',
      style: TextStyle(color: apoio),
    ),
    const SizedBox(height: 8),
    Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(perfil!.nome),
        subtitle: Text(
          'Nascimento: ${DateFormat('dd/MM/yyyy').format(Plano.parseDia(perfil!.nascimento))}\nDo seu cadastro em Ajustes > Meu cadastro.',
        ),
      ),
    ),
    const SizedBox(height: 12),
    _texto(
      'ident',
      'cpf',
      'CPF',
      dica: '000.000.000-00',
      teclado: TextInputType.number,
      max: 14,
      mascara: TextInputFormatter.withFunction(
        (_, novo) => _mascarar(novo, _mascaraCpf),
      ),
    ),
    _escolha('Sexo', _secao('ident')['sexo'], const [
      ('F', 'Feminino'),
      ('M', 'Masculino'),
    ], (v) => _definirSexo(v as String?)),
    _texto(
      'ident',
      'email',
      'E-mail',
      teclado: TextInputType.emailAddress,
      max: 200,
    ),
    _texto('ident', 'nomeMae', 'Nome da mãe', max: 200),
    _grupo(
      'Endereço',
      sub:
          'Usado na receita, caso seja preciso prescrever medicação de controle especial.',
    ),
    _texto(
      'ident',
      'cep',
      'CEP',
      dica: '00000-000',
      teclado: TextInputType.number,
      max: 9,
      mascara: TextInputFormatter.withFunction(
        (_, novo) => _mascarar(novo, _mascaraCep),
      ),
    ),
    _texto(
      'ident',
      'logradouro',
      'Endereço completo',
      dica: 'Rua/quadra, número, complemento, bairro, cidade/UF',
      linhas: 2,
      max: 500,
    ),
  ];

  List<Widget> _saude() => [
    _grupo(
      'Você já foi diagnosticada(o) com alguma dessas condições?',
      sub: 'Marque quantas se aplicarem',
    ),
    _marcar('comorbidades', 'detalhes', [
      ...comorbidadesPreConsulta.take(9),
      if (_feminino) comorbidadeSop,
      ...comorbidadesPreConsulta.skip(9),
    ], detalheComorbidade),
    const SizedBox(height: 8),
    _texto(
      'saude',
      'outras',
      'Outra doença que não está na lista (opcional)',
      linhas: 2,
    ),
    _texto(
      'saude',
      'cirurgias',
      'Já fez alguma cirurgia? Qual e quando? (opcional)',
      dica: 'ex.: cesárea em 2018, bariátrica em 2020',
      linhas: 2,
    ),
    _grupo('Alergia'),
    _texto(
      'saude',
      'alergias',
      'Alergia a algum remédio? Qual?',
      dica: 'Ou deixe em branco se não tiver',
    ),
    _grupo(
      'Na sua família (pais, avós ou irmãos)',
      sub: 'Marque quantas se aplicarem',
    ),
    _marcar(
      'historiaFamiliar',
      'famDetalhes',
      historiaFamiliarPreConsulta,
      detalheFamilia,
    ),
  ];

  List<Widget> _medidas() => [
    const Text(
      'Tire com calma. Pode pausar o formulário e voltar depois de medir. Se não conseguir alguma agora, pode deixar em branco.',
      style: TextStyle(fontSize: 17),
    ),
    const SizedBox(height: 8),
    _aviso(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Não sabe como medir? Assista ao vídeo que ensina:'),
          const SelectableText(videoMedidasPreConsulta),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: videoMedidasPreConsulta),
              );
              if (mounted) _message(context, 'Link do vídeo copiado.');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar link do vídeo'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 8),
    for (final (campo, rotulo, dica, como) in [
      (
        'peso',
        'Peso (kg)',
        'ex.: 78,5',
        'De manhã, se possível em jejum, sem sapato e com roupa leve.',
      ),
      (
        'altura',
        'Altura (cm)',
        'ex.: 165',
        'Descalça(o), encostada(o) na parede, calcanhares e ombros retos, olhando para frente.',
      ),
      (
        'cintura',
        'Cintura (cm)',
        'ex.: 92',
        'Acima do osso do quadril, fita ajustada sem apertar. Solte o ar devagar antes de ler.',
      ),
      (
        'quadril',
        'Quadril (cm)',
        'ex.: 104',
        'Na parte mais larga do quadril/nádegas.',
      ),
    ])
      _numero(
        'medidas',
        campo,
        rotulo,
        min: faixasMedidas[campo]!.$1,
        max: faixasMedidas[campo]!.$2,
        dica: dica,
        ajuda: como,
      ),
  ];

  List<Widget> _habitos() => [
    _nota(
      'alimentacao',
      'emocional',
      'Come por ansiedade, tédio ou estresse?',
      'nunca',
      'sempre',
    ),
    _grupo('Bebida alcoólica'),
    _escolha(
      'Com que frequência você toma bebida alcoólica?',
      _secao('habitos')['alcool'],
      [for (var i = 0; i < alcoolOpcoes.length; i++) (i, alcoolOpcoes[i])],
      (v) => _mudar(() => _secao('habitos')['alcool'] = v),
    ),
    _grupo('Cigarro'),
    _escolhaTexto('habitos', 'tabagismo', 'Você fuma?', tabagismoOpcoes),
    _grupo('Apoio'),
    _nota(
      'habitos',
      'apoio',
      'Quanto apoio você sente de família ou pessoas próximas para mudar hábitos?',
      'nenhum',
      'total',
    ),
  ];

  List<Widget> _escala(String chave, List<String> itens) {
    final valores = _secao('emocional')[chave] as List;
    return [
      for (var i = 0; i < itens.length; i++)
        _escolha(itens[i], valores[i], [
          for (var j = 0; j < likert4.length; j++) (j, likert4[j]),
        ], (v) => _mudar(() => valores[i] = v)),
    ];
  }

  List<Widget> _sonoHumor() => [_grupo('Sono'), ..._sono(), ..._humor()];

  List<Widget> _sono() => [
    _numero(
      'sono',
      'horas',
      'Horas de sono por noite (média)',
      min: 0,
      max: 24,
    ),
    _escolhaTexto(
      'sono',
      'restaurador',
      'Acorda com sensação de sono restaurador?',
      restauradorOpcoes,
    ),
    _escolha(
      'Acorda durante a noite?',
      _secao('sono')['acordaNoite'],
      [for (final o in simNao) (o, o)],
      (v) => _definirAcordaNoite(v as String?),
    ),
    if (_secao('sono')['acordaNoite'] == 'Sim') ...[
      _numero(
        'sono',
        'acordaVezes',
        'Quantas vezes por noite, em média?',
        min: 0,
        max: 50,
        inteiro: true,
      ),
      _texto(
        'sono',
        'acordaMotivo',
        'Por que você costuma acordar?',
        dica:
            'ex.: vou ao banheiro, calor, barulho, dor, preocupações, criança...',
        max: 1000,
      ),
    ],
    _escolhaTexto('sono', 'ronco', 'Ronca alto?', simNaoNaoSei),
    _escolhaTexto(
      'sono',
      'pausas',
      'Alguém já percebeu você parar de respirar dormindo?',
      simNaoNaoSei,
    ),
  ];

  List<Widget> _humor() => [
    _grupo(
      'Estresse e humor',
      sub:
          'Nas últimas 2 semanas, com que frequência você foi incomodada(o) por...',
    ),
    ..._escala('phq2', phq2Itens),
    ..._escala('gad2', gad2Itens),
    _aviso(
      const Text(
        'Se em algum momento você tiver pensamentos de se machucar ou de que seria melhor não estar viva(o), não espere a consulta: ligue para o CVV, 188 (ligação ou chat, 24h, gratuito), ou procure o pronto-socorro mais próximo. Em emergência, SAMU 192.',
        style: TextStyle(fontSize: 16),
      ),
      cor: alerta,
    ),
  ];

  List<Widget> _hormonal() {
    final h = _secao('hormonal');
    const chave = 'hormonal.dum';
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: _controller(
            chave,
            h['dum'] == null
                ? ''
                : DateFormat(
                    'dd/MM/yyyy',
                  ).format(Plano.parseDia(h['dum'] as String)),
          ),
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            TextInputFormatter.withFunction((_, novo) {
              final t = _formatarDataDigitada(novo.text);
              return TextEditingValue(
                text: t,
                selection: TextSelection.collapsed(offset: t.length),
              );
            }),
          ],
          decoration: InputDecoration(
            labelText: 'Data da última menstruação',
            hintText: 'DD/MM/AAAA',
            errorText: _erros[chave],
          ),
          onChanged: (texto) => _mudar(() {
            if (texto.isEmpty) {
              h['dum'] = null;
              _erros.remove(chave);
              return;
            }
            try {
              final iso = _dataIso(texto);
              h['dum'] = iso;
              _erros.remove(chave);
            } on FormatException catch (e) {
              h['dum'] = null;
              _erros[chave] = e.message;
            }
          }),
        ),
      ),
      _escolhaTexto('hormonal', 'ciclo', 'Seu ciclo é', cicloOpcoes),
      _escolhaTexto(
        'hormonal',
        'menopausa',
        'Já está na menopausa?',
        simNaoNaoSei,
      ),
      _texto(
        'hormonal',
        'hormonio',
        'Usa anticoncepcional ou reposição hormonal? Qual? (opcional)',
        max: 500,
      ),
    ];
  }

  List<Widget> _intrReavaliacao() {
    final pedido = _pedido!;
    final hoje = DateTime.now();
    final proxima = pedido.datas
        .map(Plano.parseDia)
        .where((d) => !d.isBefore(DateTime(hoje.year, hoje.month, hoje.day)))
        .firstOrNull;
    return [
      if (pendente != null) _cartaoRascunho(),
      Text(
        'A médica pediu uma reavaliação',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Responda só o que ela pediu. No fim, envie o arquivo para ela pelo e-mail ou pelo app que você preferir. O que você já respondeu fica salvo neste aparelho.',
        style: TextStyle(fontSize: 17),
      ),
      _grupo('O que atualizar'),
      for (final i in pedido.itens)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle_outline, color: verde),
          title: Text(PedidoReavaliacao.nomesItens[i]!),
        ),
      _grupo('Datas combinadas'),
      Text(
        pedido.datas
            .map((d) => DateFormat('dd/MM/yyyy').format(Plano.parseDia(d)))
            .join(' · '),
      ),
      if (proxima != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Próxima: ${DateFormat('dd/MM/yyyy').format(proxima)}. Pode responder antes ou depois do dia, se precisar.',
            style: const TextStyle(color: apoio),
          ),
        ),
    ];
  }

  List<Widget> _revisaoReavaliacao() {
    final medidas = r['medidas'] as Map<String, dynamic>?;
    return [
      const Text(
        'Quando estiver tudo certo, envie a reavaliação à médica.',
        style: TextStyle(fontSize: 17),
      ),
      if (medidas != null) ...[
        _grupo('Medidas'),
        Text(
          '${medidas.values.where((v) => v != null).length} de 4 preenchidas',
        ),
      ],
      const SizedBox(height: 16),
      ..._botoesEnvio(),
    ];
  }

  List<Widget> _botoesEnvio() => [
    if (emailDisponivel) ...[
      FilledButton.icon(
        onPressed: busy ? null : _enviarEmail,
        icon: const Icon(Icons.mail_outline),
        label: Text(busy ? 'Preparando…' : 'Enviar por e-mail para a médica'),
      ),
      const SizedBox(height: 4),
      const Text(
        'Abre o e-mail com o endereço do consultório ($emailConsultorio), o resumo das respostas e o arquivo anexado. Só a médica lê esse e-mail.',
        style: TextStyle(color: apoio),
      ),
      const SizedBox(height: 12),
    ],
    OutlinedButton.icon(
      onPressed: busy ? null : _exportar,
      icon: const Icon(Icons.ios_share),
      label: const Text('Compartilhar arquivo (WhatsApp e outros)'),
    ),
    const SizedBox(height: 8),
    const Text(
      'O arquivo contém seus dados de saúde. Envie somente à médica. Salvar em Arquivos não é enviar.',
      style: TextStyle(color: apoio),
    ),
    const SizedBox(height: 16),
    _aviso(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Este aparelho não é só seu? Depois de enviar, apague as suas respostas daqui.',
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy ? null : _apagar,
            child: const Text('Apagar minhas respostas deste aparelho'),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _revisao() {
    final ident = _secao('ident');
    final medidas = _secao('medidas');
    String ou(Object? v) =>
        v == null || (v is String && v.trim().isEmpty) ? '—' : '$v';
    Widget linha(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: apoio)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
    final condicoes = (_secao('saude')['comorbidades'] as List).length;
    final preenchidas = medidas.values.where((v) => v != null).length;
    return [
      const Text(
        'Dê uma conferida rápida. Quando estiver tudo certo, exporte a pré-consulta e envie o arquivo à médica pelo app que você preferir.',
        style: TextStyle(fontSize: 17),
      ),
      _grupo('Você'),
      linha('Nome', perfil!.nome),
      linha(
        'Nascimento',
        DateFormat('dd/MM/yyyy').format(Plano.parseDia(perfil!.nascimento)),
      ),
      linha('CPF', ou(ident['cpf'])),
      linha('E-mail', ou(ident['email'])),
      linha('Nome da mãe', ou(ident['nomeMae'])),
      _grupo('Saúde'),
      linha('Condições', condicoes == 0 ? 'nenhuma' : '$condicoes marcada(s)'),
      linha('Medidas', '$preenchidas de 4 preenchidas'),
      const SizedBox(height: 16),
      ..._botoesEnvio(),
    ];
  }

  // ---------- export ----------

  Reavaliacao _criarReavaliacao(
    PerfilPaciente p,
    Map<String, dynamic> respostas,
  ) => Reavaliacao.criar(
    p,
    planoId: widget.plano!.id,
    itens: _pedido!.itens,
    respostas: respostas,
  );

  String get _nomeEnvio => _reav ? 'Reavaliação' : 'Pré-consulta';

  /// The file and the readable summary that goes in the e-mail body.
  Future<(String, File)> _prepararArquivo() async {
    final String nome, resumo;
    final Map<String, dynamic> dados;
    if (_reav) {
      final a = _criarReavaliacao(perfil!, r);
      (nome, resumo, dados) = (
        nomeArquivoReavaliacao(a),
        resumoReavaliacao(a),
        a.data,
      );
    } else {
      final p = PreConsulta.criar(perfil!, r, termoAceitoEm: termoAceitoEm!);
      (nome, resumo, dados) = (
        nomeArquivoPreConsulta(p),
        resumoPreConsulta(p),
        p.data,
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$nome');
    await file.writeAsString(jsonEncode(dados), flush: true);
    return (resumo, file);
  }

  Future<void> _registrarEnvio() async {
    await Armazenamento.instance.setConfig(
      _reav
          ? chaveReavaliacaoEnviada(widget.plano!.id)
          : 'pre_consulta_enviada_em',
      DateTime.now().toIso8601String(),
    );
    // A sent reassessment silences the reminders of its past dates.
    if (_reav && await Armazenamento.instance.config('lembretes') != 'nao') {
      try {
        await Lembretes.instance.reagendar(widget.plano);
      } catch (_) {}
    }
  }

  /// The composer reports Send itself, so no declaration is asked here.
  Future<void> _enviarEmail() async {
    setState(() => busy = true);
    try {
      final (resumo, file) = await _prepararArquivo();
      // Readable summary in the body; the attachment is for the app.
      final status = await canalEmail.invokeMethod<String>('enviar', {
        'para': emailConsultorio,
        'assunto': '$_nomeEnvio de ${perfil!.nome}',
        'corpo':
            'Segue a minha ${_nomeEnvio.toLowerCase()}. O arquivo anexo abre no Plano de Cuidado, no modo profissional.\n\n$resumo',
        'arquivo': file.path,
      });
      if (!mounted) return;
      switch (status) {
        case 'enviado':
          await _registrarEnvio();
          if (mounted) _message(context, 'E-mail enviado à médica.');
        case 'rascunho':
          _message(
            context,
            'Salvo como rascunho no Mail. Ainda não foi enviado à médica.',
          );
        case 'falhou':
          _message(
            context,
            'O e-mail não foi enviado. Tente de novo ou use Compartilhar.',
          );
      }
    } on FormatException catch (e) {
      if (mounted) _message(context, e.message);
    } on PlatformException catch (e) {
      if (mounted) {
        _message(
          context,
          e.message ?? 'Não foi possível abrir o e-mail. Use Compartilhar.',
        );
      }
    } catch (_) {
      if (mounted) {
        _message(context, 'Não foi possível abrir o e-mail. Use Compartilhar.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _exportar() async {
    setState(() => busy = true);
    try {
      final (_, file) = await _prepararArquivo();
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: '$_nomeEnvio de ${perfil!.nome}',
          text:
              '$_nomeEnvio de ${perfil!.nome}. Abrir no modo profissional do Plano de Cuidado atualizado.',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!mounted || result.status == ShareResultStatus.dismissed) return;
      final enviado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Você enviou à médica?'),
          content: const Text(
            'Salvar em Arquivos não envia à médica. Confirme somente se você já encaminhou o arquivo para ela. Isso registra sua declaração de envio, não o recebimento ou a leitura.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Só salvei / ainda não enviei'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Já enviei à médica'),
            ),
          ],
        ),
      );
      if (enviado != true) return;
      await _registrarEnvio();
      if (mounted) {
        _message(context, 'Envio registrado. Suas respostas continuam aqui.');
      }
    } on FormatException catch (e) {
      if (mounted) _message(context, e.message);
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'Não foi possível preparar o arquivo. Suas respostas continuam salvas; tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _apagar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar as suas respostas?'),
        content: const Text(
          'Apaga as respostas deste aparelho. O que você já enviou à médica não é afetado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _comecarDoZero();
    if (mounted) _message(context, 'Respostas apagadas deste aparelho.');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (perfil == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_nomeEnvio)),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Faça seu cadastro (nome completo e nascimento) em Ajustes antes de responder.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
    final visiveis = _visiveis;
    if (!_liberado) etapa = 0;
    etapa = etapa.clamp(0, visiveis.length - 1);
    final atual = _atual;
    final ultima = etapa == visiveis.length - 1;
    final conteudo = switch (atual) {
      'reav' => _intrReavaliacao(),
      'sono' => _sono(),
      'humor' => _humor(),
      'revisao' when _reav => _revisaoReavaliacao(),
      'intro' => _intro(),
      'ident' => _ident(),
      'saude' => _saude(),
      'medidas' => _medidas(),
      'habitos' => _habitos(),
      'sonohumor' => _sonoHumor(),
      'hormonal' => _hormonal(),
      _ => _revisao(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text((_reav ? _titulosReavaliacao : _titulos)[atual]!),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${etapa + 1} / ${visiveis.length}'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (etapa + 1) / visiveis.length,
            color: verde,
            backgroundColor: borda,
          ),
        ),
      ),
      // The keyboard hides the bottom buttons: tapping outside a field or
      // dragging the list closes it.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: conteudo,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: etapa == 0 ? null : () => _irPara(etapa - 1),
                  child: const Text('Voltar'),
                ),
              ),
              if (!ultima) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: pendente != null || !_liberado
                        ? null
                        : () => _irPara(etapa + 1),
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String nomeArquivoReavaliacao(Reavaliacao a) {
  final nome = PerfilPaciente.normalizarNome(
    a.nomePaciente,
  ).replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return 'reavaliacao-$nome-${Plano.formatDia(a.criadoEm)}.plano';
}

String nomeArquivoPreConsulta(PreConsulta p) {
  final nome = PerfilPaciente.normalizarNome(
    p.nomePaciente,
  ).replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return 'pre-consulta-$nome-${Plano.formatDia(p.criadoEm)}.plano';
}

String _mascaraCpf(String d) {
  d = d.length > 11 ? d.substring(0, 11) : d;
  if (d.length > 9) {
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }
  if (d.length > 6) {
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6)}';
  }
  if (d.length > 3) return '${d.substring(0, 3)}.${d.substring(3)}';
  return d;
}

String _mascaraCep(String d) {
  d = d.length > 8 ? d.substring(0, 8) : d;
  return d.length > 5 ? '${d.substring(0, 5)}-${d.substring(5)}' : d;
}

TextEditingValue _mascarar(
  TextEditingValue novo,
  String Function(String) mascara,
) {
  final t = mascara(novo.text.replaceAll(RegExp(r'\D'), ''));
  return TextEditingValue(
    text: t,
    selection: TextSelection.collapsed(offset: t.length),
  );
}

/// DD/MM/AAAA typed by the patient, not in the future.
String _dataIso(String texto) {
  final partes = texto.trim().split('/');
  if (partes.length != 3 || partes[2].length != 4) {
    throw const FormatException('Use DD/MM/AAAA.');
  }
  final iso = '${partes[2]}-${partes[1]}-${partes[0]}';
  final DateTime d;
  try {
    d = Plano.parseDia(iso);
  } catch (_) {
    throw const FormatException('Data inválida.');
  }
  final hoje = DateTime.now();
  if (d.year < 1900 || d.isAfter(DateTime(hoje.year, hoje.month, hoje.day))) {
    throw const FormatException('A data não pode ser no futuro.');
  }
  return iso;
}
