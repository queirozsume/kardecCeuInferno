# O Céu e o Inferno

Aplicativo Android para leitura offline de *O Céu e o Inferno*, de Allan Kardec. O app apresenta o conteúdo como texto, com navegação por partes, capítulos e seções; não inclui visualizador nem arquivo PDF.

## APK

Após a publicação de uma release, o APK estará disponível em [Releases](https://github.com/queirozsume/kardecCeuInferno/releases/latest) e em [apk/ceu-e-o-inferno.apk](apk/ceu-e-o-inferno.apk).

O APK é assinado pelo GitHub Actions. O repositório precisa dos secrets `KEYSTORE_BASE64` e `KEYSTORE_PASSWORD` configurados antes de publicar uma release.

## Conteúdo

O arquivo-fonte `O-Ceu-e-o-inferno.pdf` é local e ignorado pelo Git. Para gerar o asset textual do app, coloque sua cópia autorizada na raiz do projeto e execute:

```sh
python build_book_content.py
```

O gerador extrai as páginas impressas 11 a 407, filtra cabeçalhos e rodapés correntes e não inclui as páginas físicas 4 e 408. O resultado é `app/assets/book_content.json`; nenhum PDF é empacotado no aplicativo.

## Build local

```sh
cd app
flutter pub get
flutter build apk --release
```

Um push para `main` compila o APK como artefato do Actions. Uma tag `v*` publica a release e atualiza `apk/ceu-e-o-inferno.apk`.

Desenvolvido por Joel Queiroz.
