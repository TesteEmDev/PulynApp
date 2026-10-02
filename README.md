# 📱 PulynApp - Flutter Mobile

Aplicativo mobile (Flutter) da plataforma **Pulyn** para visualizar eventos, pontuações e mapa interativo com zonas e checkpoints.

## 🎯 Filosofia de Desenvolvimento

> **🚫 Não criar nada novo. ✅ Replicar do Web.**

Todo o padrão de funcionamento (endpoints, lógica de dados, visualizações) já está implementado na versão **Web (React)** (`front-pulyn/src/`). O mobile Flutter **APENAS REPLICA** a mesma funcionalidade. 

**Isso significa:**
- Não inventar novos endpoints
- Não criar novas estruturas de dados
- Não mudar a lógica de negócio
- Apenas traduzir React → Flutter

### ⚡ Como Usar Esta Regra

**Quando precisar implementar uma feature:**

1. **Procure no Web** como é feito
   - Abra o arquivo correspondente em `front-pulyn/src/pages/` ou `front-pulyn/src/components/`
   - Veja quais endpoints são chamados
   - Veja como os dados são processados

2. **Replique no Mobile** com a mesma lógica
   - Adicione o método em `pulyn_app/lib/services/api_service.dart`
   - Crie o provider em `pulyn_app/lib/providers/index.dart`
   - Use o widget correspondente em `pulyn_app/lib/widgets/`

3. **Use os MESMOS endpoints**
   - Backend não muda
   - Web e Mobile chamam os mesmos endpoints
   - Dados são idênticos

### 📋 Checklist: Replicar uma Feature

- [ ] Encontrei no Web como é feito (`front-pulyn/src/pages/*/`)
- [ ] Identifiquei os endpoints utilizados (ex: `GET /api/eventos/:id/zones`)
- [ ] Adicionei o método em `api_service.dart`
- [ ] Criei/atualizei o provider em `providers/index.dart`
- [ ] Testei com logs para verificar dados
- [ ] Comparei com Web para garantir que é idêntico

### 📝 Exemplos de Replicação

#### ✅ Zonas (Zones)
Zonas e planta baixa são do buffet (empresa), não do evento — o espaço físico
não muda de uma festa para outra. Só os checkpoints são por evento.

**Web:** `front-pulyn/src/pages/display/DisplayMap.tsx`
```typescript
const zonesData = await api.getZones();
setZones(zonesData);
localStorage.setItem('zones_company', JSON.stringify(zonesData));
```

**Mobile:** `pulyn_app/lib/providers/index.dart`
```dart
final zones = await apiService.getZones();
await _cacheZonesToStorage(apiService, zones);
return zones;
```
**Resultado:** ✅ Idêntico

#### ✅ Checkpoints
**Web:** `front-pulyn/src/pages/display/DisplayMap.tsx`
```typescript
const checkpoints = await api.getCheckpoints(eventoAtual);
```

**Mobile:** `pulyn_app/lib/providers/index.dart`
```dart
final checkpoints = await apiService.getCheckpointsByEvent(eventoId);
```
**Resultado:** ✅ Idêntico

#### ✅ Floor Plan
**Web:** `front-pulyn/src/pages/display/DisplayMap.tsx`
```typescript
const floorPlan = await api.getFloorPlan();
```

**Mobile:** `pulyn_app/lib/services/api_service.dart`
```dart
Future<String?> getFloorPlan() async {
  final response = await _dio.get('/company-map/floor-plan');
}
```
**Resultado:** ✅ Idêntico

### 🔍 Se Tiver Dúvida

1. **Procure no Web** como é feito (use Ctrl+F para procurar)
2. **Adapte para Dart** (sintaxe, estrutura)
3. **Use os MESMOS endpoints** (não invente novos)
4. **Replique a lógica** (cache, validação, logs)
5. **Compare os resultados** (dados devem ser idênticos)

---

## 🏗️ Arquitetura

```
pulyn_app/
├── lib/
│   ├── main.dart                    # Entry point do app
│   ├── models/
│   │   └── family_models.dart       # Modelos de dados (Child, User, etc)
│   ├── screens/                     # Telas do app
│   │   ├── onboarding/
│   │   ├── child/
│   │   └── qr_scan/
│   ├── widgets/
│   │   └── event_map_widget.dart    # Widget principal do mapa
│   ├── providers/
│   │   └── index.dart               # Riverpod providers (state management)
│   ├── services/
│   │   └── api_service.dart         # Chamadas HTTP para backend
│   ├── utils/
│   │   └── logger.dart              # Sistema de logs
│   └── constants/
│       └── api_config.dart          # Configurações de API
└── pubspec.yaml                     # Dependências
```

---

## 🔗 Endpoints Utilizados

### Auth
- `POST /api/auth/login` - Login
- `POST /api/auth/register` - Registro

### Mapa do Buffet & Checkpoints
- `GET /api/company-map/floor-plan` - Carregar planta baixa (imagem do buffet, vale para todos os eventos)
- `GET /api/company-map/zones` - Carregar zonas/áreas do buffet (idem)
- `GET /api/checkpoints/evento/:evento_id` - Carregar checkpoints do evento (esses sim variam por evento)

### Pontuação & Ranking
- `GET /api/ranking/criancas/:evento_id` - Ranking de crianças
- `GET /api/ranking/times/:evento_id` - Ranking de times
- `GET /api/familias/children` - Lista de filhos da família

### WebSocket
- `ws://localhost:3001/` - Atualizações em tempo real (pontuação, posição de avatares)

---

## 🗺️ Exemplo: Zonas

### Web (React)
```typescript
// front-pulyn/src/pages/display/DisplayMap.tsx
useEffect(() => {
  const loadData = async () => {
    const zonesData = await api.getZones();
    if (zonesData && Array.isArray(zonesData) && zonesData.length > 0) {
      setZones(zonesData);
      localStorage.setItem('zones_company', JSON.stringify(zonesData));
    }
  };
  loadData();
}, []);
```

**O que faz:**
1. Busca zonas via `GET /api/company-map/zones` (uma vez, não por evento)
2. Salva no localStorage como cache
3. Se falhar, usa DEFAULT_ZONES como fallback

### Mobile (Flutter)
```dart
// pulyn_app/lib/providers/index.dart
final zonesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();

  final zones = await apiService.getZones(); // GET /api/company-map/zones

  await _cacheZonesToStorage(apiService, zones); // Salva no cache

  return zones;
});
```

**O que faz (idêntico ao Web):**
1. ✅ Busca zonas via `GET /api/eventos/:id/zones`
2. ✅ Salva em SharedPreferences como cache
3. ✅ Se falhar, retorna lista vazia (sem DEFAULT_ZONES, pois zonas vêm sempre do backend)

---

## 📊 Estrutura de Dados

### Zona (Zone)
```json
{
  "id": "uuid",
  "name": "Entrada",
  "color": "#1E9BD7",
  "x": 50,
  "y": 5,
  "width": 120,
  "height": 80
}
```

### Checkpoint
```json
{
  "id": "uuid",
  "name": "Torre Encantada",
  "zone": "Entrada",
  "map_x": 100,
  "map_y": 50,
  "led_color": "#00FF00",
  "status": "online"
}
```

### Floor Plan
```json
{
  "eventId": "uuid",
  "floorPlan": {
    "dataUrl": "data:image/png;base64,...",
    "name": "Buffet 2026",
    "type": "image/png"
  }
}
```

---

## 🎮 Como Funciona o Mapa

1. **App carrega evento ativo** via `GET /api/familias/children`
2. **Busca floor plan** via `GET /api/eventos/:id/floor-plan` (planta baixa do buffet)
3. **Busca zonas** via `GET /api/eventos/:id/zones` (áreas coloridas)
4. **Busca checkpoints** via `GET /api/checkpoints/evento/:evento_id` (pontos de interesse)
5. **Renderiza no flutter** com:
   - Floor plan como background
   - Zonas como retângulos coloridos
   - Checkpoints como ícones/pontos
   - Avatares das crianças com animação em tempo real

---

## 🔧 Setup & Desenvolvimento

### Instalar Dependências
```bash
cd pulyn_app
flutter pub get
```

### Rodar o App
```bash
# No emulador
flutter run

# Em dispositivo físico
flutter run -d <device_id>
```

### Logs
O app usa o sistema de logs customizado:
```dart
import 'package:pulyn_app/utils/logger.dart';

log.i('[TAG] Mensagem de info');
log.w('[TAG] Mensagem de warning');
log.e('[TAG] Mensagem de erro');
```

---

## 🌐 Configuração de API

### Local Development
```dart
// lib/constants/api_config.dart
ApiConfig.setEnvironment(ApiEnvironment.localhost);
// http://localhost:3001/api
```

### LAN (Servidor Local)
```dart
ApiConfig.setEnvironment(ApiEnvironment.lan);
// http://192.168.0.60:3001/api (configurável)
```

### Production
```dart
ApiConfig.setEnvironment(ApiEnvironment.production);
// https://api.pulyn.com/api
```

---

## 📚 Stack Técnico

- **Framework:** Flutter 3.x
- **State Management:** Riverpod
- **HTTP Client:** Dio
- **Local Storage:** SharedPreferences
- **Real-time:** WebSocket (dart:io)
- **Language:** Dart

---

## 🚀 Próximas Features

- [ ] Push notifications para pais
- [ ] Offline mode com sincronização
- [ ] Certificados digitais ao final do evento
- [ ] Relatórios de pontuação em PDF

---

## 🐛 Troubleshooting

### Erro 403 ao carregar Floor Plan/Zonas/Checkpoints
**Causa:** Usuário family não tem permissão

**Solução:** Verifique em `backendPulyn/routes/`:
- `events.js` - floor-plan endpoint deve permitir family role
- `events.js` - zones endpoint deve permitir family role
- `checkpoints.js` - evento checkpoints endpoint deve permitir family role

### Erro 404 ao carregar dados
**Causa:** Evento não existe no banco ou evento_id está vazio

**Solução:**
1. Verifique logs: `[CHECKPOINTS] 🎯 evento_id: xxx`
2. Se vazio: evento_id não está sendo retornado por `/api/familias/children`
3. Se 404: evento realmente não existe no banco

### Zonas não aparecem no mapa
**Causa:** Backend não salvou zonas ou endpoint retorna array vazio

**Solução:**
1. Verifique se zonas existem no banco: `SELECT zones_data FROM eventos WHERE id = '...'`
2. Verifique logs do app: `[ZONES] ✅ Zonas carregadas do backend: N áreas`
3. Se log mostra 0: não há zonas, adicione via admin web

### Checkpoints não aparecem
**Mesmo processo que Zonas**
1. Verifique se checkpoints existem: `SELECT * FROM checkpoints WHERE evento_id = '...'`
2. Verifique logs: `[CHECKPOINTS] Encontrados X checkpoints`
3. Se 0: crie checkpoints no admin web

---

## 📱 Replicando Novas Features

### Template: Adicionar um Novo Endpoint

**1. Veja no Web como é chamado** (`front-pulyn/src/`)
```typescript
const data = await api.getMyData(eventId);
```

**2. Adicione em `api_service.dart`**
```dart
Future<List<Map<String, dynamic>>> getMyData(String eventId) async {
  try {
    final response = await _dio.get('/api/my-endpoint/$eventId');
    final data = _validateResponseList(response.data);
    return data.map((item) => item as Map<String, dynamic>).toList();
  } catch (e) {
    log.e('[API] ❌ Erro: $e');
    return [];
  }
}
```

**3. Crie um provider em `providers/index.dart`**
```dart
final myDataProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final apiService = ref.read(apiServiceProvider);
  await apiService.init();
  
  log.i('[MY_DATA] 🔄 Buscando...');
  final data = await apiService.getMyData(eventId);
  
  return data;
});
```

**4. Use em um widget**
```dart
final dataAsync = ref.watch(myDataProvider(eventId));

return dataAsync.when(
  loading: () => CircularProgressIndicator(),
  error: (err, st) => Text('Erro: $err'),
  data: (data) => ListView(children: data.map((item) => Text(item['name'])).toList()),
);
```

**5. Verifique os logs**
Procure por `[MY_DATA]` para debugar
