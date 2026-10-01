import { useEffect, useRef, useState } from 'react'

const DEBOUNCE_MS = 250
const MIN_CHARS = 2

/**
 * Debounced autocomplete suggestions from GET /api/suggestions.
 *
 * - Waits {@link DEBOUNCE_MS} after the last keystroke before calling the API.
 * - Cancels the in-flight request when the query changes (AbortController), so
 *   obsolete responses never overwrite newer ones.
 * - Caches results per normalized prefix for the browser session.
 *
 * @param {string} query current input text
 * @returns {{suggestions: Array, loading: boolean}}
 */
export default function useSuggestions(query) {
  const [suggestions, setSuggestions] = useState([])
  const [loading, setLoading] = useState(false)
  const cacheRef = useRef(new Map())

  useEffect(() => {
    const q = query.trim().toLowerCase()

    if (q.length < MIN_CHARS) {
      setSuggestions([])
      setLoading(false)
      return
    }

    if (cacheRef.current.has(q)) {
      setSuggestions(cacheRef.current.get(q))
      setLoading(false)
      return
    }

    const controller = new AbortController()
    const timer = setTimeout(async () => {
      setLoading(true)
      try {
        const res = await fetch(`/api/suggestions?q=${encodeURIComponent(q)}`, {
          signal: controller.signal,
        })
        if (!res.ok) throw new Error(`suggestions ${res.status}`)
        const body = await res.json()
        const items = body.suggestions ?? []
        cacheRef.current.set(q, items)
        setSuggestions(items)
      } catch (err) {
        if (err.name !== 'AbortError') {
          setSuggestions([])
        }
      } finally {
        setLoading(false)
      }
    }, DEBOUNCE_MS)

    return () => {
      clearTimeout(timer)
      controller.abort()
    }
  }, [query])

  return { suggestions, loading }
}
