import { DataGrid } from '@mui/x-data-grid'
import Typography from '@mui/material/Typography'
import Box from '@mui/material/Box'
import { memo } from 'react'

// Server ranks at most the top 500 results (see design spec).
const MAX_RANKED = 500

const priceFormatter = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0,
})
const numberFormatter = new Intl.NumberFormat('en-US')

const columns = [
  {
    field: 'year',
    headerName: 'Year',
    type: 'number',
    width: 80,
    // Render as a plain 4-digit year (no thousands separator) while keeping
    // numeric sorting/filtering.
    valueFormatter: (value) => (value == null ? '—' : String(value)),
  },
  { field: 'make', headerName: 'Make', flex: 1, minWidth: 110 },
  { field: 'model', headerName: 'Model', flex: 1, minWidth: 120 },
  {
    field: 'trim',
    headerName: 'Trim',
    flex: 1,
    minWidth: 110,
    valueFormatter: (value) => value ?? '—',
  },
  {
    field: 'body',
    headerName: 'Body',
    flex: 1,
    minWidth: 100,
    valueFormatter: (value) => value ?? '—',
  },
  {
    field: 'odometer',
    headerName: 'Mileage',
    type: 'number',
    width: 110,
    valueFormatter: (value) => (value == null ? '—' : numberFormatter.format(value)),
  },
  {
    field: 'sellingPrice',
    headerName: 'Price',
    type: 'number',
    width: 110,
    valueFormatter: (value) => (value == null ? '—' : priceFormatter.format(value)),
  },
  { field: 'state', headerName: 'State', width: 90 },
]

/**
 * MUI X DataGrid for vehicle search results, with built-in per-column sorting
 * and filtering (community/MIT features). Rows are the current server page;
 * page/size changes are reported to the parent, which refetches.
 *
 * @param {object}   props
 * @param {Array}    props.results   listing rows for the current page
 * @param {string}   [props.mode]    match mode (EXACT | FUZZY | SEMANTIC)
 * @param {number}   props.page      current 0-based page
 * @param {number}   props.size      page size
 * @param {boolean}  props.hasNext   whether a next page exists
 * @param {number}   [props.elapsedMs] query time reported by the server
 * @param {Function} props.onPageChange (nextPage) => void
 * @param {Function} props.onSizeChange (nextSize) => void
 */
function SearchResults({
  results = [],
  mode,
  page = 0,
  size = 100,
  hasNext = false,
  elapsedMs,
  onPageChange,
  onSizeChange,
}) {
  if (!results.length) {
    return (
      <Typography role="status" color="text.secondary" sx={{ mt: 2 }}>
        No results to display.
      </Typography>
    )
  }

  // Lower-bound total for server pagination: rows seen so far, +1 while the
  // server reports another page, capped at the top-500 ranking limit.
  const seen = page * size + results.length
  const rowCount = Math.min(hasNext ? seen + 1 : seen, MAX_RANKED)

  return (
    <Box sx={{ mt: 2 }}>
      {mode && mode !== 'EXACT' && (
        <Typography role="status" color="text.secondary" sx={{ mb: 1 }}>
          No exact matches — showing {mode.toLowerCase()} results.
        </Typography>
      )}
      <Box sx={{ height: 560, width: '100%' }}>
        <DataGrid
          rows={results}
          columns={columns}
          aria-label="vehicle search results"
          getRowId={(row) => row.id}
          density="compact"
          paginationMode="server"
          rowCount={rowCount}
          pageSizeOptions={[25, 50, 100]}
          paginationModel={{ page, pageSize: size }}
          onPaginationModelChange={(model) => {
            if (model.pageSize !== size) {
              onSizeChange?.(model.pageSize)
            } else if (model.page !== page) {
              onPageChange?.(model.page)
            }
          }}
          disableRowSelectionOnClick
        />
      </Box>
      {elapsedMs != null && (
        <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
          Query time: {Math.round(elapsedMs)} ms
        </Typography>
      )}
    </Box>
  )
}

// Memoized: the grid re-renders only when its own props change, not on every
// parent state update (perf-history samples, suggestion input keystrokes).
export default memo(SearchResults)
