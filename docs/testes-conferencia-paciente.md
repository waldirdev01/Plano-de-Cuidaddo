# Conferência do destinatário — 05/10/2026

## Regra implementada

O cadastro é informado pelo paciente, sem preenchimento com dados do arquivo. Nome e nascimento são conferidos antes de exibir o resumo de importação e novamente dentro da transação que salva o plano. Dados incompatíveis produzem uma mensagem genérica e não modificam planos, registros ou envios.

Nomes são comparados integralmente, ignorando caixa, acentos compostos/decompostos e espaços repetidos. Abreviações e sobrenomes ausentes não são aceitos como equivalentes. Nascimento é uma data civil exata, válida e não futura.

Planos novos e exportações usam contrato `.plano` versão 2, com `paciente.nascimento` em AAAA-MM-DD. Nome e nascimento são obrigatórios no editor. Duplicação limpa os dois dados. PDF é opcional e não é necessário para esse fluxo.

Ao editar o cadastro, planos e histórico incompatíveis ficam ocultos; os dados salvos não são apagados. Lembretes são reagendados somente para o plano correspondente. Cópias incluem o cadastro; restaurar uma cópia de outro paciente não substitui o cadastro local.

## Testes automatizados

`flutter test --reporter expanded`: **39 testes aprovados**.

`flutter analyze`: **sem problemas**. `flutter build ios --release --no-codesign`: **compilação aprovada**, app 1.0.0, build 2, 21,5 MB. Essa compilação verifica o release; não é um pacote assinado ou enviado ao TestFlight. O aviso conhecido de falta de suporte a Swift Package Manager em `flutter_local_notifications` continua sem impedir a compilação atual.

Casos novos verificados:

- Cadastro vazio; nascimento inexistente, inválido, bissexto e futuro.
- Nome certo e nascimento certo; variações de caixa, espaços e acentos.
- Nome diferente ou sobrenome incompleto; nascimento diferente com nome igual.
- Importação sem cadastro não grava um plano e não cria identidade a partir do arquivo recebido.
- Receber arquivo sem cadastro mostra formulário em branco; cancelar não importa.
- Médico não salva/exporta sem nascimento.
- Plano errado não chega ao resumo e não mostra a identidade do destinatário.
- Conferência repetida na transação: mesmo identificador ou identificador novo não permitem substituir o plano com identidade diferente.
- Reimportação correta preserva registros; rejeição preserva plano, registros e envios.
- Cadastro persiste e está incluído no backup.
- Backup com cadastro divergente é recusado sem alterações.
- Edição do cadastro carrega os dados atuais e oculta plano e histórico incompatíveis.
- Duplicação limpa identificação e arquivo exportado contém nascimento.

A suíte também conserva a cobertura anterior de metas genéricas, edição por dia, PDF opcional, prévia, compartilhamento de PNG, SQLite e agendamento de avisos. Notificações, compartilhamento e seletor usam canais substitutos; o armazenamento SQLite e os arquivos são reais e isolados. A espera pelos eventos de I/O foi ajustada e o teste de semana anterior funciona também às segundas-feiras.

## Repetir no iPhone

Instale uma compilação atualizada sem remover os dados do app. Cadastre **Maria Exemplo**, nascimento **12/04/1985**. Arquivos inteiramente fictícios:

- `exemplos/plano-maria-2026-10-02.plano`: correspondente, permite confirmar a importação.
- `exemplos/plano-outro-paciente-teste.plano`: outro nome, bloqueia antes do resumo.
- `exemplos/plano-nascimento-incorreto-teste.plano`: mesmo nome, outro nascimento, bloqueia antes do resumo.

A execução destes cenários no iPhone físico ainda precisa ser confirmada. Não houve instalação, remoção ou alteração dos dados pessoais do aparelho nesta mudança.

## Limites

Esta é uma conferência contra abertura acidental dentro do aplicativo. Não é autenticação civil, criptografia nem uma certificação de conformidade jurídica. Arquivos e backups continuam legíveis fora do app. O modo profissional permite criar e pré-visualizar planos de vários pacientes.

A LGPD classifica dados de saúde como sensíveis (art. 5º, II) e exige medidas técnicas e administrativas adequadas contra acessos e comunicações indevidos (arts. 44 e 46). Esses artigos não estabelecem uma obrigação universal de criptografar cada documento; a adequação depende do tratamento e dos riscos. Enviar receitas em PDF não demonstra, por si só, conformidade do fluxo. Fonte: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709compilado.htm
