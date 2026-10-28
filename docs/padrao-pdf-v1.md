# Contrato do PDF profissional PLANO-CUIDADO/1

Padrão explícito definido em 17/10/2026. É um contrato **de entrada da conferência**, distinto do formato interno do arquivo `.plano`. Substitui a inferência por palavras e frases do PDF antigo. Depois da conferência aprovada, o conversor gera o plano paciente v4 conforme `contrato-plano.md` e `teste-exportacao-pdf-fase2.md`.

## Fontes e reprodução

- Modelo em branco canônico: `docs/modelos/plano-cuidado-padrao-1.txt`.
- Orientação para a médica: `docs/modelos/orientacao-medica-padrao-1.md`.
- Exemplo fictício: `test/fixtures/plano-cuidado-padrao-1.txt`.
- Parser/validador: `lib/core/padrao_pdf.dart`; integração e arquivos locais em `core/importacao_pdf.dart`.
- Materiais de entrega: `scripts/gerar_modelo_pdf.py` gera DOCX editável e guia PDF em `output/modelo-pdf-v1/`, além de DOCX fictício para teste em `tmp/modelo-pdf-v1/`. Usar Python do runtime com python-docx/reportlab e renderizar o DOCX com `render_docx.py`. Não depende de dados reais. PDFs/DOCX gerados são ignorados no Git; fontes e script permitem recriação.

## Gramática

Documento em uma coluna, parágrafos normais e texto selecionável. Título opcional `Plano de Cuidado` e exatamente um identificador `PADRAO DO APLICATIVO: PLANO-CUIDADO/1`. Caixa e acentos são normalizados; rótulos e delimitadores não são renomeados. Sem cabeçalhos, rodapés, numeração automática ou caixas de texto dentro dos dados. Não aceitar versão desconhecida como se fosse 1.

Blocos delimitados: `DADOS DO PLANO` / `FIM DADOS DO PLANO`; `META 1` até `META 8`, sequenciais, cada um terminado por `FIM META`; zero a oito `REFEICAO 1` etc., sequenciais, terminadas por `FIM REFEICAO`; um `ORIENTACOES LIVRES` / `FIM ORIENTACOES LIVRES`. Campos usam `Rotulo: valor`. Rótulos de cada bloco são obrigatórios, únicos e conhecidos; textos longos de orientação/prescrição podem continuar em outras linhas. Nenhum `[PREENCHER ...]` pode permanecer.

**DADOS DO PLANO:** Paciente, Nascimento, Consulta, Emissao, Inicio dos registros, Fim dos registros, Retorno, Hora do retorno, Envio semanal, Hora do envio, Link pessoal. Nome completo; datas DD/MM/AAAA válidas; horários HH:MM. Início <= fim <= retorno. Dia de envio: DOMINGO, SEGUNDA, TERCA, QUARTA, QUINTA, SEXTA ou SABADO. Link completo `https://drapriscilakcarvalho.com.br/monte-seu-prato.html#p=...` ou `NENHUM`. Não substituir o campo por URL de anotação ou deduzir dados do nome do arquivo.

**META:** Titulo, Tipo, Lembretes, Orientacao. Tipos: `REFEICOES` (rascunho checklist), `CONTAGEM` (contador), `CONFIRMACAO` (sim_nao). Entre uma e oito metas, sempre diárias neste padrão. Lembretes explícitos HH:MM separados por vírgula, sem repetição, ou `NENHUM`. Frequências semanais, escala de notas e tarefas pontuais não são suportadas como metas deste padrão; descrevê-las somente na referência, sem prometer acompanhamento.

Somente `CONTAGEM` exige adicionalmente Quantidade diaria, Unidade, Distribuicao. Quantidade numérica finita > 0, decimal com ponto ou vírgula. Unidade é texto integral, não calculado. Distribuição: `HH:MM=quantidade; HH:MM=quantidade`, sem horários repetidos, e soma igual ao alvo; ou `LIVRE`. Cada parcela é individual, não acumulada. Horários da distribuição não são lembretes implícitos e quantidade de lembretes não define quantidade de unidades. Valores inconsistentes precisam ser corrigidos; texto de justificativa não contorna o validador.

**REFEICAO:** Nome único, Horario HH:MM, Regra (`OBRIGATORIA` ou `CONDICIONAL`), Condicao para dispensar, Prescricao. Obrigatória exige `NAO SE APLICA`; condicional exige texto da condição. `REFEICOES` exige ao menos um bloco alimentar. Não pressupor quatro refeições. Itens obrigatórios são derivados das regras e atualizados ao editar, inclusive quando não há obrigatórias. Na conversão para v4 cada refeição mantém seu ID, texto e regra, com registro próprio; dispensa autorizada não é registrada como Não fiz.

**ORIENTACOES LIVRES:** texto obrigatório e preservado. Não extrair tarefas, horários, doses, nutrientes ou decisões desses parágrafos. O app não comprova coerência clínica entre o texto e os campos. Mensagem de ausência de pendências não significa ausência de contradições no documento.

## Revisão e compatibilidade

Documento inválido é recusado com mensagem legível, sem alterações no banco ou notificações. Documento estruturalmente válido entra em rascunho; os campos podem ser corrigidos e revalidados na conclusão. Confirmações de identidade, período e conteúdo continuam obrigatórias. Mudanças invalidam as três confirmações. O padrão fica em `padraoPdf`, mantendo o formato local `rascunho-importacao-pdf` v1 e os IDs de rascunho.

Rascunhos antigos sem `padraoPdf` são preservados e abrem com identificação de modelo antigo, incluindo suas decisões já registradas. Não são reinterpretados nem migrados silenciosamente, e não são exportados como v4. **Novas importações do modelo antigo são recusadas**: a profissional deve preencher o modelo novo. SQLite não muda de versão; o paciente atualizado passa a aceitar `.plano` v4, enquanto clientes anteriores pedem atualização. Desde a etapa 1 da pré-consulta, o backup do aplicativo inclui os rascunhos de PDF.

## Complementos da conferência

O modelo não tem campos de treino nem de metas de macro. Na conferência, a médica pode incluir um **Treino** (`docs/treino.md`) e uma **Rotina alimentar e metas de macro** (`docs/rotina-alimentar-v3.md`). A rotina estruturada substitui no `.plano` as refeições do PDF e a meta REFEICOES; as demais metas e o PDF original continuam. Os dois complementos ficam no rascunho, são validados ao restaurar o backup e desfazem as confirmações quando mudam.

## Verificação

Testes unitários cobrem contrato, soma, horários, nascimento, datas, regras condicionais, versões, links, cardinalidade, marcadores e campos ausentes/repetidos; os de interface cobrem importação/conferência/salvamento e fonte ampliada. Teste local complementar exporta o exemplo fictício em DOCX para PDF, usa o extrator Swift/PDFKit de produção e verifica o parser Dart com a extração real. Isso não substitui o teste do novo modelo no iPhone nem exportação de PDF pelo Word/Pages da médica.
