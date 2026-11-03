import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Política de Privacidade do app, dentro do próprio app (lida sem internet).
/// Texto para revisão: a versão publicada na web fica em docs/politica-de-privacidade.html.
class PoliticaPrivacidadeScreen extends StatelessWidget {
  const PoliticaPrivacidadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Pulyn Family',
                  style: TextStyle(color: PulynColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Última atualização: 03/11/2026',
                  style: TextStyle(color: PulynColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Esta política explica quais dados o Pulyn Family coleta, por que coleta, com quem compartilha e quais são os seus direitos. Ela foi escrita para responsáveis que usam o app para acompanhar seus filhos em eventos. O app é voltado a responsáveis adultos. Crianças não devem usá-lo nem criar contas.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 20),
                for (final secao in _secoes) _SecaoView(secao),
                const SizedBox(height: 12),
                Text(
                  'ADVANTAG TECNOLOGIA E SERVICOS LTDA - EPP · contato@advantag.com.br',
                  style: TextStyle(color: PulynColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Secao {
  final String titulo;
  final List<String> paragrafos;
  final List<String> itens;

  const _Secao(this.titulo, {this.paragrafos = const [], this.itens = const []});
}

class _SecaoView extends StatelessWidget {
  const _SecaoView(this.secao);

  final _Secao secao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            secao.titulo,
            style: const TextStyle(
              color: PulynColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final paragrafo in secao.paragrafos)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(paragrafo, style: const TextStyle(height: 1.5)),
            ),
          for (final item in secao.itens)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Text('• $item', style: const TextStyle(height: 1.5)),
            ),
        ],
      ),
    );
  }
}

const _secoes = <_Secao>[
  _Secao(
    '1. Quem é o responsável pelos dados',
    paragrafos: [
      'ADVANTAG TECNOLOGIA E SERVICOS LTDA - EPP, CNPJ 28.300.306/0001-82, com sede em Rua Vaticano, 121 - Jardim Fontana, Cotia - SP, CEP 06713-040.',
      'Contato para assuntos de privacidade: contato@advantag.com.br, telefone +55 11 4301-0636. Encarregado de proteção de dados (DPO): contato@advantag.com.br.',
    ],
  ),
  _Secao(
    '2. Quais dados coletamos',
    paragrafos: ['Dados da conta do responsável:'],
    itens: [
      'E-mail e senha, usados para entrar no app. A senha nunca é exibida.',
      'Nome da família, informado no cadastro.',
      'Telefone com DDD, para a organização do evento falar com você se algo acontecer com a criança.',
      'Data de criação da conta e data do último acesso.',
    ],
  ),
  _Secao(
    'Dados das crianças vinculadas (informados pela organização do evento e pelo cadastro do responsável)',
    itens: [
      'Nome e apelido.',
      'Data de nascimento, usada para calcular a idade da criança.',
      'Avatar escolhido para a criança.',
      'Pontuação, equipe e evento em que a criança participa.',
      'Código da pulseira de identificação, usado para vincular a criança.',
    ],
  ),
  _Secao(
    'Dados de vínculo e técnicos',
    itens: [
      'Quais crianças estão vinculadas à sua conta, o status do vínculo e as datas em que ele foi criado ou desfeito.',
      'Registros técnicos do servidor, como horário das requisições e identificadores da conta. Esses registros podem conter o seu e-mail e os identificadores internos.',
    ],
  ),
  _Secao(
    'Permissões do celular',
    itens: [
      'Câmera: usada somente para ler o QR Code de vinculação. As imagens da câmera não são salvas.',
      'NFC: usado somente para ler a pulseira da criança durante a vinculação. O código lido é enviado ao servidor para validar o vínculo.',
      'Internet: necessária para entrar, sincronizar dados e acompanhar o evento em tempo real.',
    ],
    paragrafos: [
      'O app não coleta a localização do celular, não acessa contatos e não lê fotos da galeria.',
    ],
  ),
  _Secao(
    '3. Para que usamos os dados',
    itens: [
      'Criar e manter a sua conta e permitir o acesso ao app.',
      'Vincular o responsável à criança e mostrar o acompanhamento do evento: mapa, pontuação e ranking.',
      'Enviar e-mails de confirmação de cadastro, de recuperação de senha e atualizações em tempo real sobre o evento.',
      'Cumprir obrigações legais e proteger o serviço contra acessos indevidos.',
    ],
    paragrafos: [
      'Não usamos esses dados para publicidade nem para criar perfis de comportamento.',
    ],
  ),
  _Secao(
    '4. Base legal e dados de crianças',
    paragrafos: [
      'Tratamos os dados com base na execução do serviço contratado e, quando envolvem crianças, no consentimento específico e em destaque de pelo menos um dos pais ou responsáveis legais, como exige o art. 14 da Lei Geral de Proteção de Dados (LGPD). Esse consentimento é dado ao criar a conta, marcando a caixa de aceite no cadastro.',
      'Coletamos apenas o mínimo necessário para o acompanhamento do evento. Não pedimos endereço, escola nem dados de saúde das crianças.',
    ],
  ),
  _Secao(
    '5. Com quem compartilhamos',
    itens: [
      'Organização do evento: tem acesso aos dados das crianças e das contas vinculadas, para operar o evento.',
      'Outras famílias: não recebem os dados da sua criança. No app, cada responsável vê apenas as crianças vinculadas à própria conta.',
      'Provedores de infraestrutura e envio: Render (hospedagem do servidor), Supabase (banco de dados) e Brevo (envio de e-mails), que processam os dados em nosso nome.',
    ],
    paragrafos: [
      'Não vendemos nem alugamos dados pessoais. Compartilhamos dados com autoridades somente quando a lei exigir.',
    ],
  ),
  _Secao(
    '6. Por quanto tempo guardamos os dados',
    paragrafos: [
      'Mantemos os dados enquanto a conta e o vínculo estiverem ativos. Depois que você desvincular uma criança, o vínculo deixa de aparecer no app. Os dados são apagados ou anonimizados quando você pedir a exclusão, salvo quando a lei exigir a guarda por mais tempo.',
    ],
  ),
  _Secao(
    '7. Segurança',
    paragrafos: [
      'A comunicação entre o app e o servidor é feita por HTTPS. O acesso à conta é protegido por token de sessão, e a senha é guardada de forma cifrada. Limitamos o número de tentativas de vinculação e de códigos para impedir adivinhação. Mesmo assim, nenhum sistema é totalmente seguro. Se você notar algo suspeito, avise-nos pelo contato da seção 1.',
    ],
  ),
  _Secao(
    '8. Seus direitos',
    paragrafos: ['Pela LGPD, você pode pedir a qualquer momento:'],
    itens: [
      'Confirmação de que tratamos seus dados e acesso a eles.',
      'Correção de dados incompletos ou incorretos.',
      'Exclusão dos dados, da sua conta e das crianças vinculadas. A conta pode ser excluída no próprio app, em Perfil → Excluir conta.',
      'Informação sobre com quem os dados foram compartilhados.',
      'Revogação do consentimento, o que pode impedir o uso do app.',
    ],
  ),
  _Secao(
    '9. Alterações nesta política',
    paragrafos: [
      'Podemos atualizar esta política. Quando a mudança for relevante, avisaremos pelo app ou por e-mail antes de ela valer.',
    ],
  ),
];
