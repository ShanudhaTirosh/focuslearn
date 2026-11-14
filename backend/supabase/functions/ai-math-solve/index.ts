import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { authenticateUser, getServiceRoleClient } from '../_shared/supabase.ts';

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
const GEMINI_MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-1.5-flash';

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const { user } = await authenticateUser(req);
    const body = await req.json();
    const {
      imageBase64,
      mimeType = 'image/jpeg',
      problemText,
      language = 'en',
      action = 'solve',
    } = body;

    if (!imageBase64 && !problemText) {
      return new Response(JSON.stringify({ error: 'Missing image or problem text' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // 1. Quota check: max 20 AI camera solves per user per day on free tier
    const today = new Date().toISOString().split('T')[0];
    const { data: usageCount } = await adminClient
      .from('rate_limit_events')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('action', 'ai_camera_solve')
      .gte('created_at', `${today}T00:00:00Z`);

    const dailyUsage = usageCount ?? 0;
    const DAILY_LIMIT = 20;

    if (dailyUsage >= DAILY_LIMIT) {
      return new Response(
        JSON.stringify({
          error: 'Daily AI problem solving quota reached (20/20 questions). Use the offline scientific calculator.',
          quotaExceeded: true,
        }),
        {
          status: 429,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({
          error: 'Gemini API key is not configured on server. Please check environment variables.',
        }),
        {
          status: 503,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // 2. Call Google AI Studio Gemini API
    const systemPrompt = `You are Focus Learn AI Math & Science Solver.
Solve the academic problem accurately for G.C.E. Advanced Level mathematics, physics, or chemistry.
Language requested: ${language}.
Action: ${action} (solve = full solution, explain_differently = conceptual intuitive explanation, practice_question = generate a similar practice question with answer).

You MUST reply with ONLY a raw JSON object (no markdown code blocks, no backticks, no extra text) with this exact schema:
{
  "problemTitle": "Short topic title",
  "problemUnderstood": "Transcribed question text in clear markdown/LaTeX",
  "canonicalExpression": "Pure mathematical expression or equation to calculate answer deterministically (e.g. '1/2 * 9.8 * 4^2' or 'x^2 - 5x + 6 = 0')",
  "steps": ["Step 1: ...", "Step 2: ..."],
  "finalAnswer": "Final answer with units (e.g. '78.4 m')",
  "formulaUsed": "Equation name or formula",
  "explanation": "Clear explanation of theory and method"
}`;

    const parts: any[] = [{ text: systemPrompt }];

    if (problemText) {
      parts.push({ text: `Student's Question:\n${problemText}` });
    }

    if (imageBase64) {
      parts.push({
        inline_data: {
          mime_type: mimeType,
          data: imageBase64,
        },
      });
    }

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

    const geminiRes = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          temperature: 0.1, // Low temperature for high precision
          maxOutputTokens: 1024,
        },
      }),
    });

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      return new Response(
        JSON.stringify({ error: `Gemini API error: ${geminiRes.status}`, details: errText }),
        {
          status: 502,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const geminiData = await geminiRes.json();
    const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? '{}';

    // Clean JSON response (strip markdown fences if present)
    const jsonString = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
    let solutionObj;
    try {
      solutionObj = JSON.parse(jsonString);
    } catch (_) {
      solutionObj = {
        problemTitle: 'Science / Math Problem',
        problemUnderstood: problemText ?? 'Scanned problem',
        canonicalExpression: '',
        steps: [rawText],
        finalAnswer: 'See step-by-step working above',
        formulaUsed: '',
        explanation: 'Completed by AI tutor',
      };
    }

    // 3. Record rate limit event
    await adminClient.from('rate_limit_events').insert({
      user_id: user.id,
      action: 'ai_camera_solve',
    });

    return new Response(
      JSON.stringify({
        solution: solutionObj,
        dailyRemaining: DAILY_LIMIT - (dailyUsage + 1),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message ?? 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
