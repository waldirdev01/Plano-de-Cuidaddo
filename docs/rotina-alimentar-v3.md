# Rotina alimentar no `.plano` v3

O bloco `alimentacao` é opcional. Arquivos v1 e v2 continuam válidos sem esse
bloco. Quando ele existe, o paciente recebe uma rotina-base pronta e pode
trocar somente uma refeição ou um dia.

Nota de continuidade (10/10/2026): o editor salva v3, mas a função de
compartilhamento ainda força v2. O exemplo abaixo é v3; para corrigir a
exportação da interface, consulte `continuidade.md` e `contrato-plano.md`.

## Fluxo da profissional

1. Abra o editor do Plano de Cuidado.
2. Em **Rotina alimentar**, escolha **Carregar modelo de teste** para testar
   o fluxo ou **Importar JSON da calculadora** para usar os dados estruturados
   produzidos pela calculadora/IA.
3. Confira título, refeições, opções, porções, qualidade e horários.
4. Salve e exporte o `.plano` v3 para enviar à pessoa correta.

O JSON pode ser o bloco `alimentacao` isolado ou um objeto que contenha essa
chave. Cada refeição tem `id`, `titulo`, `horario` opcional e `opcoes`; cada
opção tem `quantidade`, `unidade` e os cinco valores de `nutrientes`.

## Fluxo do paciente

- O arquivo só é importado depois da conferência de nome e data de nascimento.
- A aba **Alimentação** mostra a rotina do dia, a estimativa de calorias e
  macronutrientes e as opções classificadas pela profissional.
- **Trocar refeição** grava uma substituição só naquele dia e naquele
  acompanhamento. **Restaurar a rotina padrão** remove a substituição.
- Dias futuros podem ser planejados; a confirmação da refeição só fica
  disponível no dia atual ou em dias anteriores.
- Horários informados no bloco geram lembretes locais junto com os demais
  lembretes do plano. O aplicativo mantém a janela de até 60 avisos do iOS.

## Exemplo mínimo

```json
{
  "titulo": "Rotina de outubro",
  "modo": "rotina_mensal",
  "meta": {"kcal": 1800, "proteina": 120, "carboidrato": 210, "gordura": 60, "fibra": 25},
  "rotina": {"padrao": {"almoco": "almoco_1"}, "dias": {}},
  "refeicoes": [{
    "id": "almoco",
    "titulo": "Almoço",
    "horario": "12:30",
    "opcoes": [{
      "id": "almoco_1",
      "nome": "Arroz, feijão, frango e legumes",
      "grupo": "prato principal",
      "qualidade": "preferencial",
      "quantidade": 1,
      "unidade": "porção",
      "nutrientes": {"kcal": 620, "proteina": 44, "carboidrato": 74, "gordura": 16, "fibra": 12}
    }]
  }]
}
```

O arquivo `exemplos/plano-alimentar-teste-v3.plano` já contém um plano completo
com três refeições e duas opções em cada uma para o primeiro teste no iPhone.
