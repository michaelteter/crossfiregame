cd ~/bin/livebook
ELIXIR_ERL_OPTIONS="-epmd_module Elixir.Livebook.EPMD" MIX_ENV=prod mix phx.server