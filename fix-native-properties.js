#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Propriedades nativas do Flutter/Dart que NÃO devem ser renomeadas
const nativePropertyFixes = {
  // StateNotifier - state é propriedade nativa obrigatória
  'estado =': 'state =',
  'estado.': 'state.',
  ': estado': ': state',
  '(estado)': '(state)',
  ' estado,': ' state,',
  ' estado)': ' state)',

  // TextEditingController - text é propriedade nativa
  'controller.texto': 'controller.text',
  '.texto =': '.text =',
  '.texto;': '.text;',
  '?.texto': '?.text',

  // Flutter Widget parameters - color é nativo
  'cor: ': 'color: ',
  'cor)': 'color)',
  'cor,': 'color,',

  // AutofillHints - name é constante nativa
  'AutofillHints.nome': 'AutofillHints.name',
  'autofillHints.nome': 'autofillHints.name',
};

function fixFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    let originalContent = content;

    // Aplicar correções
    Object.entries(nativePropertyFixes).forEach(([wrong, correct]) => {
      const pattern = new RegExp(wrong.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');
      content = content.replace(pattern, correct);
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

function findAndFixFiles(dir) {
  const files = fs.readdirSync(dir);
  let fixed = 0;

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory() && !file.startsWith('.')) {
      fixed += findAndFixFiles(filePath);
    } else if (file.endsWith('.dart')) {
      if (fixFile(filePath)) {
        console.log(`✅ ${path.relative(process.cwd(), filePath)}`);
        fixed++;
      }
    }
  });

  return fixed;
}

function main() {
  const libDir = path.join(__dirname, 'lib');

  console.log('🔧 Corrigindo propriedades nativas do Flutter...\n');
  const fixed = findAndFixFiles(libDir);

  console.log(`\n✅ Correção completa!`);
  console.log(`   ${fixed} arquivo(s) Dart corrigido(s)`);
}

main();
