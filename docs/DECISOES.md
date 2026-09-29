# Decisões técnicas

## Dart CLI antes de serviço hospedado

O problema inicial é executar verificações simples sem exigir conta, banco de dados ou infraestrutura. O CLI funciona em Linux, macOS e Windows e pode ser usado por pessoas e pipelines.

## Sem dependências de runtime

A primeira versão usa `dart:io` e `dart:convert`. Isso reduz a superfície de manutenção e mantém o binário executável com o SDK. Testes e lint usam ferramentas de desenvolvimento do ecossistema Dart.

## Histórico JSONL local

Cada linha representa um ciclo de verificação em JSON. O formato é fácil de inspecionar, arquivar ou processar depois. Dados são minimizados: nome e host do alvo, estado, código HTTP, latência, resultado da asserção e data; sem query string, corpo ou cabeçalhos.

## Modo de alerta

O Farol separa falha funcional de lentidão: status incorreto, timeout e asserção de conteúdo ausente geram `INDISPONÍVEL`; exceder o orçamento opcional de latência gera `LENTO`.

## Limitações da versão inicial

- Sem cabeçalhos personalizados, login, cookies ou autenticação.
- Sem agendamento em background: `watch` precisa permanecer aberto.
- Sem persistência central ou alertas externos.
- Sem promessa de disponibilidade do alvo; a execução é pontual e parte do dispositivo local.
