# Preparar uma entrega iOS

Use macOS, Flutter de referência, Xcode com SDK iOS compatível e conta Apple autorizada para a equipe. O projeto usa Bundle ID `br.com.waldirdev01.planoDeCuidado`; esse ID deve corresponder ao app já cadastrado. Não criar outro registro para cada build.

## Preparação de 17/10/2026 — candidata 1.1.0 (4)

Responsável aceitou no iPhone o fluxo de conferência/exportação de prescrição, importação como Ana, devolução para a profissional e lembrete com som em segundo plano. Código Dart validado com análise sem problemas e 88 testes aprovados na etapa anterior; nesta preparação não houve mudança das regras de negócio nem atualização das dependências. `pubspec.yaml` avançou de 1.1.0+3 para **1.1.0+4**.

Xcode 26.0.1 e SDK iOS 26.0 verificados. Atendem ao [mínimo de SDK vigente da Apple](https://developer.apple.com/news/upcoming-requirements/?id=02032026a). O IPA para App Store Connect é diferente do debug instalado. Não inclui banco, PDFs de pacientes ou os documentos locais de teste; assets Flutter declarados são as fontes do app.

A tela de abertura foi trocada por UILabel nativa “Plano de Cuidado”, com fundo e cor da identidade existente. O antigo conjunto LaunchImage padrão foi movido, de forma recuperável, para `output/distribuicao/2026-10-17/LaunchImage-padrao-preservada.imageset`, fora do catálogo de assets. AppIcon personalizado preservado.

Registro de builds consultado no Organizer: 1.1.0 (3) local, sem status de upload, e 1.0.0 (2) marcado “Uploaded with warnings”. Isso não comprova que não exista outro build no servidor. O número **4 é candidato** até conferir/validar no App Store Connect; nunca reenviar o mesmo número já utilizado.

No navegador interno e no Safari, App Store Connect redirecionou para login com `authResult=FAILED`, sem apresentar o formulário. Não alterar senha, proteções, termos ou permissões para contornar isso. Upload, processamento e liberação para a médica devem ser registrados separadamente após confirmação real. [Apple: upload de builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds) e [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

Notas para a beta: `docs/notas-beta-2026-10-17.md`. Testar com dados fictícios, incluir importação/devolução em aparelhos diferentes e notificações na instalação TestFlight. Não confundir teste externo/beta com publicação pública na App Store. Não adicionar testadores ou enviar convites sem destinatário confirmado.

### Resultado da preparação

- Archive e IPA App Store assinados gerados com sucesso após a troca da abertura. Validação Flutter: versão 1.1.0, build 4, nome Plano de Cuidado, mínimo iOS 14, Bundle ID correto; sem aviso de imagem padrão na compilação final.
- Arquivo preservado em `output/distribuicao/2026-10-17/Plano-de-Cuidado-1.1.0-4.ipa`; fonte gerada em `build/ios/ipa/plano_de_cuidado.ipa`. SDK do IPA confirmado: iphoneos26.0. ZIP íntegro e assinatura do Archive verificada com codesign.
- SHA-256 do IPA: `c849a706bf1a59ad2e29ed2e56922a1eea25ec7c013172518da77a3d9ae7dd5a`.
- O aviso do plugin de notificações sem Swift Package Manager continua não bloqueante; não houve atualização de dependências e `pubspec.lock` permaneceu inalterado.
- Organizer foi aberto e selecionado o produto de Bundle ID correto. Tentativa de abrir o novo Archive pelo diálogo ficou interrompida por mudança da interface e timeout do controle nativo. Não presumir que o novo Archive foi adicionado ao Organizer nem que “Validate App” da Apple foi executado.
- **Upload não executado.** Nenhuma aprovação, processamento, grupo de testadores ou convite foi confirmado. Sem publicação pública, envio de PDF clínico, commit ou push. Retomar acesso ao App Store Connect e conferir build livre antes de upload.

## Procedimento

### Antes de compilar diretamente pelo Xcode

O Flutter 3.44.9 pode regenerar o manifesto efêmero `FlutterGeneratedPluginSwiftPackage/Package.swift` com iOS 13 após `flutter analyze`, `flutter test` ou resolução de dependências. O projeto/Podfile continuam em 14, mas o Xcode direto pode falhar antes de compilar: `file-picker-darwin requires minimum platform version 14.0 ... target supports 13.0`.

Executar análise/testes **antes** da preparação final. Antes de Run/Archive no Xcode, sincronizar pelo comando suportado do Flutter:

```sh
flutter build ios --config-only --release --no-pub
```

Esse fluxo lê `IPHONEOS_DEPLOYMENT_TARGET=14.0` e ajusta o pacote gerado para `.iOS("14.0")`. Não editar manualmente arquivos efêmeros nem o SDK Flutter. Se executar outro comando Flutter que regenere o manifesto, sincronizar novamente antes do Xcode. Compilar com `flutter build ipa --release` também faz essa preparação. Erro posterior do Xcode não invalida por si só um IPA já gerado: conferir a versão, o mínimo iOS e o hash daquele artefato.

Após a captura de erro enviada pelo responsável em 17/10/2026: confirmado pacote efêmero em 13.0, projeto/Podfile e IPA preservado em 14.0. A última análise posterior à geração do IPA havia regenerado o manifesto. Executada a sincronização acima e confirmado `.iOS("14.0")`; em seguida `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' build -quiet` terminou com código **0**, sem aquele erro. Permaneceram avisos não bloqueantes do plugin antigo e da declaração de abertura de documentos. O SHA-256 do IPA preservado continuou igual ao registrado. Não executar Flutter analyze/test depois dessa sincronização sem prepará-la novamente antes do Xcode.

1. Atualize versão/build em `pubspec.yaml`. O estado atual é `1.1.0+4`; uma próxima entrega deve usar número de build ainda não enviado.
2. Execute análise/testes e compile para simulador quando houver mudanças relevantes.
3. Abra `ios/Runner.xcworkspace`, alvo Runner, Signing & Capabilities. Ajuste sua equipe/assinatura; certificados e provisioning são locais, não ficam no Git. O Team ID presente no projeto não concede acesso a outro programador.
4. Compile Archive/IPA:

```sh
flutter build ipa --release
open build/ios/archive/Runner.xcarchive
```

No Organizer, selecione o Archive e use **Distribute App > App Store Connect > Upload**. Alternativa: arrastar `build/ios/ipa/*.ipa` para Transporter autenticado. Após upload, aguardar processamento e configurar testadores no TestFlight. Para teste externo, usar distribuição que permita esse fluxo e seguir a revisão beta indicada pela Apple.

Compilação sem assinatura:

```sh
flutter build ipa --release --no-codesign
```

Esse comando pode gerar Archive sem IPA distribuível; não equivale a upload ou assinatura válida. Os artefatos ficam em `build/`, ignorado no Git. Não reutilizar IPA antigo após alteração no código.

## Avisos observados na entrega 1.1.0+3

- iOS mínimo 14.0 configurado em Podfile e projeto Runner (file_picker requer essa versão).
- `flutter_local_notifications` não suporta Swift Package Manager na versão fixada; build usa integração existente. Planejar migração testada antes de futuros bloqueios.
- Launch image permanece no placeholder padrão; ícone do app personalizado está em AppIcon. Revisar lançamento antes da publicação final.

Verificar as exigências atuais da Apple na data do envio. Gerar Archive/IPA não publica automaticamente nem comprova aprovação.
