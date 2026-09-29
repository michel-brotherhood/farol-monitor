# Farol

**Monitor local de disponibilidade e latência para sites e APIs.** Configure seus endpoints em JSON, execute verificações em paralelo e acompanhe mudanças de estado sem enviar resultados para um serviço externo.

> O Farol está em estágio inicial (`0.1.0`). Use primeiro em ambientes de teste e valide os resultados antes de incorporá-los a rotinas críticas.

[![Dart CI](https://github.com/michel-brotherhood/farol-monitor/actions/workflows/ci.yml/badge.svg)](https://github.com/michel-brotherhood/farol-monitor/actions/workflows/ci.yml)
![Dart](https://img.shields.io/badge/Dart-%3E%3D3.8-0175C2?logo=dart)
![License](https://img.shields.io/badge/license-MIT-green)

## Por que Farol?

Serviços pequenos e projetos em desenvolvimento também precisam de uma forma simples de verificar se seus endpoints respondem, quanto demoram e se entregam um conteúdo esperado. O Farol faz essas verificações a partir da própria máquina, com configuração legível e histórico local.

A ideia central é unir **monitoramento sintético simples, limites de latência e histórico que permanece sob controle do usuário**, sem painel hospedado nem telemetria obrigatória.

## Recursos

- Verifica URLs HTTP e HTTPS com `GET` ou `HEAD`.
- Confere códigos HTTP esperados, texto opcional no corpo e limite de latência.
- Define timeout, limite de corpo lido e concorrência por configuração.
- Oferece execução única (`check`) e acompanhamento contínuo (`watch`).
- Gera saída no terminal, JSON ou Markdown.
- Registra ciclos em JSONL local e permite consultar execuções recentes.
- Evita armazenar query strings, cabeçalhos e corpos das respostas.
- Não possui dependências de runtime de terceiros.

## Requisitos

- Dart SDK 3.8 ou superior.
- Acesso de rede aos endpoints que você configurar.

## Começar

Clone o repositório e entre na pasta:

```bash
git clone https://github.com/michel-brotherhood/farol-monitor.git
cd farol-monitor
dart pub get
```

Copie a configuração de exemplo e edite seus endpoints:

```bash
cp example/farol.local.sample.json farol.json
```

Execute uma verificação:

```bash
dart run bin/farol.dart check --config farol.json
```

A saída inclui o estado, código HTTP final e latência de cada endpoint. O primeiro registro é salvo em `.farol/history.jsonl`.

### Instalação global a partir do clone

```bash
dart pub global activate --source path .
farol --help
```

Se o terminal não encontrar o comando, configure o diretório de executáveis globais do Dart no `PATH` do Linux Mint. Para uso pontual, `dart run bin/farol.dart ...` não depende disso.

## Configuração

O arquivo usa JSON, versão de esquema `1`:

```json
{
  "version": 1,
  "settings": {
    "timeoutMs": 5000,
    "maxBodyBytes": 65536,
    "concurrency": 8
  },
  "targets": [
    {
      "name": "API pública",
      "url": "https://api.example.com/health",
      "method": "GET",
      "expectedStatus": 200,
      "maxLatencyMs": 1200
    },
    {
      "name": "Página inicial",
      "url": "https://example.com",
      "method": "GET",
      "expectedStatus": [200, 204],
      "contains": "Bem-vindo",
      "maxLatencyMs": 1800,
      "timeoutMs": 7000
    }
  ]
}
```

### Campos

| Campo | Obrigatório | Padrão | Limites / descrição |
|---|---:|---:|---|
| `version` | Sim | — | Deve ser `1`. |
| `settings.timeoutMs` | Não | `5000` | Timeout padrão, de 100 a 120.000 ms. |
| `settings.maxBodyBytes` | Não | `65536` | Máximo lido para a asserção `contains`, de 1 byte a 1 MiB. |
| `settings.concurrency` | Não | `8` | De 1 a 32 verificações simultâneas. |
| `targets` | Sim | — | De 1 a 100 endpoints. |
| `targets[].name` | Sim | — | Nome único para identificar o endpoint. |
| `targets[].url` | Sim | — | URL HTTP ou HTTPS sem usuário/senha embutidos. |
| `targets[].method` | Não | `GET` | `GET` ou `HEAD`. |
| `targets[].expectedStatus` | Não | `200` | Código único ou lista de códigos HTTP aceitos. |
| `targets[].timeoutMs` | Não | `settings.timeoutMs` | Timeout específico, de 100 a 120.000 ms. |
| `targets[].maxLatencyMs` | Não | Sem limite | Acima do limite, o resultado fica `LENTO`. |
| `targets[].contains` | Não | — | Texto simples e sensível a maiúsculas/minúsculas a procurar no corpo. Não permitido com `HEAD`. |

A configuração não aceita cabeçalhos customizados nem autenticação nesta versão. Isso reduz o risco de credenciais em arquivos de configuração e no histórico.

## Comandos

### Verificar uma vez

```bash
farol check
farol check --config config/production.json
farol check --config farol.json --format json
farol check --format markdown --no-history
```

Formatos: `text`, `json` ou `markdown`. O histórico é gravado por padrão; use `--no-history` para não persistir aquele ciclo.

### Acompanhar continuamente

```bash
farol watch --config farol.json --interval 30
```

O modo `watch` executa verificações repetidas, destaca quando um endpoint muda de estado e grava cada ciclo no histórico local. Encerre com `Ctrl+C`.

### Consultar o histórico

```bash
farol history
farol history --limit 50
farol history --path .farol/history.jsonl --limit 10
```

### Códigos de saída de `check`

| Código | Significado |
|---:|---|
| `0` | Todos os endpoints estão saudáveis e dentro dos limites. |
| `1` | Pelo menos um endpoint está lento ou indisponível. |
| `2` | Configuração, argumento ou arquivo inválido. |

Esse comportamento permite integrar o comando com scripts e pipelines de CI.

## Estados

- **OK**: status HTTP esperado, conteúdo correspondente (se configurado) e latência dentro do limite.
- **LENTO**: verificação funcional, mas acima do limite de latência configurado.
- **INDISPONÍVEL**: erro de rede/timeout, status inesperado ou texto esperado ausente.

A latência considera a resposta HTTP e, quando `contains` estiver configurado, a leitura do trecho limitado do corpo necessário para procurar o texto.

## Privacidade e limites

- As verificações são iniciadas pela máquina onde o Farol roda.
- Não há conta, serviço remoto, telemetria ou upload automático.
- O histórico registra nome, host, estado, latência, código HTTP, resultado da asserção de conteúdo e data.
- O histórico não registra caminho/query da URL, cabeçalhos ou corpo da resposta.
- URLs configuradas podem identificar hosts internos; mantenha `farol.json` local se ele contiver endereços privados.
- O Farol não é um scanner de segurança, teste de carga, monitor distribuído ou substituto de uma plataforma de observabilidade.
- Use somente endpoints que você controla ou tem autorização para consultar. Não configure intervalos agressivos.

Para remover o histórico:

```bash
rm -rf .farol
```

## Desenvolvimento

```bash
dart pub get
dart format .
dart analyze
dart test --reporter expanded
```

A integração contínua executa formatação, análise estática e testes em pull requests e pushes para `main`.

## Roteiro

Ideias que podem evoluir a partir de issues reais:

- sumarização de tendências locais de latência;
- saída SARIF ou JUnit para integrar com outros fluxos;
- perfis de configuração separados por ambiente;
- verificações de certificado TLS com data de expiração;
- política de retenção configurável para histórico.

Nenhum item do roteiro é funcionalidade disponível até ser implementado e documentado.

## Contribuir

Leia [CONTRIBUTING.md](CONTRIBUTING.md) antes de propor mudanças. Relatos de segurança devem seguir [`.github/SECURITY.md`](.github/SECURITY.md), sem publicar detalhes exploráveis em issues públicas.

## Licença

Distribuído sob licença MIT. Veja [LICENSE](LICENSE).
