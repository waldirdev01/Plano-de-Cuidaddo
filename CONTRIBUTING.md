# Continuidade do desenvolvimento

1. Leia README e `docs/continuidade.md`; confirme o escopo com o responsável.
2. Instale Flutter de referência, execute `flutter pub get`, `flutter analyze` e `flutter test`.
3. Crie uma branch para a tarefa. Preserve `pubspec.lock`; não atualizar SDK/plugins junto com correções sem combinar.
4. Formate arquivos alterados, execute verificações pertinentes e atualize os documentos afetados.
5. Relate implementação, testes automáticos e confirmação em aparelho separadamente.

## Regras do projeto

- Preservar funcionamento offline. Serviço remoto ou IA dentro do app exige decisão explícita. JSON pode ser produzido fora; hoje não existe integração com Claude.
- Tratar `.plano` como contrato entre versões em aparelhos diferentes. Combinar alterações antes de mudar; incluir validador, fixtures e compatibilidade.
- Manter ID e chaves dos registros ao editar/reimportar. Duplicação cria ID, limpa identidade/PDF; revisar textos copiados.
- Separar acompanhamento selecionado de estado `em_andamento`/`encerrado`.
- Conferir destinatário antes do resumo e da gravação. Nunca preencher cadastro a partir do arquivo recebido.
- Migrações SQLite devem preservar planos, registros e configurações; aumentar versão com migração e teste de recuperação.
- Apenas dados fictícios em fixtures, screenshots, issues e commits. Não incluir PDFs de consulta, backups, bancos e certificados reais.

```sh
dart format lib test
flutter analyze
flutter test
```

Mocks nativos não demonstram alarmes reais nem abertura via WhatsApp. Alterações nativas/distribuição exigem compilação iOS e conferência em aparelho; Android tem validação própria pendente.

Antes do commit, confira `git diff --stat`, `git diff --cached` e `git status --short`. Inclua somente o escopo da tarefa. Ainda não existe pipeline de CI; versionamento de entrega fica em `pubspec.yaml`.
