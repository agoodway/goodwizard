# Telemetry Observability Foundation (Phases 1-2) — Tasks

## Backend

- [ ] 1.1 Add metrics dependencies and reporter wiring under `Goodwizard.Application`
- [ ] 1.2 Define telemetry metrics for tool/react/agent-cmd totals and durations
- [ ] 1.3 Add runtime config for metrics reporter behavior (enable/disable, endpoint/port as applicable)
- [ ] 1.4 Add OpenTelemetry dependencies and base runtime config (service name/version/environment)
- [ ] 1.5 Create trace handlers/spans for ReAct lifecycle from existing telemetry events
- [ ] 1.6 Create trace handlers/spans for tool execution lifecycle from existing telemetry events
- [ ] 1.7 Create trace handlers/spans for agent command lifecycle from existing telemetry events
- [ ] 1.8 Add OTLP exporter configuration and startup validation/logging for misconfiguration
- [ ] 1.9 Update docs/config examples for local and production observability setup

## Test

- [ ] 2.1 Test metrics increment and duration recording for tool success/error paths
- [ ] 2.2 Test metrics recording for ReAct completion paths (`final_answer`, `max_iterations`, `error`)
- [ ] 2.3 Test metrics recording for agent command start/stop/exception paths
- [ ] 2.4 Test span creation for a representative tool call path (attributes + status)
- [ ] 2.5 Test span creation for a representative ReAct path (duration + termination metadata)
- [ ] 2.6 Test instrumentation startup wiring is attached exactly once
