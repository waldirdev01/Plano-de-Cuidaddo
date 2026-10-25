# Arquitetura e mapa do código

`lib/main.dart` abre SQLite, inicializa notificações e inicia `PlanoCuidadoApp`. A interface usa Material, localização pt_BR e fontes locais Karla/Fraunces.

`ui/profissional.dart`, `ui/paciente.dart` e `ui/alimentacao.dart` são **part of `app.dart`**, não bibliotecas independentes. Compartilham símbolos privados; importar `ui/app.dart` para usar suas classes. Considerar esse acoplamento ao separar telas futuramente.

| Arquivo | Responsabilidade |
| --- | --- |
| `core/plano.dart` | Validação do arquivo, cadastro/conferência e datas |
| `core/edicao_plano.dart` | Criar/duplicar, IDs, modelos de campos |
| `core/armazenamento.dart` | SQLite, seleção, planos, registros, config e backup |
| `core/alimentacao.dart` | Opções, porções, rotina e soma de nutrientes |
| `core/lembretes.dart` | Agendamento local e limite de avisos |
| `core/native_bridge.dart` | EventChannel iOS de arquivos recebidos |
| `core/importacao_pdf.dart` | Leitor local por MethodChannel, conferência e arquivos de rascunho |
| `core/padrao_pdf.dart` | Contrato explícito PLANO-CUIDADO/1, blocos, campos e validações determinísticas |
| `core/exportacao_pdf.dart` | Converte somente o rascunho conferido em plano v4, mantendo IDs e sem calcular nutrientes |
| `ui/importacao_pdf.dart` | Conferência profissional, decisões, consulta do PDF original e salvamento isolado |
| `ui/app.dart` | Entrada, Hoje, Semana, PDF, compartilhamento e ajustes |
| `ui/profissional.dart` | Perfil, editor, exportação e prévia |
| `ui/paciente.dart` | Cadastro e máscara do nascimento |
| `ui/alimentacao.dart` | Rotina e substituições por dia |

## Persistência

Banco `plano_de_cuidado.db` em Application Support, versão **2**. Migração v1 acrescenta `planos.estado`.

| Tabela | Chaves e uso |
| --- | --- |
| `planos` | `id` primário; JSON, status, origem, estado, atualização |
| `registros` | chave `(plano_id, data, campo_id)`; valor JSON |
| `envios` | períodos compartilhados e timestamp por plano |
| `config` | chave/valor: perfil, papel, seleção, alarmes e alimentação |

`origem=criado` identifica planos profissionais; `importado` identifica recebidos. A seleção usa `config.acompanhamento_selecionado`; estado fica em `planos.estado`. `status` é legado, ainda persistido; `planoAtivo()` recupera seleção por `status=ativo` em bancos antigos.

Reimportar mesmo ID atualiza JSON e preserva registros; outro ID tem histórico próprio. `acompanhamentosPaciente()` filtra por cadastro. Encerrar conserva dados; reativar permite selecionar.

Substituições alimentares: config `alimentacao_selecoes_<planoId>_<AAAA-MM-DD>`. Confirmações: registros `alimentacao_feita_<refeicaoId>`. Defaults e escolhas são combinados ao abrir a tela; backup inclui config e essas seleções.

## Recebimento iOS

`Info.plist` declara `.plano`/UTI `br.com.waldirdev01.plano`. `AppDelegate.swift` copia arquivo recebido para Application Support/`planos_recebidos` usando security scoped access. `SceneDelegate.swift` encaminha URLs com app aberto e na criação da cena. Canal `br.com.waldirdev01.plano_cuidado/incoming-files` deve coincidir em Swift, Dart e mocks.

Dart valida bytes, exige cadastro independente e confere antes do resumo. Após confirmação, `Armazenamento.importar()` confere novamente na transação. Não logar conteúdo de pacientes.

### Importação profissional de PDF: etapa 1

O botão profissional **Importar PDF do plano** usa `PlatformFile.readAsBytes()` (file_picker 13). O MethodChannel `br.com.waldirdev01.plano_cuidado/pdf`, registrado no engine implícito, envia bytes a `LeitorPdfNativo.swift`. PDFKit extrai texto por página e URLs das anotações, em fila de trabalho local. Não abre links nem executa ações do PDF. Limites: 10 MB, 40 páginas, 400 mil caracteres; rejeita PDF bloqueado e sem texto legível. Não há OCR nem nova dependência de pacote.

O parser Dart exige PLANO-CUIDADO/1 e lê somente seus blocos e campos explícitos (ver `padrao-pdf-v1.md`). Valida quantidade/distribuição, horários, datas e regras condicionais sem inferir conteúdo de frases. Textos livres são referência, não tarefas. O leitor preserva também URLs das anotações, mas o link importado deve estar escrito completo no campo próprio. A conferência preserva a íntegra e os bytes do documento e exige três confirmações. Alterar campos invalida a conferência anterior. Rascunhos antigos abrem sem migração; novas importações do formato antigo são recusadas.

Arquivos em Application Support/`rascunhos_pdf/<uuid>.json`, formato `rascunho-importacao-pdf` v1, gravados por arquivo temporário e rename. **Não são `.plano`** e não entram diretamente em SQLite ou notificações. O backup existente **não inclui esses rascunhos**. Somente a conversão explícita após conferência gera o arquivo paciente v4; só a importação confirmada pelo paciente grava esse plano no banco. Ambos contêm dados de saúde legíveis, sem criptografia nova. Ver `teste-exportacao-pdf-fase2.md`.

V4 mantém `fim` independente de `retorno`, metas `refeicoes` como apresentação sem registro duplicado e `refeicoesPrescritas` com IDs e regras. `Plano.camposRegistraveis` combina metas registráveis, anotações e refeições para Semana/compartilhamento. Hoje registra refeições por ID com `feito`, `nao_feito`, `dispensado` ou ausência, nunca confunde ausência com comprovação de não execução. A aba Alimentação textual não usa o modelo nutricional v3. Os consumidores de calendário e lembretes usam `Plano.fim` (fallback retorno para formatos anteriores). O aviso de retorno continua vinculado à data real da consulta.

## Calendário, avisos e compartilhamento

Datas civis em `AAAA-MM-DD`; semana recortada entre início/retorno. Hoje/tabela bloqueiam marcações futuras. Alimentação permite planejar futuro, mas confirmação só em hoje/passado.

`Lembretes.reagendar()` cancela avisos, monta candidatos de metas/refeições/envio/retorno, ordena e programa até **60** futuros. Fuso fixo `America/Sao_Paulo`. Não existe serviço de fundo para reposição da janela sem abrir o app. Configuração de horários das metas usa apenas `meta.id` (ver pendências).

Enviar semana renderiza PNG e chama compartilhamento nativo. Registro de envio não é confirmação de leitura/recebimento. PDF é base64 no arquivo, aberto pelo paciente; não há extração OCR/IA.

## Testes

### Devolução do acompanhamento

`core/retorno_acompanhamento.dart` valida um envelope independente (`plano-de-cuidado-acompanhamento`, v1) na mesma extensão `.plano` já registrada no iOS. O roteador de arquivos inspeciona `formato` antes do parser de prescrição; não encaminhar esse envelope a `Armazenamento.importar()`. Abertura exige modo profissional e destinatária correspondente ao perfil, antes de mostrar os dados. Não cria cadastro paciente nem troca modo automaticamente.

Exportação cumulativa v4, início até min(hoje,fim), sem PDF, seções clínicas livres ou link pessoal. Guarda IDs e valores por data/campo; ausência não vira falso. Registros desconhecidos/removidos e fora do período não entram. Arquivos recebidos ficam separados em config `retorno_recebido_<id>`, com validação e transação, sem migração SQLite. Mesmo arquivo é idempotente; mesmo ID com conteúdo diferente é recusado. Novos IDs são snapshots independentes, nunca um merge de registros. Backup config já contempla esses arquivos.

`ui/retorno_acompanhamento.dart` fornece prévia, compartilhamento nativo e leitura diária sem edição. “Já enviei à médica” é declaração explícita, não confirmação de leitura. Somente ela atualiza `envios`; salvar/cancelar não atualiza. Na exportação de imagem v4 também não se marca envio automaticamente. A médica consulta os campos e a prescrição de referência, sem PDFs nem interpretação clínica automática. Lista por perfil profissional, busca por paciente e snapshots ordenados pela data declarada de exportação. Não há autenticação criptográfica, servidor, IA ou transmissão automática.

Aceitação de outras versões (1–3), consolidação automática entre arquivos, log de cada alteração com horário, assinatura, criptografia e confirmação remota continuam fora desta etapa. Limites do fuso fixo e janela de 60 alertas permanecem.

- `plano_test.dart`: contrato e datas.
- `conferencia_paciente_test.dart`/`importacao_test.dart`: identidade, seleção e importação.
- `fase2_test.dart`: persistência, editor e backup.
- `alimentacao_test.dart`: totais, rotina, separação e exemplo v3.
- `fluxos_widget_test.dart`: telas com mocks de serviços nativos e fontes reais.

Os testes usam SQLite isolado e fixtures fictícios versionados; serviços nativos precisam de aceitação manual.
