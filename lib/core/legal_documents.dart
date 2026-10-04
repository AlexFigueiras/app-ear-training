/// Documentos legais exibidos no app [LGPD/PLAY].
///
/// A política é o MESMO arquivo publicado na web (docs/legal/, URL informada na Play Console):
/// fonte única, sem cópia para divergir.
class LegalDocuments {
  const LegalDocuments._();

  static const String privacyPolicyAsset =
      'docs/legal/politica-de-privacidade.md';

  /// Versão vigente da política, gravada junto com o consentimento no cadastro. Ao mudar a
  /// política, atualize aqui e no cabeçalho do arquivo (test/legal_documents_test.dart confere).
  static const String privacyPolicyVersion = '2026-10-04';

  /// Aviso de saúde (política "Health Content and Services" da Google Play).
  static const String healthDisclaimer =
      'O BOSYN é um programa de treino auditivo. Não é um dispositivo médico, não faz '
      'diagnóstico e não substitui a avaliação de um fonoaudiólogo ou médico '
      'otorrinolaringologista. O teste auditivo do app é uma estimativa feita com o seu fone, '
      'usada só para personalizar o treino. Use sempre um volume confortável. Se notar perda '
      'auditiva súbita, zumbido persistente, dor ou tontura, procure atendimento profissional.';
}
