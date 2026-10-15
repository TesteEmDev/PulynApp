# 📱 Play Store & App Store - Checklist de Submissão

## ✅ ANTES DE SUBMETER

### Código & Build
- [x] `flutter analyze` sem erros críticos
- [x] `flutter test` passando
- [x] `flutter build apk --release` gerando
- [x] `flutter build appbundle --release` gerando
- [x] Versão em `pubspec.yaml` atualizada (1.0.0+1)
- [x] AndroidManifest.xml com permissões corretas
- [x] Info.plist com permissões corretas

### Keystore & Signing (Android)
- [x] `android/key.properties` criado
- [x] `android/app/pulyn_release.keystore` gerado
- [x] `key.properties` em `.gitignore`
- [x] build.gradle configurado para signing

### Conteúdo
- [ ] 5+ Screenshots de qualidade (1080x1920px)
- [ ] Descrição otimizada (máx 4000 caracteres)
- [ ] Changelog preparado
- [ ] Privacy Policy em português
- [ ] Terms of Service em português
- [ ] Ícone de app finalizado (1024x1024px)
- [ ] Splash screen finalizado

### Configuração nas Lojas
- [ ] Google Play Developer Console configurado
- [ ] Categoria: Family
- [ ] Faixa etária: 4+
- [ ] Idiomas: Português (Brasil)
- [ ] Email de contato de suporte válido

---

## 📦 GOOGLE PLAY STORE (Android)

### 1. Preparar Conteúdo

**Descrição Curta (50 caracteres max):**
```
Rastreie seus filhos em tempo real
```

**Descrição Longa (4000 caracteres max):**
```
Pulyn Family - Acompanhe seus filhos em eventos gamificados!

✨ Features:
🎮 Participate em 3 jogos interativos:
   • Caça ao Tesouro - procure coordenadas e itens
   • Caça ao Monstro - encontre checkpoints ocultos
   • Zona Conquistada - controle áreas do mapa

🗺️ Mapa em tempo real:
   • Veja a planta baixa do buffet
   • Localize todos os checkpoints
   • Acompanhe avatares das crianças se movendo

📊 Pontuação ao vivo:
   • Ranking de crianças e times
   • Atualizado em tempo real
   • Histórico de eventos

👨‍👩‍👧‍👦 Família conectada:
   • Vincule múltiplos filhos
   • QR Code ou NFC wearables
   • Gerencie perfis individuais

🔐 Seguro:
   • Autenticação JWT
   • Dados criptografados
   • Permissões explícitas

💬 Suporte:
Email: support@pulyn.com
Website: www.pulyn.com
```

### 2. Screenshots (obrigatório 5)

1. **Tela de Login** - Mostrar interface de autenticação
2. **Home com Mapa** - Mapa com zonas e checkpoints
3. **Ranking** - Pontuação ao vivo
4. **Evento em Ação** - Avatar se movendo
5. **Perfil de Criança** - Achievements e histórico

**Dimensões:** 1080x1920px (portrait)

### 3. Ícone
- Dimensões: 512x512px
- Formato: PNG com alpha channel
- Sem sombras ou efeitos 3D
- Simples e reconhecível em 48px

### 4. Feature Graphic (opcional mas recomendado)
- Dimensões: 1024x500px
- Mostrar o app em ação

### 5. Categoria & Conteúdo
```
Categoria: Family
Faixa etária: 4+
Conteúdo: "Baixo risco - apropriado para crianças"
Permissões usadas:
  - Câmera (QR Code)
  - NFC (pulseiras)
  - Internet
```

### 6. Política de Privacidade
URL obrigatória: https://www.pulyn.com/privacy

### 7. Submeter
1. Abra Google Play Console
2. Pulyn Family → Release → Production
3. "Create new release"
4. Upload `app-release.aab`
5. Preencha tudo acima
6. "Review and rollout"

**Tempo de aprovação:** 2-3 horas

---

## 🍎 APP STORE (iOS)

### 1. Preparar Conteúdo

**Nome:** Pulyn Family (30 caracteres max)

**Subtitle:** Acompanhe seus filhos (30 caracteres max)

**Descrição (4000 caracteres max):**
```
[MESMO DA PLAY STORE]
```

### 2. Screenshots (obrigatório 5-6)

Dimensões: 1242x2688px (iPhone) ou 2048x2732px (iPad)

Mesmos 5 screenshots do Android

### 3. Preview
Vídeo opcional de 30s mostrando o app

### 4. Keywords (100 caracteres max)
```
rastreamento,crianças,games,mapa,evento
```

### 5. Suporte & Política
- URL de Suporte: https://www.pulyn.com/support
- Privacy Policy: https://www.pulyn.com/privacy
- Terms: https://www.pulyn.com/terms

### 6. Configuração
```
Categoria: Family
Faixa etária: 4+
Apto para crianças: Sim
Permissões usadas: Câmera, NFC
```

### 7. Submeter
1. Abra App Store Connect
2. Pulyn Family → "Build"
3. Selecione build iOS
4. Preencha tudo acima
5. "Submit for Review"

**Tempo de aprovação:** 24-48 horas

---

## 📋 DADOS DE SUBMISSÃO

### Contato
- **Email:** support@pulyn.com
- **Website:** www.pulyn.com
- **Telefone:** +55 (XX) XXXXX-XXXX (se tiver)

### Descrição da Empresa
```
Pulyn Inc - Plataforma de Gamificação de Eventos
Especializada em eventos infantis com rastreamento em tempo real.
```

### Avaliação de Conteúdo
- Violência: Nenhuma
- Conteúdo sexual: Nenhum
- Linguagem forte: Nenhuma
- Informações de contato pessoal: Limitadas (apenas contato de suporte)
- Dados de crianças: Sim (com consentimento dos pais)

---

## 🚀 APÓS LANÇAMENTO

### Monitorar
- [ ] Crashes em Crashlytics
- [ ] Reviews diárias
- [ ] Rating (objetivo: 4.5+)
- [ ] Download trending

### Responder Reviews
- Template para review positivo:
  ```
  Obrigado por usar Pulyn! Fico feliz que tenha gostado.
  Qualquer dúvida, email: support@pulyn.com
  ```

- Template para review negativo:
  ```
  Desculpe pela experiência! Poderia descrever o problema
  com mais detalhes? Email: support@pulyn.com para ajuda rápida.
  ```

### Atualizações
- Bug fixes: 1-2 semanas
- Features: 2-4 semanas
- Patch releases: conforme necessário

---

## 🎯 Objetivo
- Google Play Store: 4.5+ stars
- App Store: 4.5+ stars
- Download inicial: 1000+
