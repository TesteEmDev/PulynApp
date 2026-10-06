# 📱 Guia de Publicação - Pulyn Family

## ✅ Pré-requisitos

- Flutter SDK atualizado
- Android SDK/NDK
- Xcode (para iOS)
- Conta Google Play Developer
- Conta Apple Developer Program

---

## 🔑 Android - Google Play Store

### 1. Verificar Keystore
```bash
keytool -list -v -keystore android/app/pulyn_release.keystore -alias pulyn_key -storepass pulyn2026 -keypass pulyn2026
```

### 2. Build Release APK
```bash
flutter clean
flutter pub get
flutter build apk --release
# Arquivo: build/app/outputs/flutter-apk/app-release.apk
```

### 3. Build App Bundle (recomendado para Play Store)
```bash
flutter build appbundle --release
# Arquivo: build/app/outputs/bundle/release/app-release.aab
```

### 4. Submeter na Play Store
1. Abra https://play.google.com/console
2. Selecione "Pulyn Family"
3. Vá em "Release" → "Production"
4. Clique "Create new release"
5. Upload do arquivo `.aab`
6. Preencha:
   - Release notes (português)
   - Screenshots (recomendado 5+)
   - Categoria: Family
   - Idade: 4+
7. Review política privacidade
8. Enviar para review

**Tempo de aprovação:** 2-3 horas geralmente

---

## 🍎 iOS - Apple App Store

### 1. Configurar no Xcode
```bash
cd ios
pod repo update
pod install
cd ..
```

### 2. Build Release IPA
```bash
flutter build ios --release
```

### 3. Abra no Xcode e Archive
```bash
open ios/Runner.xcworkspace
# Menu: Product → Archive
```

### 4. Distribuir
1. Window → Organizer
2. Selecione o archive
3. "Distribute App"
4. Selecione "App Store Connect"
5. Automatic signing
6. Upload

### 5. Submeter no App Store Connect
1. Abra https://appstoreconnect.apple.com
2. "Pulyn Family"
3. "Builds"
4. Selecione seu build
5. Preencha:
   - Release notes
   - Screenshots (5+ por dispositivo)
   - Categoria: Family
   - Idade: 4+
   - Política privacidade
6. "Submit for Review"

**Tempo de aprovação:** 24-48 horas

---

## 📋 Checklist de Submissão

### Geral
- [ ] Versão `pubspec.yaml` atualizada
- [ ] Changelog preparado
- [ ] Privacy Policy em português
- [ ] Terms of Service
- [ ] Screenshots de alta qualidade (2-5 por idioma)
- [ ] Descrição otimizada para SEO

### Android
- [ ] Keystore gerado (`pulyn_release.keystore`)
- [ ] `key.properties` configurado
- [ ] APK/AAB buildado e testado
- [ ] Permissões corretas em AndroidManifest.xml
- [ ] targetSdk >= 34 (obrigatório após Nov 2024)

### iOS
- [ ] Certificates and Identifiers
- [ ] Provisioning profiles atualizados
- [ ] IPA buildado e testado
- [ ] Info.plist correto
- [ ] App Privacy declarado no App Store Connect

---

## 🧪 Testes Pré-submissão

```bash
# 1. Lint & Analyze
flutter analyze

# 2. Rodar testes
flutter test

# 3. Build de produção
flutter build apk --release
flutter build ios --release

# 4. Testar em device real
flutter run --release

# 5. Verificar permissões
# Android: adb shell pm dump com.pulyn.pulyn_app | grep permission
# iOS: Xcode → General → App Capabilities
```

---

## 🔐 Senhas e Certificados (SEGURO)

**Keystore Android:**
- Arquivo: `android/app/pulyn_release.keystore`
- Senha Store: `pulyn2026`
- Alias: `pulyn_key`
- Senha Key: `pulyn2026`

⚠️ **NÃO commitar para Git!** Já está em `.gitignore`.

---

## 📊 Monitoramento Pós-Launch

1. **Google Play Console:**
   - Crashes & ANRs
   - User reviews
   - Analytics

2. **App Store Connect:**
   - Crash logs
   - User reviews
   - Analytics

3. **Firebase (se configurado):**
   - Crashlytics
   - Performance
   - Analytics

---

## 🔄 Atualizações Futuras

Para cada nova versão:
1. Bump version em `pubspec.yaml` (ex: 1.0.1+2)
2. Atualizar changelog
3. Build & test
4. Submit aos app stores
5. Monitorar crashes

---

## 📞 Suporte

Se tiver problemas:
- Android: https://support.google.com/googleplay/android-developer
- iOS: https://developer.apple.com/help/app-store-connect/
- Flutter: https://flutter.dev/docs
