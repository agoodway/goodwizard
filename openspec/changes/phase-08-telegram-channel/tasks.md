# Phase 8: Telegram Channel — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.Channels.Telegram.Markdown — convert markdown to Telegram HTML (code blocks, inline code, bold, italic, headers, blockquotes, HTML escaping)
- [ ] 1.2 Create Goodwizard.Channels.Telegram.Sender — send_message/4 with HTML conversion, message splitting at 4096 chars, API error handling
- [ ] 1.3 Create Goodwizard.Channels.Telegram.Poller GenServer — init reads config/token, schedules first poll
- [ ] 1.4 Implement poll loop — call getUpdates via Req, process messages, update offset
- [ ] 1.5 Implement per-message handling — allow_from filtering, get-or-create AgentServer via Jido instance, ask_sync, send response
- [ ] 1.6 Wire Telegram auto-start in Application if channels.telegram.enabled is true

## Test

- [ ] 2.1 Test Markdown: conversion of all markdown elements to Telegram HTML
- [ ] 2.2 Test Sender: message splitting for long responses
- [ ] 2.3 Test Poller: mock HTTP calls, verify message processing flow
- [ ] 2.4 Test allow-list filtering (allowed user passes, blocked user rejected, empty list allows all)
