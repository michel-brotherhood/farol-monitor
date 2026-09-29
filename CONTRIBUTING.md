# Como contribuir

Obrigado por querer melhorar o Farol. Mudanças pequenas, reproduzíveis e bem explicadas são mais fáceis de revisar.

## Antes de abrir uma alteração

1. Abra uma issue para discutir mudanças de comportamento ou escopo.
2. Para correções pequenas, descreva o problema e o resultado esperado no pull request.
3. Nunca inclua URLs privadas, credenciais, tokens, cabeçalhos ou histórico local em exemplos e testes.

## Ambiente

- Dart SDK 3.8 ou superior.
- Linux, macOS ou Windows.

## Validar antes do pull request

```bash
dart pub get
dart format .
dart analyze
dart test --reporter expanded
```

## Convenções

- Mantenha o núcleo sem dependências de runtime sempre que possível.
- Separe parsing de configuração, execução de probes, apresentação e persistência.
- Adicione testes para alterações de comportamento.
- Não grave corpo de resposta, cabeçalhos ou query strings no histórico.
- Documente alterações visíveis ao usuário em `CHANGELOG.md`.
- Use mensagens de commit objetivas, por exemplo: `feat: adiciona filtro por estado`.
