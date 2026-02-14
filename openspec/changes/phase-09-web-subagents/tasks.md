# Phase 9: Browser Capabilities and Subagents — Tasks

## Backend

- [x] 1.1 Configure JidoBrowser.Plugin on agent — `plugins: [{JidoBrowser.Plugin, [headless: true]}]`
- [x] 1.2 Wire Goodwizard.Config browser settings into `:jido_browser` application config at startup
- [x] 1.3 Create Goodwizard.SubAgent module (use Jido.AI.ReActAgent, limited tools, no spawn/messaging/browser)
- [x] 1.3b Create Goodwizard.SubAgent.Character — focused identity ("background research and file processing agent"), constrained instructions (no user comms, no recursion), professional tone. SubAgent's on_before_cmd/2 uses this character with task context as knowledge
- [x] 1.4 Create Goodwizard.Actions.Subagent.Spawn action (start SubAgent via Jido instance, emit completion signal to parent)
- [x] 1.5 Create Goodwizard.Actions.Messaging.Send action (room_id + content schema, saves via Messaging API, delivers via JidoMessaging.Deliver)
- [x] 1.6 Register subagent and messaging actions as additional tools on the main agent; browser actions auto-registered by plugin

## Test

- [x] 2.1 Test JidoBrowser.Plugin mounts on agent and registers browser actions
- [x] 2.2 Test browser config wired from Goodwizard.Config to jido_browser application config
- [x] 2.3 Test Spawn: verify subagent process starts and completes task
- [x] 2.4 Test Send: verify message saved to room and delivery triggered with correct room_id/content
- [x] 2.5 Test SubAgent.Character — produces focused identity with constrained instructions, on_before_cmd/2 injects task context as knowledge
