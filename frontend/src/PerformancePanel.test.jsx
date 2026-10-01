import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import PerformancePanel from './PerformancePanel'

const history = [
  { label: 'toyota', serverMs: 40, clientMs: 90, mode: 'EXACT', results: 100 },
  { label: 'family suv', serverMs: 120, clientMs: 200, mode: 'SEMANTIC', results: 20 },
]

describe('PerformancePanel', () => {
  it('renders nothing when there is no history', () => {
    const { container } = render(<PerformancePanel history={[]} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('shows the performance heading and summary stats', () => {
    render(<PerformancePanel history={history} />)
    expect(screen.getByText('Query performance')).toBeInTheDocument()
    expect(screen.getByText(/last: 120 ms/)).toBeInTheDocument()
    expect(screen.getByText(/avg: 80 ms/)).toBeInTheDocument()
    expect(screen.getByText(/queries: 2/)).toBeInTheDocument()
    expect(screen.getByText(/mode: SEMANTIC/)).toBeInTheDocument()
  })
})
