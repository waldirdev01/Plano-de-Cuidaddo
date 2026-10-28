# Rotina alimentar no `.plano` v3

O bloco `alimentacao` é opcional. Arquivos v1 e v2 continuam válidos sem esse
bloco. Quando ele existe, o paciente recebe uma rotina-base pronta e pode
trocar somente uma refeição ou um dia.

Nota de continuidade (10/10/2026): o editor salva v3, mas a função de
compartilhamento ainda força v2. O exemplo abaixo é v3; para corrigir a
exportação da interface, consulte `continuidade.md` e `contrato-plano.md`.

## Fluxo da profissional

1. No editor do Plano de Cuidado, toque em **Incluir rotina alimentar** (ou
   **Editar rotina e metas de macro**). Num plano vindo de PDF, use o card
   **Rotina alimentar e metas de macro** da tela de conferência.
2. Escolha **Importar JSON da calculadora** para usar os dados estruturados
   produzidos pela calculadora/IA, ou **Carregar modelo de teste** para testar.
3. Ajuste as **metas do dia** (kcal, proteína, carboidrato, gordura e fibra).
   A tela mostra quanto a rotina padrão soma; mudar as metas não altera as
   porções das opções.
4. Toque em **Aplicar**, salve (ou conclua a conferência) e exporte o `.plano`.

Num plano de PDF, a rotina estruturada **substitui** no arquivo da paciente as
refeições lidas do PDF e a meta REFEICOES, porque um plano tem uma só rotina
alimentar. O PDF original continua anexado. Incluir, alterar ou remover a
rotina desfaz as confirmações da conferência.

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
