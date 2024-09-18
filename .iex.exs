IEx.configure inspect: [charlists: false] # prevent [7, 8, 9] from being printed as ~c"a\b\t"

alias Crossfire.Core.Debug
alias Crossfire.Core.{AlphaIdServer, Const, GameMetadata, Game, Types, Util}
alias Crossfire.Core.PubSub, as: Comm
alias Crossfire.Core.Game.Block
alias Crossfire.Core.Game.State, as: GameState
alias Crossfire.Core.GameManager.Api
alias Crossfire.Core.GameManager.Server
alias Crossfire.Core.GameManager.State, as: GMState
alias Crossfire.Core.Lobby.Api
alias Crossfire.Core.Lobby.Server
alias Crossfire.Core.Lobby.State, as: LobbyState

IO.inspect("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
IO.inspect("%%% Remember to look at Debug for tools %%%")
IO.inspect("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
