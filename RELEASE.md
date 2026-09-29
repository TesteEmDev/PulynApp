# Publicação — Play Store e App Store

Checklist do que ainda depende de você (chaves, contas e domínio). O código já está preparado para isso.

## Antes de tudo
- **Versão:** em `pubspec.yaml`, `version: 1.0.0+1` (`nome+build`). A cada envio para a loja o número depois do `+` precisa **subir** (Android `versionCode`, iOS `CFBundleVersion`).
- **Ambiente da API:** o padrão é `ApiEnvironment.render` (HTTPS). Confira em `lib/config/api_config.dart` antes de gerar o build. O teste `test/api_config_test.dart` falha se o padrão virar `local` ou HTTP.
- **Nome do app:** "Pulyn Family" (Android `android:label`, iOS `CFBundleDisplayName`).
- **Identificadores:** Android `com.pulyn.pulyn_app`, iOS `com.pulyn.pulynApp`. Depois de publicar, **não dá mais para trocar**.

## Android (Google Play)

### 1. Criar a chave de assinatura (uma vez só — guarde com backup!)
Se você perder esta chave, não consegue mais atualizar o app na Play Store.
```
keytool -genkey -v -keystore pulyn-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pulyn
```
Guarde o arquivo `.jks` **fora do repositório** (e as senhas em um cofre de senhas).

### 2. Criar `android/key.properties` (não é versionado)
```
storePassword=SUA_SENHA_DO_KEYSTORE
keyPassword=SUA_SENHA_DA_CHAVE
keyAlias=pulyn
storeFile=C:/caminho/completo/pulyn-release.jks
```
Sem esse arquivo o build release cai **em silêncio** na chave de **debug** (o aviso do Gradle costuma ficar escondido pelo Flutter) e a Play Store recusa o envio. Se a Play Console reclamar de assinatura de debug, é porque este arquivo não estava no lugar.

### 3. Gerar o pacote
Antes, na máquina de build: Android Studio → SDK Manager → *SDK Tools* → marque **Android SDK Command-line Tools (latest)** e rode `flutter doctor --android-licenses`. Sem isso o Flutter termina com "failed to strip debug symbols from native libraries" (o `.aab` é gerado, mas o comando sai com erro e as libs nativas ficam maiores).
```
flutter build appbundle --release
```
Saída: `build/app/outputs/bundle/release/app-release.aab` — é esse arquivo que sobe na Play Console.
Ative também o **Play App Signing** na primeira publicação.

### 4. Links de convite (`https://app.pulyn.com/family/invite/...`)
O manifest já pede verificação automática (`autoVerify`). Para o Android abrir o app direto, publique em
`https://app.pulyn.com/.well-known/assetlinks.json`:
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.pulyn.pulyn_app",
    "sha256_cert_fingerprints": ["SHA-256 DO CERTIFICADO DE ASSINATURA DA PLAY STORE"]
  }
}]
```
O SHA-256 fica na Play Console → Integridade do app → Assinatura de apps.

### 5. Play Console
Política de privacidade (URL), formulário de Segurança dos dados, classificação etária (app com crianças: revise as regras de **Família/Crianças**), capturas de tela e ícone 512×512 (use `assets/icons/app_icon.png`).

## iOS (App Store) — precisa de um Mac (ou serviço de build, ex.: Codemagic)

Nada disso pôde ser compilado/testado no Windows.

1. **Conta Apple Developer** (paga) e um app criado no App Store Connect com o bundle id `com.pulyn.pulynApp`.
2. No Xcode abra `ios/Runner.xcworkspace` → target **Runner** → *Signing & Capabilities*: escolha o **Team** e deixe *Automatically manage signing* ligado. A capability **Associated Domains** (`applinks:app.pulyn.com`) já vem em `ios/Runner/Runner.entitlements`.
3. Na primeira vez: `cd ios && pod install` (o `Podfile` já está no projeto).
4. Gerar: `flutter build ipa --release` e enviar pelo Transporter/Xcode Organizer.
5. **Câmera/QR:** o `Podfile` liga `PERMISSION_CAMERA=1` (necessário para o `permission_handler`). Se um dia o app passar a usar outra permissão (galeria, localização…), ligue o macro correspondente no `Podfile` **e** adicione a chave `NS…UsageDescription` no `Info.plist`.
6. **Universal Links:** publique em `https://app.pulyn.com/.well-known/apple-app-site-association` (sem extensão, `Content-Type: application/json`):
```json
{
  "applinks": {
    "details": [{
      "appIDs": ["SEU_TEAM_ID.com.pulyn.pulynApp"],
      "components": [{ "/": "/family/invite/*" }]
    }]
  }
}
```
7. **App Store Connect:** política de privacidade, *App Privacy* (dados coletados), classificação etária, capturas de tela por tamanho de aparelho. Por ser um app usado com crianças, revise as diretrizes **1.3 (Kids Category)** e **5.1.4**. O `Info.plist` já declara `ITSAppUsesNonExemptEncryption = false` (só HTTPS), então o envio não pergunta sobre criptografia.

## Ícone do app
Regerar depois de mudar as imagens em `assets/icons/`: `dart run flutter_launcher_icons`.
Depois de rodar, confira o `ios/Runner.xcodeproj/project.pbxproj`: o plugin costuma trocar `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` por `AppIcon` (valor inválido) — desfaça essa linha.
