# Phase 9: Web Tools and Subagents — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.Actions.Web.Search action (Brave Search API via Req, query + count params, formatted results)
- [ ] 1.2 Create Goodwizard.Actions.Web.Fetch action (HTTP fetch via Req, HTML-to-text stripping, truncation)
- [ ] 1.3 Create Goodwizard.SubAgent module (use Jido.AI.ReActAgent, limited tools, no spawn/messaging)
- [ ] 1.4 Create Goodwizard.Actions.Subagent.Spawn action (start SubAgent via Jido instance, emit completion signal to parent)
- [ ] 1.5 Create Goodwizard.Actions.Messaging.Send action (cross-channel message directive)
- [ ] 1.6 Register web, subagent, and messaging actions as additional tools on the main agent

## Test

- [ ] 2.1 Test Search: mock Brave API, verify query formatting and result parsing
- [ ] 2.2 Test Fetch: mock HTTP response, verify HTML stripping and content extraction
- [ ] 2.3 Test Spawn: verify subagent process starts and completes task
- [ ] 2.4 Test Send: verify directive emission with correct channel/chat_id/content
