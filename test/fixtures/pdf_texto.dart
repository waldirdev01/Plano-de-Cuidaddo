import 'dart:io';

// Canonical synthetic document, also rendered to test the real PDF extractor.
final textoPlanoPdfTeste = File(
  'test/fixtures/plano-cuidado-padrao-1.txt',
).readAsStringSync();
const linkPdfTeste =
    'https://drapriscilakcarvalho.com.br/monte-seu-prato.html#p=dj0yJm09Y2FmZToxOjE6MQ';
