# Preparar uma entrega iOS

Use macOS, Flutter de referência, Xcode com SDK iOS compatível e conta Apple autorizada para a equipe. O projeto usa Bundle ID `br.com.waldirdev01.planoDeCuidado`; esse ID deve corresponder ao app já cadastrado. Não criar outro registro para cada build.

1. Atualize versão/build em `pubspec.yaml`. O estado desta passagem é `1.1.0+3`; uma próxima entrega deve usar número de build ainda não enviado.
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
