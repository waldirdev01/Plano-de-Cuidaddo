import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/plano.dart';

void main() {
  final example = File(
    'exemplos/plano-maria-2026-10-02.plano',
  ).readAsStringSync();

  group('arquivo .plano', () {
    test('importa o exemplo e preserva metas genéricas', () {
      final plano = Plano.parse(example);
      expect(plano.nomePaciente, 'Maria Exemplo');
      expect(plano.metas.map((e) => e['tipo']), ['checklist', 'contador']);
      expect(plano.camposDiarios.map((e) => e['tipo']), [
        'texto',
        'texto',
        'escala',
      ]);
    });

    test('recusa JSON aleatório e assinatura ausente', () {
      expect(() => Plano.parse('{"ok":true}'), throwsFormatException);
      expect(
        () => Plano.parse(
          example.replaceFirst('"formato": "plano-de-cuidado",', ''),
        ),
        throwsFormatException,
      );
    });

    test('orienta atualização para versão futura sem importar', () {
      final future = example.replaceFirst('"versao": 2', '"versao": 5');
      expect(
        () => Plano.parse(future),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'mensagem',
            contains('versão mais nova'),
          ),
        ),
      );
    });

    test('recusa metas com tipos fora do contrato', () {
      final invalid = example.replaceFirst(
        '"tipo": "contador"',
        '"tipo": "prescricao"',
      );
      expect(() => Plano.parse(invalid), throwsFormatException);
    });
  });

  group('datas e semana', () {
    test('calcula dias civis sem contar horas', () {
      expect(
        Plano.diasEntre(DateTime(2026, 10, 3, 23), DateTime(2026, 10, 16, 1)),
        13,
      );
      expect(
        diasDoPlano(DateTime(2026, 10, 3), DateTime(2026, 10, 5)),
        hasLength(3),
      );
    });

    test('recorta semana no início e retorno do plano', () {
      final beforeStart = semanaDoPlano(
        DateTime(2026, 10, 4),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 16),
      );
      expect(beforeStart.de, DateTime(2026, 10, 3));
      expect(beforeStart.ate, DateTime(2026, 10, 4));
      final finalWeek = semanaDoPlano(
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 16),
      );
      expect(finalWeek.de, DateTime(2026, 10, 12));
      expect(finalWeek.ate, DateTime(2026, 10, 16));
    });
  });
}
