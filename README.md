# NutriSnap — App iOS (casca WebView)

App iOS que embrulha o NutriSnap web (**https://neurovoice.com.br/nutrisnap/**)
numa casca nativa, publicada no **TestFlight** via Codemagic (sem precisar de Mac).

Como é uma casca WebView, **toda atualização do site aparece no app automaticamente**
— só precisa rebuildar de novo se mudar algo nativo (ícone, permissões, versão).

## Estrutura

```
ios_nutrisnap_app/            <- conecte ESTA pasta como raiz do repositório
├── codemagic.yaml            # pipeline: XcodeGen -> assina -> IPA -> TestFlight
├── project.yml               # spec do XcodeGen (gera o .xcodeproj no Codemagic)
├── .gitignore
└── NutriSnapApp/
    ├── NutriSnapApp.swift     # @main; aponta pra URL do site
    ├── WebView.swift          # WKWebView (câmera/galeria, diálogos JS, links)
    └── Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

Diferente do LocaCobrança, **não** tem Face ID (o NutriSnap não tem login).

## Pré-requisitos (reaproveitando o que você já usa)

- **App Store Connect:** criar um app novo com bundle **`com.dprobaos.nutrisnap`**
  (nome "NutriSnap"). Categoria sugerida: Saúde e fitness.
- **Codemagic:**
  - Integração App Store Connect **"NeuroVoice ASC"** (a mesma dos outros apps).
  - Grupo de variáveis **`ios_signing`** com `CM_CERTIFICATE_PRIVATE_KEY` (o mesmo dos outros).
  - Time de assinatura: **`4P5D9V48GJ`** (já configurado no `project.yml`).

## Passo a passo pro TestFlight

1. Suba a pasta `ios_nutrisnap_app/` num repositório Git (raiz = esta pasta),
   por ex. GitHub. Faça push na branch **`main`**.
2. No **App Store Connect**, crie o app com bundle `com.dprobaos.nutrisnap`.
3. No **Codemagic**, conecte o repositório e confirme que existem a integração
   "NeuroVoice ASC" e o grupo de variáveis "ios_signing".
4. Rode o workflow **"NutriSnap iOS (TestFlight)"** (ou dê push na `main` — o build
   dispara sozinho).
5. Ao terminar, o build sobe pro TestFlight (**teste interno** sai sem revisão).
   Para **teste externo**, preencha as "Test Information" no App Store Connect e
   troque `submit_to_testflight: false` → `true` no `codemagic.yaml`.

## Observações

- O `codemagic.yaml` incrementa o **build number** automaticamente (timestamp),
  evitando erro de "versão já usada" no upload.
- Câmera/galeria: as permissões (`NSCameraUsageDescription` /
  `NSPhotoLibraryUsageDescription`) já estão no `project.yml`.
- Trocar de versão pública: editar `MARKETING_VERSION` no `project.yml`.
