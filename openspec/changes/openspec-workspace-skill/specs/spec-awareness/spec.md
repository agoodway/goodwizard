## ADDED Requirements

### Requirement: System prompt injection
The system SHALL inject a summary of available OpenSpec projects and their capabilities into the agent's system prompt at startup.

#### Scenario: Projects with specs exist
- **WHEN** the agent starts and the plugin index contains projects with specs
- **THEN** the system prompt includes an "OpenSpec Projects" section listing each project, its capabilities, and requirement counts

#### Scenario: No specs exist
- **WHEN** the agent starts and the plugin index is empty
- **THEN** no OpenSpec section is added to the system prompt

### Requirement: Prompt skill documentation
The system SHALL include an `openspec` prompt skill in the workspace that documents how the agent should use OpenSpec concepts.

#### Scenario: Skill activation
- **WHEN** the agent activates the `openspec` skill
- **THEN** it loads documentation explaining OpenSpec concepts (specs, changes, requirements, scenarios, delta operations) and available actions

#### Scenario: Skill discovery
- **WHEN** the agent lists available skills at startup
- **THEN** the `openspec` skill appears in the skill summary with a description of its purpose

### Requirement: Contextual spec awareness
The system SHALL enable the agent to consult relevant specs when reasoning about project behavior or requirements.

#### Scenario: User asks about current behavior
- **WHEN** a user asks "how does authentication work in project X?" and project X has an `auth` spec
- **THEN** the agent knows to read the auth spec via the `read_spec` action to ground its answer

#### Scenario: User references a change
- **WHEN** a user mentions an active change by name
- **THEN** the agent can read the change's artifacts to understand what is being proposed or implemented
