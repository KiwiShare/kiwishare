import { writeFile } from 'node:fs/promises';
import os from 'node:os';
import process from 'node:process';
import { performance } from 'node:perf_hooks';

const readPositiveInteger = (name, fallback) => {
  const value = Number.parseInt(process.env[name] ?? '', 10);
  if (!Number.isFinite(value) || value <= 0) return fallback;
  return value;
};

const readNonNegativeNumber = (name, fallback) => {
  const value = Number.parseFloat(process.env[name] ?? '');
  if (!Number.isFinite(value) || value < 0) return fallback;
  return value;
};

const baseUrl = (process.env.API_PERF_BASE_URL ?? 'http://127.0.0.1:3000').replace(/\/$/, '');
const requestCount = readPositiveInteger('API_PERF_REQUESTS', 80);
const concurrency = Math.min(readPositiveInteger('API_PERF_CONCURRENCY', 4), requestCount);
const warmupRequests = readPositiveInteger('API_PERF_WARMUP_REQUESTS', 8);
const timeoutMs = readPositiveInteger('API_PERF_TIMEOUT_MS', 10_000);
const maxP95Ms = readPositiveInteger('API_PERF_MAX_P95_MS', 1_500);
const maxErrorRate = readNonNegativeNumber('API_PERF_MAX_ERROR_RATE', 0.01);
const outputPath = process.env.API_PERF_OUTPUT;

const requestMix = [
  { name: 'health', path: '/health', weight: 10 },
  { name: 'listing', path: '/api/usedItems?limit=12', weight: 40 },
  { name: 'discovery-options', path: '/api/usedItems/discovery-options', weight: 30 },
  { name: 'categories', path: '/api/categories', weight: 20 }
];

const schedule = requestMix.flatMap((entry) =>
  Array.from({ length: entry.weight / 10 }, () => entry)
);

const percentile = (values, fraction) => {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1);
  return Number(sorted[index].toFixed(2));
};

const timedRequest = async (entry) => {
  const startedAt = performance.now();
  try {
    const response = await fetch(`${baseUrl}${entry.path}`, {
      headers: { accept: 'application/json', 'user-agent': 'kiwishare-api-performance-smoke/1.0' },
      signal: AbortSignal.timeout(timeoutMs)
    });
    await response.arrayBuffer();
    return {
      endpoint: entry.name,
      durationMs: performance.now() - startedAt,
      status: response.status,
      ok: response.status === 200
    };
  } catch (error) {
    return {
      endpoint: entry.name,
      durationMs: performance.now() - startedAt,
      status: null,
      ok: false,
      error: error instanceof Error ? error.message : String(error)
    };
  }
};

const runRequests = async (count, collectResults) => {
  const results = [];
  let nextIndex = 0;

  const worker = async () => {
    while (true) {
      const index = nextIndex;
      nextIndex += 1;
      if (index >= count) return;
      const result = await timedRequest(schedule[index % schedule.length]);
      if (collectResults) results.push(result);
    }
  };

  await Promise.all(Array.from({ length: Math.min(concurrency, count) }, () => worker()));
  return results;
};

const summarise = (results) => {
  if (results.length === 0) {
    return {
      requests: 0,
      successes: 0,
      failures: 0,
      errorRate: null,
      latencyMs: { min: null, p50: null, p95: null, p99: null, max: null }
    };
  }

  const durations = results.map((result) => result.durationMs);
  const failures = results.filter((result) => !result.ok);
  return {
    requests: results.length,
    successes: results.length - failures.length,
    failures: failures.length,
    errorRate: Number((failures.length / results.length).toFixed(4)),
    latencyMs: {
      min: Number(Math.min(...durations).toFixed(2)),
      p50: percentile(durations, 0.5),
      p95: percentile(durations, 0.95),
      p99: percentile(durations, 0.99),
      max: Number(Math.max(...durations).toFixed(2))
    }
  };
};

await runRequests(warmupRequests, false);

const startedAt = performance.now();
const results = await runRequests(requestCount, true);
const elapsedSeconds = (performance.now() - startedAt) / 1_000;
const overall = summarise(results);
const endpointResults = Object.fromEntries(
  requestMix.map((entry) => {
    const matching = results.filter((result) => result.endpoint === entry.name);
    return [entry.name, { path: entry.path, weight: entry.weight, ...summarise(matching) }];
  })
);

const thresholdChecks = {
  p95Latency: {
    actualMs: overall.latencyMs.p95,
    maximumMs: maxP95Ms,
    passed: overall.latencyMs.p95 !== null && overall.latencyMs.p95 <= maxP95Ms
  },
  errorRate: {
    actual: overall.errorRate,
    maximum: maxErrorRate,
    passed: overall.errorRate <= maxErrorRate
  }
};

const report = {
  schemaVersion: 1,
  measuredAt: new Date().toISOString(),
  target: baseUrl,
  environment: {
    node: process.version,
    platform: process.platform,
    architecture: process.arch,
    cpuModel: os.cpus()[0]?.model ?? 'unknown',
    logicalCpus: os.cpus().length
  },
  configuration: {
    requests: requestCount,
    concurrency,
    warmupRequests,
    timeoutMs,
    requestMix
  },
  thresholds: {
    maxP95Ms,
    maxErrorRate
  },
  result: {
    durationSeconds: Number(elapsedSeconds.toFixed(3)),
    throughputRequestsPerSecond: Number((requestCount / elapsedSeconds).toFixed(2)),
    overall,
    endpoints: endpointResults,
    failures: results.filter((result) => !result.ok).slice(0, 10)
  },
  checks: thresholdChecks,
  passed: Object.values(thresholdChecks).every((check) => check.passed)
};

const renderedReport = `${JSON.stringify(report, null, 2)}\n`;
process.stdout.write(renderedReport);
if (outputPath) await writeFile(outputPath, renderedReport, 'utf8');
if (!report.passed) process.exitCode = 1;
