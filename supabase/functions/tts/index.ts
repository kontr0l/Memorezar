import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");

// Map language codes to OpenAI TTS voices that sound best for each
// OpenAI voices: alloy, echo, fable, nova, onyx, shimmer
const VOICE_MAP: Record<string, string> = {
  default: "nova",
  en: "nova",
  es: "nova",
  fr: "shimmer",
  it: "nova",
  ar: "onyx",
  fa: "onyx",
  de: "nova",
  pt: "nova",
  zh: "nova",
  ja: "nova",
  ko: "nova",
};

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type, apikey, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!OPENAI_API_KEY) {
    return new Response(
      JSON.stringify({ error: "OpenAI API key not configured" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const { text, language, voice } = await req.json();

    if (!text || typeof text !== "string") {
      return new Response(
        JSON.stringify({ error: "text is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Cap text length to prevent abuse (2000 chars is plenty for any quote)
    if (text.length > 2000) {
      return new Response(
        JSON.stringify({ error: "Text too long (max 2000 characters)" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const lang = (language || "en").split("-")[0]; // "es-ES" → "es"
    const selectedVoice = voice || VOICE_MAP[lang] || VOICE_MAP.default;

    const openaiRes = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "tts-1",
        input: text,
        voice: selectedVoice,
        response_format: "aac",
        speed: 0.9, // slightly slower for memorization
      }),
    });

    if (!openaiRes.ok) {
      const err = await openaiRes.text();
      console.error("[TTS] OpenAI error:", openaiRes.status, err);
      return new Response(
        JSON.stringify({ error: "TTS generation failed" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    const audioData = await openaiRes.arrayBuffer();

    return new Response(audioData, {
      headers: {
        "Content-Type": "audio/aac",
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "public, max-age=86400", // CDN cache 24h
      },
    });
  } catch (e) {
    console.error("[TTS] Error:", e);
    return new Response(
      JSON.stringify({ error: "Internal error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
