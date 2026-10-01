import { renderHook, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import useSuggestions from './useSuggestions'

describe('useSuggestions', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('does not call the API below the minimum character count', async () => {
    const fetchSpy = vi.spyOn(global, 'fetch')
    renderHook(() => useSuggestions('t'))
    // Wait past the debounce window; still no call for a 1-char query.
    await new Promise((r) => setTimeout(r, 350))
    expect(fetchSpy).not.toHaveBeenCalled()
  })

  it('debounces then fetches suggestions', async () => {
    const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({ suggestions: [{ term: 'TOYOTA', termType: 'MAKE', score: 1 }] }),
    })

    const { result } = renderHook(() => useSuggestions('toy'))

    await waitFor(() => expect(fetchSpy).toHaveBeenCalledTimes(1), { timeout: 1000 })
    expect(fetchSpy.mock.calls[0][0]).toContain('/api/suggestions?q=toy')
    await waitFor(() => expect(result.current.suggestions).toHaveLength(1))
  })
})
