## Context

Goodwizard already listens to Jido telemetry and converts those events into structured logs in `Goodwizard.Telemetry`. This provides useful debugging detail but does not provide aggregate operational visibility (metrics) or execution causality across operations (traces).

This change introduces an observability foundation in two phases only:

1. Metrics pipeline from existing telemetry events
2. OpenTelemetry tracing with OTLP export

## Goals / Non-Goals

**Goals:**

- Emit low-overhead runtime metrics for tool/react/agent-cmd execution
- Emit traces for the same flows with meaningful span attributes
- Keep instrumentation additive and non-breaking
- Wire instrumentation at application startup with environment-driven configuration

**Non-Goals:**

- Dashboard/alert authoring
- SLO policy decisions
- New business-domain telemetry event families unrelated to existing core execution

## Decisions

### 1. Build metrics from existing telemetry events

**Decision**: Reuse existing event streams (`[:jido, :ai, :tool, ...]`, `[:jido, :ai, :react, ...]`, `[:jido, :agent, :cmd, ...]`) instead of introducing duplicate app-specific events.

**Rationale**: Reusing current events minimizes instrumentation drift and keeps source-of-truth consistent.

### 2. Prefer histogram distributions for duration measurements

**Decision**: Track durations with histograms and track result counts with counters.

**Rationale**: Histograms support p50/p95/p99 reporting and are a better fit for latency monitoring than only averages.

### 3. Use OTLP exporter with runtime config

**Decision**: Configure OpenTelemetry exporter endpoint and service metadata through runtime config/environment variables.

**Rationale**: OTLP is vendor-neutral and supports local and hosted observability backends.

### 4. Guard cardinality in tags and span attributes

**Decision**: Keep labels/attributes to bounded values (status, event type, known names) and avoid unbounded user input.

**Rationale**: High-cardinality labels can degrade collector and backend performance.

## Risks / Trade-offs

- Added dependencies increase startup complexity.
- Misconfigured exporter may silently drop traces if not validated.
- Over-instrumentation can add overhead if cardinality or event volume is not controlled.

Mitigations:

- Keep initial instrumentation to core flows only.
- Provide safe defaults and explicit startup warnings for invalid exporter config.
- Add focused tests for metric/trace emission on representative paths.
