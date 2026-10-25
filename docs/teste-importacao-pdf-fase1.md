# Importar PDF e conferir etapa 1

Registro histórico da etapa já aceita no iPhone pelo responsável. A continuação com exportação está em [teste da etapa 2](teste-exportacao-pdf-fase2.md); os limites de “sem exportação” abaixo descrevem a primeira entrega, não a versão atual.

Branch local `codex/importacao-pdf-conferencia`, atualizada em 17/10/2026 para o contrato **PLANO-CUIDADO/1**. Regras e fontes em [padrão PDF](padrao-pdf-v1.md).

## Preparação

1. Gerar o modelo editável e o guia com `scripts/gerar_modelo_pdf.py`, usando Python do runtime com python-docx/reportlab.
2. Entregar uma cópia do DOCX e do guia para a médica. Preencher todos os colchetes, manter campos e marcadores e exportar como PDF com texto selecionável.
3. Para testes sem dados pessoais, usar `test/fixtures/plano-cuidado-padrao-1.txt` e o exemplo DOCX gerado em `tmp/modelo-pdf-v1/`. As quantidades são fictícias, não uma prescrição.

## Teste na versão atualizada do iPhone

1. No modo profissional, abrir **Meus planos > Regras do modelo PDF**, consultar as regras e depois **Importar PDF do plano**. “Anexar PDF” no editor manual continua sendo apenas anexo.
2. Escolher o PDF preenchido **no padrão novo**. A leitura ocorre localmente, sem IA, OCR ou transmissão.
3. Em **Conferir PDF**, revisar nome completo e nascimento; consulta, emissão, início/fim e retorno; envio semanal; metas, unidades, distribuição e lembretes explícitos; refeições, regras de dispensa e prescrição; link completo e orientações.
4. No exemplo fictício, conferir: duas metas, quatro refeições, lanche **condicional** com sua exceção. A lista obrigatória da meta alimentar não deve incluir automaticamente esse lanche. Não deve haver pedido de decisão sobre ambiguidade no modelo preenchido corretamente.
5. Usar o ícone no topo para consultar o original; o PDF não é modificado quando se alteram campos.
6. **Salvar rascunho com pendências**, sair e reabrir em **Rascunhos de PDF**. Preservar campos, regra condicional e ID.
7. Para concluir, marcar as três confirmações. Um modelo correto conclui sem justificativas extras. Editar algo depois desmarca as confirmações.
8. Teste negativo: mudar o alvo da contagem para um valor diferente da soma da distribuição. A conclusão deve ser bloqueada pedindo a correção, mesmo com justificativa livre.
9. PDF antigo, incompleto, com data/horário inválido ou versão desconhecida deve ser recusado com mensagem legível e sem modificar planos existentes.
10. Rascunho salvo na versão anterior continua abrindo e preserva decisões, com aviso de modelo antigo. Não é reinterpretado como padrão 1.

## Critério de parada

Esta etapa termina no rascunho conferido. **Não exporta esse rascunho em .plano, não configura acompanhamento do paciente e não agenda notificações.** O editor manual antigo continua independente. O backup atual não inclui os rascunhos locais.

## Limites

PDF de até 10 MB, 40 páginas e 400 mil caracteres, sem senha, sem imagem escaneada. Um a oito blocos de metas diárias e até oito refeições; os textos livres não são convertidos em alarmes ou tarefas. O aplicativo verifica o contrato e as relações numéricas/datas programadas, não a coerência clínica de toda frase. A revisão da profissional continua obrigatória.

## Evidências e aceitação

A primeira versão de inferência de frases foi instalada e aberta no iPhone em 17/10/2026; o usuário identificou os avisos de água/lanche durante a conferência. Depois disso, solicitou o contrato explícito. **Esse teste anterior não comprova aceitação do novo padrão.**

A atualização é verificada por análise estática, testes unitários/de interface, render dos materiais e prova complementar de extração PDFKit de um PDF fictício exportado do DOCX. Relatar esses resultados separadamente do teste no aparelho. A exportação pelo Word/Pages usado pela médica e a conferência do novo PDF no iPhone ainda exigem aceitação manual.

Resultado local do padrão em 17/10/2026: `flutter analyze` sem ocorrências; suíte completa com **70 testes aprovados**; `flutter build ios --simulator --no-codesign` aprovado. Prova complementar com o extrator PDFKit de produção e o PDF fictício exportado do DOCX aprovado, incluindo recusa do template ainda em branco. Modelo de três páginas e guia de duas páginas renderizados e inspecionados, além da interface com dados fictícios. Posteriormente, a pedido do responsável, esta atualização foi compilada, instalada e iniciada via Xcode no iPhone “Waldir” (14 Pro Max), com status Running e sessão Dart nova. Não houve backup prévio, desinstalação ou upload para TestFlight. A importação/conferência do novo PDF no aparelho continua pendente de aceitação do usuário.

Nota operacional: executar os comandos Flutter de análise/teste e build iOS **em sequência**, não simultaneamente neste checkout. Durante a validação em paralelo, o pacote Swift efêmero foi regenerado com mínimo 13.0 enquanto o build precisava de 14.0. O projeto já estava configurado para 14.0; a recompilação isolada regenerou o manifesto corretamente e passou, sem alteração de dependências ou do SDK.

## Próxima etapa

Só após aprovação: definir a conversão desse rascunho para o contrato do paciente, incluindo condicionais sem registrar dispensa autorizada como descumprimento; preservar IDs, períodos e vínculo com a fonte. As pendências de exportação v3, calendário e alimentação em `continuidade.md` continuam fora desta entrega.
