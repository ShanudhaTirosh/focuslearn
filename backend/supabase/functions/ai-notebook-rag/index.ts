import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { authenticateUser, getServiceRoleClient } from '../_shared/supabase.ts';

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
const GEMINI_MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-1.5-flash';
const GEMINI_EMBED_MODEL = 'text-embedding-004';

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
    const { action, notebookId } = body;

    if (!notebookId || !action) {
      return new Response(JSON.stringify({ error: 'Missing notebookId or action' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // Verify user has read access
    const { data: canRead } = await adminClient.rpc('can_read_notebook', {
      p_notebook_id: notebookId,
      p_user_id: user.id,
    });

    if (canRead === false) {
      return new Response(JSON.stringify({ error: 'Access denied to notebook' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Rate limiting: 30 notebook queries/actions per user per day on free tier
    const today = new Date().toISOString().split('T')[0];
    const { count: dailyUsage } = await adminClient
      .from('rate_limit_events')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('action', 'ai_notebook_query')
      .gte('created_at', `${today}T00:00:00Z`);

    const DAILY_NOTEBOOK_LIMIT = 30;
    if ((dailyUsage ?? 0) >= DAILY_NOTEBOOK_LIMIT) {
      return new Response(
        JSON.stringify({
          error: 'Daily notebook query quota reached (30/30). Please continue studying your sources directly.',
          quotaExceeded: true,
        }),
        {
          status: 429,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // --- Action 1: Index source text into chunks and pgvector embeddings
    if (action === 'index_source') {
      const { sourceId, text, title = 'Document' } = body;
      if (!sourceId || !text) {
        return new Response(JSON.stringify({ error: 'Missing sourceId or text' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Chunk text into ~350 word pieces with 50-word overlap
      const words = text.split(/\s+/);
      const chunkSize = 350;
      const overlap = 50;
      const chunks: string[] = [];

      for (let i = 0; i < words.length; i += (chunkSize - overlap)) {
        const slice = words.slice(i, i + chunkSize);
        if (slice.length > 0) {
          chunks.push(slice.join(' '));
        }
        if (i + chunkSize >= words.length) break;
      }

      // Batch generate embeddings
      for (let idx = 0; idx < chunks.length; idx++) {
        const chunkContent = chunks[idx];
        const pageEst = Math.floor(idx / 2) + 1;

        let embedding: number[] | null = null;
        if (GEMINI_API_KEY) {
          try {
            const embedRes = await fetch(
              `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_EMBED_MODEL}:embedContent?key=${GEMINI_API_KEY}`,
              {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                  model: `models/${GEMINI_EMBED_MODEL}`,
                  content: { parts: [{ text: chunkContent }] },
                  outputDimensionality: 768, // Matryoshka dimension reduction
                }),
              }
            );
            if (embedRes.ok) {
              const embedData = await embedRes.json();
              embedding = embedData.embedding?.values ?? null;
            }
          } catch (_) {
            // Keep going without embedding
          }
        }

        await adminClient.from('document_chunks').insert({
          notebook_id: notebookId,
          source_id: sourceId,
          chunk_index: idx,
          page_number: pageEst,
          content: chunkContent,
          embedding: embedding ? JSON.stringify(embedding) : null,
          metadata: { title },
        });
      }

      await adminClient
        .from('notebook_sources')
        .update({ status: 'ready', char_count: text.length })
        .eq('id', sourceId);

      return new Response(JSON.stringify({ success: true, chunksCount: chunks.length }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // --- Action 2: Grounded Q&A Chat with exact citations
    if (action === 'grounded_chat') {
      const { query } = body;
      if (!query) {
        return new Response(JSON.stringify({ error: 'Missing query' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // 1. Embed query
      let queryEmbedding: number[] | null = null;
      if (GEMINI_API_KEY) {
        const qEmbedRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_EMBED_MODEL}:embedContent?key=${GEMINI_API_KEY}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              model: `models/${GEMINI_EMBED_MODEL}`,
              content: { parts: [{ text: query }] },
              outputDimensionality: 768,
            }),
          }
        );
        if (qEmbedRes.ok) {
          const qData = await qEmbedRes.json();
          queryEmbedding = qData.embedding?.values ?? null;
        }
      }

      // 2. Vector search matching chunks
      let matchedChunks: any[] = [];
      if (queryEmbedding) {
        const { data: matches } = await adminClient.rpc('match_document_chunks', {
          p_notebook_id: notebookId,
          p_embedding: JSON.stringify(queryEmbedding),
          p_match_count: 5,
          p_match_threshold: 0.55,
        });
        matchedChunks = matches ?? [];
      }

      // Fallback: if no vector matches or no vector query, grab top chunks from notebook
      if (matchedChunks.length === 0) {
        const { data: fallbackChunks } = await adminClient
          .from('document_chunks')
          .select('id, source_id, page_number, content, notebook_sources(title)')
          .eq('notebook_id', notebookId)
          .limit(4);

        matchedChunks = (fallbackChunks ?? []).map((c: any) => ({
          id: c.id,
          source_id: c.source_id,
          source_title: c.notebook_sources?.title ?? 'Notes',
          page_number: c.page_number,
          content: c.content,
          similarity: 0.5,
        }));
      }

      if (matchedChunks.length === 0) {
        return new Response(
          JSON.stringify({
            answer:
              'No source documents found in this notebook yet. Please add a note, PDF or past paper first to enable grounded research answers.',
            citations: [],
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // 3. Grounded Prompt
      const excerptsText = matchedChunks
        .map(
          (m, i) =>
            `[Excerpt ${i + 1}] Source: "${m.source_title}", Page: ${m.page_number}\n${m.content}`
        )
        .join('\n\n');

      const systemPrompt = `You are Focus Learn Academic Research Assistant.
Answer the student's question STRICTLY and SOLELY based on the provided source excerpts below.
If the information cannot be verified directly from these excerpts, reply honestly:
"This topic is not covered in your uploaded notebook sources."
For every claim or fact you state, include an inline citation tag: [Source: <Title>, p. <Page>].
Never hallucinate or bring in ungrounded outside facts.

SOURCE EXCERPTS:
${excerptsText}

STUDENT QUESTION:
${query}`;

      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
      const genRes = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: systemPrompt }] }],
          generationConfig: { temperature: 0.2, maxOutputTokens: 800 },
        }),
      });

      const genData = await genRes.json();
      const answer = genData.candidates?.[0]?.content?.parts?.[0]?.text ?? 'No answer generated.';

      // Extract citation metadata
      const citations = matchedChunks.map((m) => ({
        sourceTitle: m.source_title,
        pageNumber: m.page_number,
        snippet: m.content.substring(0, 150) + '...',
      }));

      // Record rate limit event
      await adminClient.from('rate_limit_events').insert({
        user_id: user.id,
        action: 'ai_notebook_query',
      });

      return new Response(
        JSON.stringify({
          answer,
          citations,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // --- Action 3: Generate Study Artifact (guide, flashcards, quiz, audio overview)
    if (action === 'generate_artifact') {
      const { artifactType } = body;
      if (!artifactType) {
        return new Response(JSON.stringify({ error: 'Missing artifactType' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Fetch sample source chunks
      const { data: chunks } = await adminClient
        .from('document_chunks')
        .select('content')
        .eq('notebook_id', notebookId)
        .limit(8);

      const sourceContext = (chunks ?? []).map((c: any) => c.content).join('\n\n');

      let artifactPrompt = '';
      if (artifactType === 'flashcards') {
        artifactPrompt = `Generate 10 active-recall flashcards based on these study sources.
Return raw JSON array: [{"question": "...", "answer": "..."}]`;
      } else if (artifactType === 'quiz') {
        artifactPrompt = `Generate a 5-question multiple choice quiz with explanations based on these study sources.
Return raw JSON array: [{"question": "...", "options": ["A", "B", "C", "D"], "correctIndex": 0, "explanation": "..."}]`;
      } else if (artifactType === 'audio_overview') {
        artifactPrompt = `Write a lively 2-host podcast dialogue script ("Host 1" and "Host 2") summarizing the key insights from these study sources simply and engagingly.
Return raw JSON array: [{"speaker": "Host 1", "text": "..."}, {"speaker": "Host 2", "text": "..."}]`;
      } else {
        artifactPrompt = `Synthesize a comprehensive Study Guide from these study sources: key concepts, summary, vocabulary terms, and core formulas. Return Markdown text.`;
      }

      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
      const genRes = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: `Study Material:\n${sourceContext}\n\nTask: ${artifactPrompt}\nReply with valid JSON where requested, otherwise clean markdown.`,
                },
              ],
            },
          ],
        }),
      });

      const genData = await genRes.json();
      const rawText = genData.candidates?.[0]?.content?.parts?.[0]?.text ?? '{}';
      const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim();

      let parsedData;
      try {
        parsedData = JSON.parse(cleanJson);
      } catch (_) {
        parsedData = { text: rawText };
      }

      // Save artifact
      const { data: savedArtifact } = await adminClient
        .from('study_artifacts')
        .insert({
          notebook_id: notebookId,
          artifact_type: artifactType,
          title: `${artifactType.toUpperCase()} - ${new Date().toLocaleDateString()}`,
          data: parsedData,
        })
        .select()
        .single();

      return new Response(JSON.stringify({ artifact: savedArtifact }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ error: `Unsupported action: ${action}` }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message ?? 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
