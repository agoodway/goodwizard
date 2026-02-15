defmodule Goodwizard.Cache do
  @moduledoc "Nebulex local ETS cache for hot-path reads."

  use Nebulex.Cache,
    otp_app: :goodwizard,
    adapter: Nebulex.Adapters.Local
end
