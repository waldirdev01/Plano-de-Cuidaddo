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

## Calendário, avisos e compartilhamento

Datas civis em `AAAA-MM-DD`; semana recortada entre início/retorno. Hoje/tabela bloqueiam marcações futuras. Alimentação permite planejar futuro, mas confirmação só em hoje/passado.

`Lembretes.reagendar()` cancela avisos, monta candidatos de metas/refeições/envio/retorno, ordena e programa até **60** futuros. Fuso fixo `America/Sao_Paulo`. Não existe serviço de fundo para reposição da janela sem abrir o app. Configuração de horários das metas usa apenas `meta.id` (ver pendências).

Enviar semana renderiza PNG e chama compartilhamento nativo. Registro de envio não é confirmação de leitura/recebimento. PDF é base64 no arquivo, aberto pelo paciente; não há extração OCR/IA.

## Testes

- `plano_test.dart`: contrato e datas.
- `conferencia_paciente_test.dart`/`importacao_test.dart`: identidade, seleção e importação.
- `fase2_test.dart`: persistência, editor e backup.
- `alimentacao_test.dart`: totais, rotina, separação e exemplo v3.
- `fluxos_widget_test.dart`: telas com mocks de serviços nativos e fontes reais.

Os testes usam SQLite isolado e fixtures fictícios versionados; serviços nativos precisam de aceitação manual.
