part of 'app.dart';

String _nascimentoIso(String texto) {
  final partes = texto.trim().split('/');
  if (partes.length != 3 ||
      partes[0].length != 2 ||
      partes[1].length != 2 ||
      partes[2].length != 4) {
    throw const FormatException('Use DD/MM/AAAA.');
  }
  final iso = '${partes[2]}-${partes[1]}-${partes[0]}';
  PerfilPaciente.validarNascimento(iso);
  return iso;
}

String _formatarDataDigitada(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length > 8) digits = digits.substring(0, 8);
  if (digits.length <= 2) return digits;
  if (digits.length <= 4) {
    return '${digits.substring(0, 2)}/${digits.substring(2)}';
  }
  return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
}

class CampoNascimento extends StatelessWidget {
  const CampoNascimento({super.key, required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.datetime,
    inputFormatters: [
      TextInputFormatter.withFunction((oldValue, newValue) {
        final text = _formatarDataDigitada(newValue.text);
        return TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }),
    ],
    decoration: const InputDecoration(
      labelText: 'Data de nascimento',
      hintText: 'DD/MM/AAAA',
      helperText: 'As barras são preenchidas automaticamente',
    ),
    validator: (value) {
      try {
        _nascimentoIso(value ?? '');
        return null;
      } on FormatException catch (e) {
        return e.message;
      }
    },
  );
}

class CadastroPacientePage extends StatefulWidget {
  const CadastroPacientePage({
    super.key,
    required this.onSaved,
    this.onCancel,
    this.perfil,
  });
  final Future<void> Function() onSaved;
  final Future<void> Function()? onCancel;
  final PerfilPaciente? perfil;
  @override
  State<CadastroPacientePage> createState() => _CadastroPacientePageState();
}

class _CadastroPacientePageState extends State<CadastroPacientePage> {
  final form = GlobalKey<FormState>();
  late TextEditingController nome, nascimento;
  bool salvando = false;
  @override
  void initState() {
    super.initState();
    nome = TextEditingController(text: widget.perfil?.nome ?? '');
    nascimento = TextEditingController(
      text: widget.perfil == null
          ? ''
          : DateFormat(
              'dd/MM/yyyy',
            ).format(Plano.parseDia(widget.perfil!.nascimento)),
    );
  }

  @override
  void dispose() {
    nome.dispose();
    nascimento.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!form.currentState!.validate()) return;
    setState(() => salvando = true);
    try {
      final perfil = PerfilPaciente(
        nome: nome.text,
        nascimento: _nascimentoIso(nascimento.text),
      );
      await Armazenamento.instance.salvarPerfilPaciente(perfil);
      await widget.onSaved();
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'Não foi possível salvar seu cadastro. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Meu cadastro'),
      leading: widget.onCancel == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: salvando ? null : widget.onCancel,
            ),
    ),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Para conferir se o plano é seu',
              style: TextStyle(fontSize: 22, fontFamily: 'Fraunces'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Informe seu nome completo e nascimento, como a profissional vai colocar no plano. O app confere os dois dados antes de importar. Seu cadastro fica neste aparelho.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const ValueKey('cadastro_nome'),
              controller: nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Informe seu nome completo.'
                  : null,
            ),
            const SizedBox(height: 16),
            CampoNascimento(
              key: const ValueKey('cadastro_nascimento'),
              controller: nascimento,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: salvando ? null : _salvar,
              child: Text(salvando ? 'Salvando…' : 'Salvar cadastro'),
            ),
          ],
        ),
      ),
    ),
  );
}
