#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Todas as correções necessárias para propriedades nativas
const allFixes = [
  // state/estado
  { wrong: /\bestado\s*=/g, correct: 'state =' },
  { wrong: /\bestado,/g, correct: 'state,' },
  { wrong: /\bestado\)/g, correct: 'state)' },

  // text/texto em constructors
  { wrong: /texto\s*:/g, correct: 'text:' },
  { wrong: /this\.texto/g, correct: 'this.text' },
  { wrong: /required this\.texto/g, correct: 'required this.text' },

  // color/cor em constructors
  { wrong: /cor\s*:/g, correct: 'color:' },
  { wrong: /this\.cor/g, correct: 'this.color' },
  { wrong: /required this\.cor/g, correct: 'required this.color' },
  { wrong: /final String cor/g, correct: 'final String color' },
  { wrong: /final Color cor/g, correct: 'final Color color' },
  { wrong: /this\.cor,/g, correct: 'this.color,' },

  // tipo em constructors
  { wrong: /tipo\s*:/g, correct: 'type:' },
  { wrong: /this\.tipo/g, correct: 'this.type' },
  { wrong: /required this\.tipo/g, correct: 'required this.type' },
  { wrong: /final String tipo/g, correct: 'final String type' },

  // nome em constructors
  { wrong: /nome\s*:/g, correct: 'name:' },
  { wrong: /this\.nome/g, correct: 'this.name' },
  { wrong: /required this\.nome/g, correct: 'required this.name' },

  // message/mensagem
  { wrong: /\.mensagem/g, correct: '.message' },
  { wrong: /mensagem:/g, correct: 'message:' },
];

function fixFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    let originalContent = content;

    allFixes.forEach(({ wrong, correct }) => {
      content = content.replace(wrong, correct);
    });

    if (content !== originalContent) {
      fs.writeFileSync(filePath, content, 'utf-8');
      return true;
    }
    return false;
  } catch (error) {
    console.error(`Erro: ${filePath}: ${error.message}`);
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

  console.log('🔧 Corrigindo todos os problemas de propriedades nativas...\n');
  const fixed = findAndFixFiles(libDir);

  console.log(`\n✅ Pronto! ${fixed} arquivo(s) corrigido(s).`);
}

main();
