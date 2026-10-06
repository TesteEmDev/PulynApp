#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Mapa de conversões
const conversions = {
  'cliente_id': 'clienteId',
  'evento_id': 'eventoId',
  'brincadeira_id': 'brincadeiraId',
  'crianca_id': 'criancaId',
  'time_id': 'timeId',
  'empresa_id': 'empresaId',
  'checkpoint_id': 'checkpointId',
  'leitura_id': 'leituraId',
  'partida_id': 'partidaId',
  'created_at': 'criadoEm',
  'updated_at': 'atualizadoEm',
  'started_at': 'iniciadoEm',
  'finished_at': 'finalizadoEm',
  'completed_at': 'completadoEm',
  'scanned_at': 'leroEm',
  'sent_at': 'enviadoEm',
  'data_criacao': 'dataCriacao',
  'data_atualizacao': 'dataAtualizacao',
  'family_name': 'nomeFamilia',
  'default_points': 'pontosPadrao',
  'game_type': 'tipoJogo',
  'bracelet_code': 'codigoPulseira',
  'points_awarded': 'pontosAtribuidos',
  'authorized_tags': 'tagsAutorizadas',
};

function updateFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    let originalContent = content;

    // Atualizar @JsonKey annotations
    Object.entries(conversions).forEach(([snake, camel]) => {
      // Padrão: @JsonKey(name: 'column_name')
      const pattern = new RegExp(`@JsonKey\\(name: '${snake}'\\)`, 'g');
      content = content.replace(pattern, `@JsonKey(name: '${camel}')`);

      // Padrão direto no código
      const codePattern = new RegExp('\\b' + snake + '\\b', 'g');
      content = content.replace(codePattern, camel);
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

function findAndUpdateFiles(dir) {
  const files = fs.readdirSync(dir);
  let updated = 0;

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      if (!file.startsWith('.')) {
        updated += findAndUpdateFiles(filePath);
      }
    } else if (file.endsWith('.dart')) {
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

  console.log('🔄 Atualizando arquivos Dart...\n');
  const updated = findAndUpdateFiles(libDir);
  console.log(`\n✅ Atualização concluída! ${updated} arquivo(s) modificado(s).`);
}

main();
