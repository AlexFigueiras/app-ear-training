// Edge Function `tts`: proxy autenticado para o Google Cloud Text-to-Speech.
//
// Por que existe: a chave do Google não pode ficar no app (qualquer pessoa a extrai do APK, e
// o repositório é público). Ela fica só aqui, como secret da função:
//   supabase secrets set GOOGLE_TTS_API_KEY=<chave nova, restrita à API Text-to-Speech>
// Só usuário autenticado chama (auth 'user'), e o texto é validado e limitado para a função
// não virar TTS grátis para terceiros. O teto de custo real é a cota da API + alerta de
// orçamento no Google Cloud (docs/PLAY_STORE.md).
//
// Contrato com o app (lib/services/tts_service.dart): POST JSON
//   { text, languageCode, voiceName, speakingRate, pitch }
// → 200 application/octet-stream com o WAV LINEAR16 | 4xx/5xx JSON { error }.
import { withSupabase } from "npm:@supabase/server@1";

const GOOGLE_TTS_URL = "https://texttospeech.googleapis.com/v1/text:synthesize";
const MAX_TEXT_LENGTH = 120; // maior frase falada pelo app hoje tem ~60 caracteres
const ALLOWED_LANGUAGE = "pt-BR";
const DEFAULT_VOICE = "pt-BR-Wavenet-A";
const VOICE_PATTERN = /^pt-BR-[A-Za-z0-9]+-[A-Z]$/; // ex.: pt-BR-Wavenet-A, pt-BR-Neural2-B

function errorResponse(error: string, status: number): Response {
  return Response.json({ error }, { status });
}

function clamp(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, value));
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req) => {
    if (req.method !== "POST") return errorResponse("method_not_allowed", 405);

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return errorResponse("invalid_json", 400);
    }

    const text = typeof body.text === "string" ? body.text.trim() : "";
    if (!text || text.length > MAX_TEXT_LENGTH) return errorResponse("invalid_text", 400);

    const languageCode = body.languageCode ?? ALLOWED_LANGUAGE;
    if (languageCode !== ALLOWED_LANGUAGE) return errorResponse("invalid_language", 400);

    const voiceName = body.voiceName ?? DEFAULT_VOICE;
    if (typeof voiceName !== "string" || !VOICE_PATTERN.test(voiceName)) {
      return errorResponse("invalid_voice", 400);
    }

    const apiKey = Deno.env.get("GOOGLE_TTS_API_KEY");
    if (!apiKey) {
      console.error("tts: secret GOOGLE_TTS_API_KEY ausente");
      return errorResponse("server_misconfigured", 500);
    }

    const googleResponse = await fetch(GOOGLE_TTS_URL, {
      method: "POST",
      // Chave no header, nunca na URL: não aparece em logs de acesso.
      headers: { "Content-Type": "application/json", "X-Goog-Api-Key": apiKey },
      body: JSON.stringify({
        input: { text },
        voice: { languageCode, name: voiceName },
        audioConfig: {
          audioEncoding: "LINEAR16",
          // Taxa do motor de áudio do app. Sem isto o Google devolve a taxa nativa da voz
          // (24 kHz no WaveNet) e o app tocava a fala uma oitava acima e 2x mais rápida.
          sampleRateHertz: 48000,
          speakingRate: clamp(body.speakingRate, 0.25, 4.0, 1.0),
          pitch: clamp(body.pitch, -20.0, 20.0, 0.0),
        },
      }),
    });

    if (!googleResponse.ok) {
      console.error("tts: Google respondeu", googleResponse.status);
      return errorResponse("tts_upstream_error", 502);
    }

    const { audioContent } = await googleResponse.json();
    if (typeof audioContent !== "string") return errorResponse("tts_upstream_error", 502);

    const audio = Uint8Array.from(atob(audioContent), (char) => char.charCodeAt(0));
    return new Response(audio, { headers: { "Content-Type": "application/octet-stream" } });
  }),
};
