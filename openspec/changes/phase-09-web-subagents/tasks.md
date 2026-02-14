# Phase 9: Browser Capabilities and Subagents — Tasks

## Backend

- [ ] 1.1 Configure JidoBrowser.Plugin on agent — `plugins: [{JidoBrowser.Plugin, [headless: true]}]`
- [ ] 1.2 Wire Goodwizard.Config browser settings into `:jido_browser` application config at startup
- [ ] 1.3 Create Goodwizard.SubAgent module (use Jido.AI.ReActAgent, limited tools, no spawn/messaging/browser)
- [ ] 1.3b Create Goodwizard.SubAgent.Character — focused identity ("background research and file processing agent"), constrained instructions (no user comms, no recursion), professional tone. SubAgent's on_before_cmd/2 uses this character with task context as knowledge
- [ ] 1.4 Create Goodwizard.Actions.Subagent.Spawn action (start SubAgent via Jido instance, emit completion signal to parent)
- [ ] 1.5 Create Goodwizard.Actions.Messaging.Send action (room_id + content schema, saves via Messaging API, delivers via JidoMessaging.Deliver)
- [ ] 1.6 Register subagent and messaging actions as additional tools on the main agent; browser actions auto-registered by plugin

## Test

- [ ] 2.1 Test JidoBrowser.Plugin mounts on agent and registers browser actions
- [ ] 2.2 Test browser config wired from Goodwizard.Config to jido_browser application config
- [ ] 2.3 Test Spawn: verify subagent process starts and completes task
- [ ] 2.4 Test Send: verify message saved to room and delivery triggered with correct room_id/content
- [ ] 2.5 Test SubAgent.Character — produces focused identity with constrained instructions, on_before_cmd/2 injects task context as knowledge
