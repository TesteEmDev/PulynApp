#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Mapa de conversões para Dart
const conversions = {
  // Nomes
  'name': 'nome',
  'family_name': 'nomeFamilia',
  'responsible_name': 'nomeResponsavel',
  'sender': 'remetente',
  'client': 'cliente',
  'assignee': 'atribuidoPara',

  // Descrição
  'description': 'descricao',

  // Tipo/Status
  'type': 'tipo',
  'role': 'perfil',
  'status': 'status',
  'priority': 'prioridade',

  // Localização
  'city': 'cidade',
  'state': 'estado',
  'zone': 'zona',
  'ip': 'ip',
  'location': 'localizacao',
  'latitude': 'latitude',
  'longitude': 'longitude',

  // Contato
  'email': 'email',
  'phone': 'telefone',
  'password': 'senha',

  // Dados
  'points': 'pontos',
  'scores': 'pontos',
  'plan': 'plano',
  'avatar': 'avatar',

  // Brincadeira
  'rules': 'regras',
  'default_points': 'pontosPadrao',
  'game_type': 'tipoJogo',
  'checkpoints': 'checkpoints',

  // Criança
  'nickname': 'apelido',
  'age': 'idade',
  'bracelet_code': 'codigoPulseira',

  // Checkpoint
  'checkpoint_purpose': 'proposito',
  'map_x': 'mapaX',
  'map_y': 'mapaY',
  'led_color': 'corLed',
  'territory_owner_time_id': 'territorioDonoTimeId',
  'territory_owner_crianca_id': 'territorioDonosCriancaId',
  'territory_locked_until': 'territorioTravadoAte',
  'territory_cooldown_until': 'territorioCooldownAte',
  'authorized_tags': 'tagsAutorizadas',

  // Evento
  'enable_display': 'exibirDisplay',
  'enable_location': 'exibirLocalizacao',
  'active_game_type': 'tipoJogoAtivo',
  'active_brincadeira_id': 'brincadeiraAtivaId',
  'floor_plan_data': 'dadosPlanoPiso',
  'floor_plan_name': 'nomePlanoPiso',
  'floor_plan_type': 'tipoPlanoPiso',
  'auto_start': 'autoInicio',
  'auto_end': 'autoFim',

  // Leitura
  'authorized': 'autorizado',
  'points_awarded': 'pontosAtribuidos',
  'signal_strength': 'forcaSinal',

  // Pontos
  'points_multiplier': 'multiplicadorPontos',
  'required_type': 'tipoRequerido',
  'required_value': 'valorRequerido',
  'points_bonus': 'pontosBonus',

  // Outras
  'color': 'cor',
  'code': 'codigo',
  'subject': 'assunto',
  'message': 'mensagem',
  'details': 'detalhes',
  'text': 'texto',
  'cnpj': 'cnpj',
  'relationship': 'relacionamento',
  'setting_key': 'chave',
  'setting_value': 'valor',
  'token_hash': 'hashToken',
  'uid': 'uid',

  // Tempos
  'round_number': 'numeroRonda',
  'target_checkpoint_id': 'checkpointAlvoId',
  'completed_checkpoint_ids': 'checkpointsCompletadosIds',
  'starting_team_id': 'timeInicialId',
  'turn_team_id': 'timeVezId',
  'turn_available_at': 'vezDisponvelEm',
  'round_started_at': 'rondaIniciadaEm',
  'elapsed_ms': 'msDecorridos',
  'events_done': 'eventosRealizados',
  'created_by': 'criadoPor',
  'approved_by': 'aprovadoPor',
  'approved_at': 'aprovadoEm',
  'rejected_at': 'rejeitadoEm',
  'expires_at': 'expiramEm',
  'used_at': 'usadoEm',
  'data_criacao': 'dataCriacao',
  'data_atualizacao': 'dataAtualizacao',
};

function updateFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    let originalContent = content;

    // Ordenar keys por tamanho (maior primeiro)
    const sortedKeys = Object.keys(conversions).sort((a, b) => b.length - a.length);

    sortedKeys.forEach(english => {
      const portuguese = conversions[english];

      // Padrão para @JsonKey(name: 'campo')
      const jsonKeyPattern = new RegExp(`@JsonKey\\(name: '${english}'\\)`, 'g');
      content = content.replace(jsonKeyPattern, `@JsonKey(name: '${portuguese}')`);

      // Padrão geral com word boundaries
      const generalPattern = new RegExp('\\b' + english + '\\b', 'g');
      content = content.replace(generalPattern, portuguese);
    });

    if (content !== originalContent) {
      fs.writeFileSync(filePath, content, 'utf-8');
      return true;
    }
    return false;
  } catch (error) {
    console.error(`Erro ao processar ${filePath}:`, error.message);
    return false;
  }
}

function findAndUpdateFiles(dir, extensions = ['.dart']) {
  const files = fs.readdirSync(dir);
  let updated = 0;

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory() && !file.startsWith('.')) {
      updated += findAndUpdateFiles(filePath, extensions);
    } else if (extensions.some(ext => file.endsWith(ext))) {
      if (updateFile(filePath)) {
        console.log(`✅ ${path.relative(process.cwd(), filePath)}`);
        updated++;
      }
    }
  });

  return updated;
}

function main() {
  const libDir = path.join(__dirname, 'lib');

  console.log('🇧🇷 Refatorando Flutter para português completo...\n');
  const updated = findAndUpdateFiles(libDir);

  console.log(`\n✅ Refatoração completa!`);
  console.log(`   ${updated} arquivo(s) Dart atualizado(s)`);
}

main();
