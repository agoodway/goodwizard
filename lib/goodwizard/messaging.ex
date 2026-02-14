defmodule Goodwizard.Messaging do
  @moduledoc """
  Messaging infrastructure for Goodwizard.

  Provides rooms, participants, messages, signal bus, deduplication,
  and channel supervision via JidoMessaging with ETS adapter.
  """
  use JidoMessaging, adapter: JidoMessaging.Adapters.ETS
end
