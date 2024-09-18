defmodule CrossfireWeb.Plugs.BadActorRedirect do
  import Plug.Conn

  def init(default), do: default

  # Anyone trying to access wp-includes can F-off.
  @send_to "https://www.cisa.gov/report"

  def call(%Plug.Conn{request_path: request_path} = conn, _opts) do
    if String.contains?(request_path, "/wp-includes") do
      conn
      |> put_resp_header("location", @send_to)
      |> send_resp(301, "")
      |> halt()
    else
      conn
    end
  end
end
