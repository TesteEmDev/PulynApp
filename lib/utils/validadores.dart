// Regras dos campos de formulário. Login, cadastro e convite da família usam estas mesmas funções,
// para a mesma coisa nunca ser aceita numa tela e recusada em outra. Devolvem a mensagem de erro, ou null quando está certo.

final RegExp _formatoEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const int minimoSenha = 6;

String? validarEmail(String? valor) {
  if (valor == null || valor.isEmpty) return 'Email é obrigatório';
  if (!_formatoEmail.hasMatch(valor)) return 'Email inválido';
  return null;
}

String? validarSenha(String? valor) {
  if (valor == null || valor.isEmpty) return 'Senha é obrigatória';
  if (valor.length < minimoSenha) return 'Senha deve ter no mínimo $minimoSenha caracteres';
  return null;
}

String? validarConfirmacaoSenha(String? valor, String senha) {
  if (valor == null || valor.isEmpty) return 'Confirme a senha';
  if (valor != senha) return 'As senhas não conferem';
  return null;
}

/// Nome completo: nome e sobrenome, sem números.
String? validarNome(String? valor) {
  if (valor == null || valor.isEmpty) return 'Nome é obrigatório';
  if (valor.length < 2) return 'Nome deve ter no mínimo 2 caracteres';
  if (valor.length > 100) return 'Nome não pode ter mais de 100 caracteres';
  if (RegExp(r'\d').hasMatch(valor)) return 'Nome não pode conter números';
  if (valor.trim().split(RegExp(r'\s+')).length < 2) return 'Por favor, insira seu nome completo (nome e sobrenome)';
  return null;
}
