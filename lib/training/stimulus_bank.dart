/// Tipo de contraste treinado e a faixa de frequência onde está a pista que distingue o par.
enum Contrast {
  /// /s/ × /ʃ/ (sapo × chapéu): o /s/ concentra energia acima de ~5 kHz, o /ʃ/ por volta de
  /// 2,5–4 kHz. A diferença está entre 3 e 6 kHz.
  sVsSh(cueBandHz: 4000, label: 's × ch'),

  /// /s/ × /f/: o /s/ é forte nos agudos, o /f/ é fraco e espalhado.
  sVsF(cueBandHz: 6000, label: 's × f'),

  /// /t/ × /p/ (ponto de articulação): explosão do /t/ nos agudos, a do /p/ difusa e grave.
  tVsP(cueBandHz: 4000, label: 't × p'),

  /// /t/ × /k/: explosão do /k/ em ~2–3 kHz, a do /t/ acima de 4 kHz.
  tVsK(cueBandHz: 3000, label: 't × k'),

  /// /s/ final (singular × plural): a única pista do plural é um /s/ fraco e agudo no fim.
  finalS(cueBandHz: 6000, label: 'plural'),

  /// Vozeamento/nasalidade (faca × vaca): pistas GRAVES, preservadas na perda em agudos.
  /// Só aquecimento — não treina agudos (Miller & Nicely, 1955).
  warmUp(cueBandHz: 500, label: 'aquecimento');

  final int cueBandHz;
  final String label;

  const Contrast({required this.cueBandHz, required this.label});

  bool get isHighFrequency => this != Contrast.warmUp;
}

/// Par mínimo: duas palavras REAIS que só diferem no contraste. Qualquer uma pode ser a tocada,
/// então a resposta não é memorizável nem dedutível por "qual palavra existe" (achado D1).
class MinimalPair {
  final String a;
  final String b;
  final Contrast contrast;

  const MinimalPair(this.a, this.b, this.contrast);

  String get id => '$a/$b';
}

/// Banco de pares do treino de palavras parecidas.
///
/// Substitui o antigo `phoneme_map.dart`, cujo alvo era sempre a mesma palavra do par, que tinha
/// pseudopalavras ("Felo", "Fopa") e metade dos itens em contrastes graves.
/// Revisão por fonoaudiólogo recomendada (frequência de uso, pronúncia do TTS).
class StimulusBank {
  const StimulusBank._();

  static const List<MinimalPair> pairs = [
    // /s/ × /ʃ/
    MinimalPair('são', 'chão', Contrast.sVsSh),
    MinimalPair('soro', 'choro', Contrast.sVsSh),
    MinimalPair('seque', 'cheque', Contrast.sVsSh),
    MinimalPair('socar', 'chocar', Contrast.sVsSh),
    MinimalPair('roça', 'rocha', Contrast.sVsSh),
    MinimalPair('mansa', 'mancha', Contrast.sVsSh),
    MinimalPair('assa', 'acha', Contrast.sVsSh),
    MinimalPair('assado', 'achado', Contrast.sVsSh),
    MinimalPair('seca', 'checa', Contrast.sVsSh),

    // /s/ × /f/
    MinimalPair('sala', 'fala', Contrast.sVsF),
    MinimalPair('saca', 'faca', Contrast.sVsF),
    MinimalPair('sino', 'fino', Contrast.sVsF),
    MinimalPair('soco', 'foco', Contrast.sVsF),
    MinimalPair('cesta', 'festa', Contrast.sVsF),
    MinimalPair('sorte', 'forte', Contrast.sVsF),
    MinimalPair('sim', 'fim', Contrast.sVsF),
    MinimalPair('sumo', 'fumo', Contrast.sVsF),
    MinimalPair('seio', 'feio', Contrast.sVsF),
    MinimalPair('sede', 'fede', Contrast.sVsF),

    // /t/ × /p/
    MinimalPair('tia', 'pia', Contrast.tVsP),
    MinimalPair('tato', 'pato', Contrast.tVsP),
    MinimalPair('tinta', 'pinta', Contrast.tVsP),
    MinimalPair('tão', 'pão', Contrast.tVsP),
    MinimalPair('tente', 'pente', Contrast.tVsP),
    MinimalPair('touca', 'pouca', Contrast.tVsP),
    MinimalPair('tosse', 'posse', Contrast.tVsP),
    MinimalPair('tomba', 'pomba', Contrast.tVsP),

    // /t/ × /k/
    MinimalPair('tola', 'cola', Contrast.tVsK),
    MinimalPair('tapa', 'capa', Contrast.tVsK),
    MinimalPair('torre', 'corre', Contrast.tVsK),
    MinimalPair('toca', 'coca', Contrast.tVsK),
    MinimalPair('tanto', 'canto', Contrast.tVsK),
    MinimalPair('tão', 'cão', Contrast.tVsK),

    // /s/ final (plural)
    MinimalPair('gato', 'gatos', Contrast.finalS),
    MinimalPair('carro', 'carros', Contrast.finalS),
    MinimalPair('livro', 'livros', Contrast.finalS),
    MinimalPair('casa', 'casas', Contrast.finalS),
    MinimalPair('mesa', 'mesas', Contrast.finalS),
    MinimalPair('porta', 'portas', Contrast.finalS),
    MinimalPair('prato', 'pratos', Contrast.finalS),
    MinimalPair('copo', 'copos', Contrast.finalS),
    MinimalPair('bolo', 'bolos', Contrast.finalS),
    MinimalPair('dedo', 'dedos', Contrast.finalS),

    // Aquecimento (pistas graves)
    MinimalPair('faca', 'vaca', Contrast.warmUp),
    MinimalPair('pato', 'bato', Contrast.warmUp),
    MinimalPair('tia', 'dia', Contrast.warmUp),
    MinimalPair('cola', 'gola', Contrast.warmUp),
    MinimalPair('mala', 'bala', Contrast.warmUp),
  ];

  static Iterable<MinimalPair> of(Contrast contrast) => pairs.where((p) => p.contrast == contrast);

  /// Vozes pt-BR do Google TTS (várias vozes generalizam melhor que uma só — Logan, Lively &
  /// Pisoni, 1991). A primeira é a padrão da Edge Function.
  static const List<String> voices = ['pt-BR-Wavenet-A', 'pt-BR-Wavenet-B', 'pt-BR-Wavenet-C'];
}
