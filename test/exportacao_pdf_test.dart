import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/exportacao_pdf.dart';
import 'package:plano_de_cuidado/core/edicao_plano.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures/rascunho_conferido.dart';

void main() {
  test(
    'só exporta padrão novo conferido, válido e com perfil profissional',
    () {
      final r = rascunhoConferido();
      r.data['estado'] = 'rascunho';
      expect(
        () => planoDoPdfConferido(
          r,
          profissional: 'Médica Exemplo',
          registro: 'CRM TESTE',
        ),
        throwsFormatException,
      );
      r.data['estado'] = 'conferido';
      r.data['confirmacoes']['conteudo'] = false;
      expect(
        () => planoDoPdfConferido(
          r,
          profissional: 'Médica Exemplo',
          registro: 'CRM TESTE',
        ),
        throwsFormatException,
      );
      r.data['confirmacoes']['conteudo'] = true;
      expect(
        () => planoDoPdfConferido(r, profissional: '', registro: 'CRM TESTE'),
        throwsFormatException,
      );
      r.lista('metas').last['alvo'] = '5';
      expect(
        () => planoDoPdfConferido(
          r,
          profissional: 'Médica Exemplo',
          registro: 'CRM TESTE',
        ),
        throwsFormatException,
      );
      r.lista('metas').last['alvo'] = '4';
      r.data.remove('padraoPdf');
      expect(
        () => planoDoPdfConferido(
          r,
          profissional: 'Médica Exemplo',
          registro: 'CRM TESTE',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'conversão v4 mantém identidade, período, IDs, prescrições e PDF sem nutrientes inventados',
    () {
      final r = rascunhoConferido();
      final p = planoDoPdfConferido(
        r,
        profissional: 'Médica Exemplo',
        registro: 'CRM TESTE',
      );
      final again = planoDoPdfConferido(
        r,
        profissional: 'Médica Exemplo',
        registro: 'CRM TESTE',
      );
      expect(p.id, r.id);
      expect(again.data, p.data);
      expect(p.data['versao'], 4);
      expect(p.nascimentoPaciente, '1990-01-01');
      expect(p.fim, DateTime(2026, 10, 30));
      expect(p.retorno, DateTime(2026, 10, 31));
      expect(p.metas.map((m) => m['id']), r.lista('metas').map((m) => m['id']));
      expect(p.metas.first['tipo'], 'refeicoes');
      expect(p.camposRegistraveis, hasLength(5));
      expect(p.refeicoesPrescritas[2]['regra'], 'condicional');
      expect(p.refeicoesPrescritas[2]['condicao'], contains('não sentir fome'));
      expect(
        p.refeicoesPrescritas[2]['descricao'],
        r.lista('refeicoes')[2]['descricao'],
      );
      expect(p.data['pdf'], r.data['pdf']);
      expect(p.data['secoes'], r.data['secoes']);
      expect(p.data.containsKey('alimentacao'), false);
      expect(Plano.parseBytes(utf8.encode(jsonEncode(p.data))).id, p.id);
      expect(
        () => duplicarPlano(p, 'Médica Exemplo', 'CRM TESTE'),
        throwsFormatException,
      );
    },
  );
  test('exporta três, cinco, seis e oito refeições sem pressupor quatro', () {
    for (final n in [3, 5, 6, 8]) {
      final p = planoPdfTeste(refeicoes: n);
      expect(p.refeicoesPrescritas, hasLength(n));
      expect(p.camposRefeicoes, hasLength(n));
    }
  });
  test(
    'validador rejeita período, destinatário, IDs ou regras corrompidos e downgrade',
    () {
      final p = planoPdfTeste();
      for (final edit in <void Function(Map<String, dynamic>)>[
        (d) => d['fim'] = '2026-11-02',
        (d) => d['fim'] = '2026-10-01',
        (d) => (d['paciente'] as Map).remove('nascimento'),
        (d) => d['refeicoesPrescritas'][0]['id'] = d['metas'][0]['id'],
        (d) => d['refeicoesPrescritas'][0]['regra'] = 'talvez',
        (d) => d['refeicoesPrescritas'][2]['condicao'] = '',
        (d) => d['refeicoesPrescritas'][0]['horario'] = '25:00',
        (d) => d['refeicoesPrescritas'][1]['titulo'] =
            d['refeicoesPrescritas'][0]['titulo'],
        (d) => d['versao'] = 3,
        (d) => d['metas'][1]['distribuicao'] = '07:00=5',
        (d) => d['linkMonteSeuPrato'] = 'https://outro.exemplo/paciente',
      ]) {
        final d = copiarDados(p.data);
        edit(d);
        expect(() => Plano.parse(jsonEncode(d)), throwsFormatException);
      }
    },
  );
  test(
    'reimportar mesmo plano preserva feito, dispensa e ausência sem fabricar registros',
    () async {
      sqfliteFfiInit();
      final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await Armazenamento.criarEsquema(sql);
      final db = Armazenamento.testing(sql);
      try {
        await db.salvarPerfilPaciente(
          PerfilPaciente(
            nome: 'Ana Exemplo Completo',
            nascimento: '1990-01-01',
          ),
        );
        final r = rascunhoConferido();
        var p = planoDoPdfConferido(
          r,
          profissional: 'Médica Exemplo',
          registro: 'CRM TESTE',
        );
        await db.importar(p);
        await db.salvarRegistro(
          p.id,
          '2026-10-17',
          p.refeicoesPrescritas[0]['id'] as String,
          'feito',
        );
        await db.salvarRegistro(
          p.id,
          '2026-10-17',
          p.refeicoesPrescritas[2]['id'] as String,
          'dispensado',
        );
        r.lista('refeicoes')[2]['descricao'] =
            'Texto fictício revisado pela médica.';
        p = planoDoPdfConferido(
          r,
          profissional: 'Médica Exemplo',
          registro: 'CRM TESTE',
        );
        await db.importar(p);
        final records = await db.registros(p.id, '2026-10-17');
        expect(records[p.refeicoesPrescritas[0]['id']], 'feito');
        expect(records[p.refeicoesPrescritas[2]['id']], 'dispensado');
        expect(records.containsKey(p.refeicoesPrescritas[1]['id']), false);
        expect(await sql.query('planos'), hasLength(1));
        final errado = copiarDados(p.data)
          ..['paciente'] = {
            'nome': 'Outro Paciente',
            'nascimento': '1990-01-01',
          };
        await expectLater(
          db.importar(Plano.parse(jsonEncode(errado))),
          throwsFormatException,
        );
        expect(await db.registros(p.id, '2026-10-17'), records);
      } finally {
        await sql.close();
      }
    },
  );
}
