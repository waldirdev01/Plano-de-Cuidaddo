# Plano de Cuidado

Aplicativo Flutter em português para lembrar e acompanhar metas e hábitos. Repositório: `waldirdev01/Plano-de-Cuidaddo` (grafia do nome remoto). Funciona com arquivos locais e SQLite, sem servidor ou integração com IA em execução.

A profissional anexa o PDF da consulta como referência, define metas e exporta um `.plano`. O paciente importa esse arquivo e registra o acompanhamento. **Anexar PDF não extrai automaticamente metas nem alimentos.** O foco do app é acompanhar hábitos; ele não realiza diagnóstico ou consulta.

**Fluxo de PDF em teste, 17/10/2026:** no modo profissional, **Importar PDF do plano** lê localmente o modelo **PLANO-CUIDADO/1**. Depois da conferência concluída e salva, **Exportar .plano conferido** gera o formato interno **4**, com período de registros, prescrições textuais e condições de dispensa. O paciente precisa do app atualizado; importa conferindo sua identidade, registra execução/dispensa e recebe lembretes locais se autorizados. Novas importações do PDF antigo são recusadas; rascunhos antigos salvos permanecem disponíveis, sem conversão v4 automática. Veja [regras do modelo](docs/padrao-pdf-v1.md) e [teste da exportação/paciente](docs/teste-exportacao-pdf-fase2.md). Não há IA, OCR ou transmissão automática de documentos.

## Comece por aqui

**Devolução do acompanhamento (17/10/2026):** para planos conferidos v4, o paciente usa **Hoje/ Semana > Exportar acompanhamento**, confere e compartilha um `.plano` cumulativo. No modo profissional, **Meus planos > Acompanhamentos recebidos > Abrir acompanhamento .plano** guarda e exibe os registros por dia, sem editar a prescrição nem o cadastro do paciente. Este arquivo tem formato próprio, diferente do `.plano` de prescrição. Não há envio automático, assinatura digital ou comprovação de recebimento. Ver [roteiro de teste da devolução](docs/teste-devolucao-acompanhamento.md).

Ambiente de referência: Flutter **3.44.9**, Dart **3.12.2**, Xcode **26.0.1**, iOS mínimo **14.0**. Versão do app: **1.1.0+4** em `pubspec.yaml`, candidata para TestFlight; geração local não comprova upload ou aprovação da Apple. Instale o SDK de referência antes de alterar dependências; ele não é incluído no Git. Testes SQLite no Linux podem exigir `libsqlite3-dev`.

```sh
git clone https://github.com/waldirdev01/Plano-de-Cuidaddo.git
cd Plano-de-Cuidaddo
flutter --version
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <id-do-dispositivo>
```

Substitua `<id-do-dispositivo>` pelo ID listado por `flutter devices`. No macOS, abra um simulador iOS antes de executar. Para iPhone físico, abra `ios/Runner.xcworkspace`, escolha sua equipe em **Runner > Signing & Capabilities** e configure o Modo de Desenvolvedor do aparelho. Certificados e chaves privadas não acompanham o clone.

Se os Pods precisarem ser instalados, após `flutter pub get` execute `cd ios`, `pod install` e `cd ..`. Não use IDs de simuladores de outro computador.

## Documentação de continuidade

| Documento | Conteúdo |
| --- | --- |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Desenvolvimento, validação e preservação de dados |
| [Arquitetura](docs/arquitetura.md) | Módulos, armazenamento e integração nativa |
| [Contrato](docs/contrato-plano.md) | Arquivos `.plano`, versões, PDF e backup |
| [Continuidade](docs/continuidade.md) | Limitações verificadas e próximas entregas |
| [Distribuição iOS](docs/distribuicao-ios.md) | Assinatura, Archive e TestFlight |
| [Resumo para a médica](docs/resumo-teste-medica.md) | Teste a partir do PDF |
| [Rotina alimentar](docs/rotina-alimentar-v3.md) | Estrutura do JSON alimentar |

## Funcionalidades presentes

- Profissional: perfil, criar/editar/duplicar planos, metas de cinco tipos, textos, PDF, prévia e exportação.
- Paciente: cadastro independente, conferência de destinatário antes do resumo, Hoje, tabela Semana, edição de dias anteriores e bloqueio dos futuros.
- Históricos por ID do acompanhamento; seleção, encerramento e reativação preservam marcações.
- Alimentação opcional: rotina-base, troca por dia, totais de nutrientes e horários de refeições.
- Lembretes locais, biometria opcional, backup/restauração e compartilhamento semanal como PNG.

iOS é a plataforma trabalhada até agora. **Android tem estrutura, mas ainda precisa completar notificações, recebimento de arquivos, assinatura e validação em aparelho.** Não há alvo macOS neste checkout.

## Verificações

```sh
flutter analyze
flutter test
flutter build ios --simulator --no-codesign
```

Testes usam dados fictícios, SQLite isolado e mocks de serviços nativos. Não dependem de PDFs pessoais nem da pasta `tmp/`. Os exemplos de Maria Exemplo em `exemplos/` podem ter datas passadas; ajuste uma cópia para testar alarmes hoje.

Em 10/10/2026, uma cópia limpa dos arquivos preparados para o Git passou em `flutter analyze` e nos **48 testes**, sem a pasta `tmp/` e sem o exemplo pessoal. `pubspec.lock` foi preservado. IPA 1.1.0+3 foi gerado anteriormente, em 08/10/2026; isso não confirma upload, aprovação da Apple ou teste completo dessa versão no iPhone. Relatórios `docs/testes-*.md` são históricos.

## Dados e licença

A conferência de nome/nascimento reduz importação acidental; `.plano`, PDF, backup e banco local **não são criptografados**. Não publicar dados reais no Git. `tmp/`, `output/`, builds, bancos, certificados e o exemplo pessoal local são ignorados. Fontes possuem arquivos OFL em `assets/fonts/`; a licença geral do projeto ainda não foi definida pelo proprietário.
