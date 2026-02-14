## ADDED Requirements

### Requirement: Mix project with required dependencies
The project SHALL be a Mix project named `:goodwizard` with the following dependencies:
- `jido ~> 2.0.0-rc`
- `jido_ai ~> 0.5`
- `jido_browser ~> 0.8`
- `jido_messaging ~> 0.1`
- `telegex ~> 1.8`
- `finch ~> 0.18`
- `toml ~> 0.7`
- `jason ~> 1.4`

#### Scenario: Project compiles with all dependencies
- **WHEN** `mix deps.get && mix compile` is run
- **THEN** the project SHALL compile without errors

#### Scenario: Browser binary installed before first use
- **WHEN** `mix jido_browser.install` is run after `mix deps.get`
- **THEN** the platform-appropriate Vibium browser binary (~10MB) SHALL be downloaded and available for jido_browser actions

### Requirement: Application supervision tree
`Goodwizard.Application` SHALL start a supervision tree containing:
1. `Goodwizard.Config` — loaded first
2. `Goodwizard.Jido` — started after Config
3. `Goodwizard.Messaging` — started after Jido (replaces a future ChannelSupervisor)

The children SHALL start in the listed order to ensure config is available before Jido initializes, and Jido is available before Messaging starts its supervision tree.

#### Scenario: Application starts successfully
- **WHEN** the application is started via `Application.start(:goodwizard)`
- **THEN** `Goodwizard.Config`, `Goodwizard.Jido`, and `Goodwizard.Messaging` SHALL be running under the supervisor

#### Scenario: Config failure prevents Jido start
- **WHEN** `Goodwizard.Config` fails to start (e.g., crashes in init)
- **THEN** the supervisor SHALL not start `Goodwizard.Jido` or `Goodwizard.Messaging`

#### Scenario: Messaging starts with its full supervision tree
- **WHEN** `Goodwizard.Messaging` starts successfully
- **THEN** it SHALL provide room supervision, agent/instance supervisors, signal bus, and deduplication services via jido_messaging

### Requirement: Jido instance module
`Goodwizard.Jido` SHALL use `use Jido, otp_app: :goodwizard` to create a Jido instance module that manages agent lifecycle.

#### Scenario: Jido module is a valid Jido instance
- **WHEN** the application starts
- **THEN** `Goodwizard.Jido` SHALL be a running process that implements the Jido instance behaviour

### Requirement: Top-level module
`Goodwizard` (lib/goodwizard.ex) SHALL serve as the top-level module providing the public API entry point for the application.

#### Scenario: Module exists and compiles
- **WHEN** the project is compiled
- **THEN** the `Goodwizard` module SHALL be available with module documentation
