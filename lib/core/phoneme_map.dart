const Map<String, dynamic> phonemeRehabData = {
  'level_2': [
    // --- ZONA ALTA (6kHz - 8kHz): Sibilantes e Fricativas Agudas ---
    {'target': 'Selo', 'distractor': 'Felo', 'freq_band': 6500, 'type': 'fricative'},
    {'target': 'Saca', 'distractor': 'Faca', 'freq_band': 7000, 'type': 'high_f'},
    {'target': 'Sino', 'distractor': 'Fino', 'freq_band': 7500, 'type': 'fricative'},
    {'target': 'Sete', 'distractor': 'Fete', 'freq_band': 6200, 'type': 'high_f'},
    {'target': 'Sina', 'distractor': 'Fina', 'freq_band': 7800, 'type': 'fricative'},
    {'target': 'Sala', 'distractor': 'Fala', 'freq_band': 6800, 'type': 'fricative'},
    {'target': 'Sopa', 'distractor': 'Fopa', 'freq_band': 6400, 'type': 'high_f'},
    {'target': 'Seda', 'distractor': 'Feda', 'freq_band': 6600, 'type': 'fricative'},
    {'target': 'Soma', 'distractor': 'Foma', 'freq_band': 7200, 'type': 'high_f'},
    {'target': 'Sela', 'distractor': 'Zela', 'freq_band': 6000, 'type': 'voiced_fricative'},
    {'target': 'Sosso', 'distractor': 'Fosso', 'freq_band': 8000, 'type': 'ultra_high'},
    {'target': 'Assa', 'distractor': 'Acha', 'freq_band': 6500, 'type': 'sibilant'},
    {'target': 'Passo', 'distractor': 'Pacho', 'freq_band': 6700, 'type': 'sibilant'},
    {'target': 'Cesta', 'distractor': 'Festa', 'freq_band': 6900, 'type': 'high_f'},
    {'target': 'Soco', 'distractor': 'Foco', 'freq_band': 7100, 'type': 'fricative'},

    // --- ZONA MÉDIA (3kHz - 5kHz): Plosivas e Transições ---
    {'target': 'Tia', 'distractor': 'Pia', 'freq_band': 4200, 'type': 'plosive'},
    {'target': 'Chave', 'distractor': 'Sabe', 'freq_band': 4800, 'type': 'sibilant'},
    {'target': 'Massa', 'distractor': 'Mata', 'freq_band': 5200, 'type': 'sibilant'},
    {'target': 'Vila', 'distractor': 'Fila', 'freq_band': 3800, 'type': 'labiodental'},
    {'target': 'Zelo', 'distractor': 'Selo', 'freq_band': 4500, 'type': 'voiced_fricative'},
    {'target': 'Gato', 'distractor': 'Cato', 'freq_band': 3200, 'type': 'velar'},
    {'target': 'Data', 'distractor': 'Tata', 'freq_band': 3500, 'type': 'plosive'},
    {'target': 'Bala', 'distractor': 'Pala', 'freq_band': 3000, 'type': 'bilabial'},
    {'target': 'Dedo', 'distractor': 'Tedo', 'freq_band': 3400, 'type': 'plosive'},
    {'target': 'Vento', 'distractor': 'Bento', 'freq_band': 4100, 'type': 'fricative_plosive'},
    {'target': 'Jato', 'distractor': 'Xato', 'freq_band': 4600, 'type': 'postalveolar'},
    {'target': 'Gelo', 'distractor': 'Chelo', 'freq_band': 4400, 'type': 'postalveolar'},
    {'target': 'Vaca', 'distractor': 'Faca', 'freq_band': 3900, 'type': 'fricative'},
    {'target': 'Zero', 'distractor': 'Sero', 'freq_band': 4300, 'type': 'voiced_sibilant'},
    {'target': 'Pote', 'distractor': 'Bote', 'freq_band': 3100, 'type': 'plosive'},

    // --- ZONA MÉDIA-BAIXA (2kHz - 3kHz): Nasais e Fricativas Sonoras ---
    // Nasais afetadas por perda em agudos: pistas de F2/F3 de transição
    {'target': 'Mala', 'distractor': 'Bala', 'freq_band': 2800, 'type': 'nasal'},
    {'target': 'Mola', 'distractor': 'Bola', 'freq_band': 2600, 'type': 'nasal'},
    {'target': 'Mudo', 'distractor': 'Budo', 'freq_band': 2900, 'type': 'nasal'},
    {'target': 'Nata', 'distractor': 'Data', 'freq_band': 2500, 'type': 'nasal'},
    {'target': 'Nada', 'distractor': 'Dada', 'freq_band': 2700, 'type': 'nasal'},
    {'target': 'Nobre', 'distractor': 'Dobre', 'freq_band': 2400, 'type': 'nasal'},
    // Fricativas sonoras /z/ — confundidas com /s/ por perda em agudos
    {'target': 'Zona', 'distractor': 'Sona', 'freq_band': 4000, 'type': 'voiced_sibilant'},
    {'target': 'Zaga', 'distractor': 'Saga', 'freq_band': 4200, 'type': 'voiced_sibilant'},
    {'target': 'Zela', 'distractor': 'Sela', 'freq_band': 4100, 'type': 'voiced_sibilant'},

  ]
};
