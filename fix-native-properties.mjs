#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Propriedades nativas do Flutter/Dart que NÃO devem ser renomeadas
const nativePropertyFixes = [
  // StateNotifier - state é propriedade nativa obrigatória
  { wrong: /\bestado\s*=/g, correct: 'state =' },
  { wrong: /\bestado\./g, correct: 'state.' },
  { wrong: /:\s*estado\b/g, correct: ': state' },
  { wrong: /\(estado\)/g, correct: '(state)' },
  { wrong: /\s+estado,/g, correct: ' state,' },
  { wrong: /\s+estado\)/g, correct: ' state)' },

  // TextEditingController - text é propriedade nativa
  { wrong: /\.texto\b/g, correct: '.text' },
  { wrong: /controller\.texto/g, correct: 'controller.text' },

  // Flutter Widget parameters - color é nativo
  { wrong: /\bcor:\s/g, correct: 'color: ' },
  { wrong: /\bcor\)/g, correct: 'color)' },
  { wrong: /\bcor,/g, correct: 'color,' },

  // AutofillHints - name é constante nativa
  { wrong: /AutofillHints\.nome/g, correct: 'AutofillHints.name' },
  { wrong: /autofillHints\.nome/g, correct: 'autofillHints.name' },
];

function fixFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    let originalContent = content;

    // Aplicar correções
    nativePropertyFixes.forEach(({ wrong, correct }) => {
      content = content.replace(wrong, correct);
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
