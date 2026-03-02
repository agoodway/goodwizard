# Telemetry Observability Foundation (Phases 1-2)

## Why

Goodwizard currently captures rich `:telemetry` events and writes structured logs, but it does not publish operational metrics or distributed traces. This leaves observability partial: we can read logs after the fact, but we cannot reliably monitor latency/error trends or follow request/tool execution across components.

This change implements only the first two observability phases:

1. Metrics pipeline (counters/histograms)
2. Trace pipeline (OpenTelemetry spans + OTLP export)

## What

### Phase 1: Metrics Pipeline

- Add metrics definitions for core runtime signals:
  - Tool calls: total, success/error, duration
  - ReAct runs: total, termination_reason, duration, iteration counts
  - Agent command lifecycle: total, errors, duration
- Add a metrics reporter under the application supervision tree.
- Emit metrics from existing telemetry events (no behavior change to business logic).

### Phase 2: Traces Pipeline

- Add OpenTelemetry tracing dependencies and runtime configuration.
- Create spans for core execution flow:
  - ReAct lifecycle span
  - Tool execution span
  - Agent command span
- Attach stable attributes (for example: tool name, status, duration, call/thread IDs where available) with low-cardinality defaults.
- Export traces via OTLP to an operator-configured endpoint.

## Scope

In scope:

- Metrics and tracing instrumentation plumbing
- Application startup wiring for reporter/exporter
- Config keys and documentation for local/production setup
- Tests validating event-to-metric and event-to-span behavior on key happy/error paths

Out of scope (explicitly deferred):

- Dashboards, alerts, and SLO definitions (Phase 3)
- Coverage hardening/playbooks and extended integration suites (Phase 4)
- Persistent metrics storage or vendor-specific dashboard assets

## Dependencies

- Existing telemetry events in `Goodwizard.Telemetry` and Jido event streams
- No functional dependency on unrelated product features

## Success Criteria

- Metrics are emitted for tool/react/agent-cmd execution with useful labels and latency distributions.
- Traces are emitted for the same execution paths and are exportable via OTLP.
- Existing behavior and logs remain intact; instrumentation is additive.
