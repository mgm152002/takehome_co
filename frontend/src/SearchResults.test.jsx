import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import SearchResults from './SearchResults'

const rows = [
  {
    id: 1, year: 2020, make: 'Toyota', model: 'Camry', trim: 'SE', body: 'sedan',
    odometer: 35000, sellingPrice: 18500, state: 'ca', matchType: 'EXACT',
  },
  {
    id: 2, year: 2018, make: 'Honda', model: 'Accord', trim: null, body: 'sedan',
    odometer: null, sellingPrice: null, state: 'tx', matchType: 'FUZZY',
  },
]

const noop = () => {}

describe('SearchResults (DataGrid)', () => {
  it('renders a data grid with the result rows', () => {
    render(<SearchResults results={rows} mode="EXACT" onPageChange={noop} onSizeChange={noop} />)

    expect(screen.getByRole('grid', { name: 'vehicle search results' })).toBeInTheDocument()
    expect(screen.getByText('Camry')).toBeInTheDocument()
    expect(screen.getByText('Accord')).toBeInTheDocument()
  })

  it('exposes sortable, filterable column headers', () => {
    render(<SearchResults results={rows} mode="EXACT" onPageChange={noop} onSizeChange={noop} />)

    expect(screen.getAllByRole('columnheader', { name: 'Make' }).length).toBeGreaterThan(0)
    expect(screen.getAllByRole('columnheader', { name: 'Price' }).length).toBeGreaterThan(0)
  })

  it('formats price and mileage, showing a dash for nulls', () => {
    render(<SearchResults results={rows} mode="EXACT" onPageChange={noop} onSizeChange={noop} />)

    expect(screen.getAllByText('$18,500').length).toBeGreaterThan(0)
    expect(screen.getAllByText('35,000').length).toBeGreaterThan(0)
    expect(screen.getAllByText('—').length).toBeGreaterThan(0)
  })

  it('shows a fallback notice when mode is not EXACT', () => {
    render(<SearchResults results={rows} mode="SEMANTIC" onPageChange={noop} onSizeChange={noop} />)
    expect(screen.getByText(/no exact matches/i)).toBeInTheDocument()
  })

  it('shows the query time when elapsedMs is provided', () => {
    render(<SearchResults results={rows} mode="EXACT" elapsedMs={42.7} onPageChange={noop} onSizeChange={noop} />)
    expect(screen.getByText(/query time: 43 ms/i)).toBeInTheDocument()
  })

  it('shows an empty state when there are no results', () => {
    render(<SearchResults results={[]} />)
    expect(screen.getByText('No results to display.')).toBeInTheDocument()
  })
})
