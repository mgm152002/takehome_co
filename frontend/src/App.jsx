import { useCallback, useEffect, useRef, useState } from 'react'
import Container from '@mui/material/Container'
import Typography from '@mui/material/Typography'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import Stack from '@mui/material/Stack'
import Autocomplete from '@mui/material/Autocomplete'
import CircularProgress from '@mui/material/CircularProgress'

import SearchResults from './SearchResults'
import useSuggestions from './useSuggestions'
import PerformancePanel from './PerformancePanel'

const DEFAULT_SIZE = 100
const MAX_HISTORY = 15

export default function App() {
  const [query, setQuery] = useState('')       // committed search term
  const [inputValue, setInputValue] = useState('') // live input for suggestions
  const [page, setPage] = useState(0)
  const [size, setSize] = useState(DEFAULT_SIZE)
  const [response, setResponse] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [perfHistory, setPerfHistory] = useState([])

  // Client-side result cache (session lifetime), keyed by query|page|size and
  // scoped to the server's datasetVersion so an import invalidates everything.
  const cacheRef = useRef(new Map())
  const cacheVersionRef = useRef(null)
  // Tracks the latest in-flight request so a stale response can't overwrite a
  // newer one, and so a superseded request is aborted.
  const abortRef = useRef(null)

  const { suggestions, loading: suggestLoading } = useSuggestions(inputValue)

  const fetchSearch = useCallback(async (q, pageArg, sizeArg) => {
    const term = q.trim()
    if (!term) return
    const key = `${term.toLowerCase()}|${pageArg}|${sizeArg}`

    // Cache hit → serve instantly, no network, no spinner.
    const cached = cacheRef.current.get(key)
    if (cached) {
      setResponse(cached)
      setError(null)
      setLoading(false)
      return
    }

    // Cancel any previous in-flight search.
    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller

    setLoading(true)
    setError(null)
    const startedAt = performance.now()
    try {
      const res = await fetch(
        `/api/search?q=${encodeURIComponent(term)}&page=${pageArg}&size=${sizeArg}`,
        { signal: controller.signal },
      )
      if (!res.ok) throw new Error(`Search failed (${res.status})`)
      const body = await res.json()
      const clientMs = performance.now() - startedAt

      // Invalidate the whole client cache when the dataset version changes.
      if (cacheVersionRef.current !== null && cacheVersionRef.current !== body.datasetVersion) {
        cacheRef.current.clear()
      }
      cacheVersionRef.current = body.datasetVersion
      cacheRef.current.set(key, body)

      setResponse(body)
      setPerfHistory((prev) => {
        const sample = {
          label: `${term}${pageArg > 0 ? ` p${pageArg}` : ''}`,
          serverMs: body.elapsedMs ?? 0,
          clientMs,
          mode: body.mode,
          results: body.results?.length ?? 0,
        }
        return [...prev, sample].slice(-MAX_HISTORY)
      })
    } catch (err) {
      if (err.name === 'AbortError') return  // superseded; ignore
      setError(err.message)
      setResponse(null)
    } finally {
      setLoading(false)
    }
  }, [])

  // Refetch whenever the committed query, page, or size changes.
  useEffect(() => {
    if (query) fetchSearch(query, page, size)
  }, [query, page, size, fetchSearch])

  function submit(event) {
    event?.preventDefault()
    const term = inputValue.trim()
    if (!term) return
    setPage(0)          // new query starts at page 0
    setQuery(term)      // triggers the effect
  }

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        Vehicle Auction Search
      </Typography>

      <form onSubmit={submit}>
        <Stack direction="row" spacing={2}>
          <Autocomplete
            fullWidth
            freeSolo
            options={suggestions}
            getOptionLabel={(opt) => (typeof opt === 'string' ? opt : opt.term)}
            filterOptions={(x) => x}  // server already filtered; don't re-filter
            loading={suggestLoading}
            inputValue={inputValue}
            onInputChange={(_e, value) => setInputValue(value)}
            onChange={(_e, value) => {
              const term = typeof value === 'string' ? value : value?.term
              if (term) {
                setInputValue(term)
                setPage(0)
                setQuery(term)
              }
            }}
            renderInput={(params) => (
              <TextField
                {...params}
                size="small"
                label="Search vehicles"
                placeholder="e.g. Toyota Camry, family SUV"
              />
            )}
          />
          <Button type="submit" variant="contained" disabled={loading}>
            Search
          </Button>
        </Stack>
      </form>

      {loading && <CircularProgress size={24} sx={{ mt: 2 }} role="progressbar" />}

      {error && (
        <Typography role="alert" color="error" sx={{ mt: 2 }}>
          {error}
        </Typography>
      )}

      {response && !loading && (
        <>
          <Typography color="text.secondary" sx={{ mt: 2 }}>
            {response.results.length} result{response.results.length === 1 ? '' : 's'} on this page
            {response.elapsedMs != null && ` · ${Math.round(response.elapsedMs)} ms`}
          </Typography>
          <SearchResults
            results={response.results}
            mode={response.mode}
            page={response.page ?? page}
            size={response.size ?? size}
            hasNext={response.hasNext}
            elapsedMs={response.elapsedMs}
            onPageChange={setPage}
            onSizeChange={(nextSize) => { setSize(nextSize); setPage(0) }}
          />
        </>
      )}

      <PerformancePanel history={perfHistory} />
    </Container>
  )
}
