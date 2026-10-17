/// Plano do usuário como o servidor gravou em `profiles` [MONETIZAÇÃO]. O app só lê: quem
/// escreve é a Edge Function `play-subscription`/`play-rtdn` (migration 004).
///
/// Valores de `subscription_status`: 'free'; 'pro' (Google Play, com validade); 'elite' (dado à
/// mão, sem validade).
class ProAccess {
  final String status;
  final DateTime? expiresAt;

  const ProAccess({required this.status, this.expiresAt});

  static const ProAccess free = ProAccess(status: 'free');

  /// Linha de `profiles` (ou null sem perfil). Campo ausente ou data inválida = sem validade.
  factory ProAccess.fromProfile(Map<String, dynamic>? row) {
    final status = row?['subscription_status'];
    final expires = row?['subscription_expires_at'];
    return ProAccess(
      status: status is String && status.isNotEmpty ? status : 'free',
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
    );
  }

  /// PRO vale com plano diferente de 'free' e validade no futuro. Sem validade: PRO dado à mão
  /// ou perfil gravado antes da migration 004.
  bool isActiveAt(DateTime now) =>
      status != 'free' && (expiresAt == null || expiresAt!.isAfter(now));

  @override
  bool operator ==(Object other) =>
      other is ProAccess &&
      other.status == status &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(status, expiresAt);
}
