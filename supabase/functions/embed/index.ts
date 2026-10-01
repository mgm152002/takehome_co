import 'jsr:@supabase/functions-js/edge-runtime.d.ts'

const model = new Supabase.ai.Session('gte-small')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
}

type EmbeddingInput = {
  id?: number
  input: string
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return Response.json(
      { error: 'POST is required' },
      { status: 405, headers: corsHeaders },
    )
  }

  try {
    const body = await request.json()
    const items: EmbeddingInput[] = body.input
      ? [{ input: body.input }]
      : body.inputs

    if (!Array.isArray(items) || items.length === 0 || items.length > 25) {
      return Response.json(
        { error: 'Provide input or 1-25 inputs' },
        { status: 400, headers: corsHeaders },
      )
    }

    const embeddings = []
    for (const item of items) {
      if (typeof item.input !== 'string' || item.input.trim().length === 0) {
        return Response.json(
          { error: 'Each input must be a non-empty string' },
          { status: 400, headers: corsHeaders },
        )
      }

      const embedding = await model.run(item.input, {
        mean_pool: true,
        normalize: true,
      })

      if (!Array.isArray(embedding) || embedding.length !== 384) {
        throw new Error('gte-small returned an invalid embedding')
      }

      embeddings.push({ id: item.id, embedding })
    }

    if (body.input) {
      return Response.json(
        { embedding: embeddings[0].embedding },
        { headers: corsHeaders },
      )
    }

    return Response.json({ embeddings }, { headers: corsHeaders })
  } catch (error) {
    console.error(error)
    return Response.json(
      { error: 'Embedding generation failed' },
      { status: 500, headers: corsHeaders },
    )
  }
})
