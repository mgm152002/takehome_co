import { BarChart } from '@mui/x-charts/BarChart'
import Paper from '@mui/material/Paper'
import Typography from '@mui/material/Typography'
import Box from '@mui/material/Box'
import Stack from '@mui/material/Stack'
import Chip from '@mui/material/Chip'

const MODE_COLORS = {
  EXACT: 'success',
  FUZZY: 'warning',
  SEMANTIC: 'info',
}

function percentile(values, p) {
  if (!values.length) return 0
  const sorted = [...values].sort((a, b) => a - b)
  const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)
  return sorted[Math.max(0, idx)]
}

/**
 * Session latency chart. Each search appends a sample; this shows how the query
 * is performing over time — server query time (elapsedMs from the API) vs the
 * full client round-trip — plus summary stats and the match-mode of each query.
 *
 * @param {object} props
 * @param {Array<{label:string, serverMs:number, clientMs:number, mode:string, results:number}>} props.history
 */
export default function PerformancePanel({ history = [] }) {
  if (!history.length) return null

  const labels = history.map((h) => h.label)
  const serverSeries = history.map((h) => Math.round(h.serverMs ?? 0))
  const clientSeries = history.map((h) => Math.round(h.clientMs ?? 0))

  const serverValues = history.map((h) => h.serverMs ?? 0)
  const last = history[history.length - 1]
  const avg = Math.round(serverValues.reduce((a, b) => a + b, 0) / serverValues.length)
  const p95 = Math.round(percentile(serverValues, 95))
  const max = Math.round(Math.max(...serverValues))

  return (
    <Paper variant="outlined" sx={{ mt: 3, p: 2 }}>
      <Typography variant="h6" gutterBottom>
        Query performance
      </Typography>

      <Stack direction="row" spacing={1} useFlexGap sx={{ flexWrap: 'wrap', mb: 1 }}>
        <Chip size="small" label={`last: ${Math.round(last.serverMs)} ms`} />
        <Chip size="small" label={`avg: ${avg} ms`} />
        <Chip size="small" label={`p95: ${p95} ms`} />
        <Chip size="small" label={`max: ${max} ms`} />
        <Chip size="small" label={`queries: ${history.length}`} />
        {last.mode && (
          <Chip size="small" color={MODE_COLORS[last.mode] ?? 'default'} label={`mode: ${last.mode}`} variant="outlined" />
        )}
      </Stack>

      <Box sx={{ width: '100%', height: 260 }}>
        <BarChart
          xAxis={[{ scaleType: 'band', data: labels, label: 'query' }]}
          yAxis={[{ label: 'latency (ms)' }]}
          series={[
            { data: serverSeries, label: 'server query', color: '#1976d2' },
            { data: clientSeries, label: 'client round-trip', color: '#9c27b0' },
          ]}
          height={260}
          margin={{ left: 60, right: 10, top: 20, bottom: 50 }}
        />
      </Box>

      <Typography variant="caption" color="text.secondary">
        Server query = time reported by the API (SQL execution). Client round-trip = full fetch
        time measured in the browser (includes network + JSON parsing).
      </Typography>
    </Paper>
  )
}
