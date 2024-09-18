defmodule Crossfire.Core.Util do
  @moduledoc """
  Miscellaneous functions, including macros for logging.
  """

  require Logger

  @doc """
  Sometimes we need a unique number, particularly for tracking related events
  and messages.
  """
  def somenum, do: :erlang.unique_integer([:positive])

  def hms_ms do
    Calendar.strftime(DateTime.utc_now(), "%H:%M:%S.%f")
  end

  @doc """
  Log a message, prefixed with the current module and function name.
  """
  defmacro lfi(additional_info \\ "") do
    # NOTE: See Debug module to control which modules are logged.
    #   If the module using this macro is not explicitly allowed to log,
    #   you will see nothing...
    quote do
      if Crossfire.Core.Debug.should_log(__MODULE__) do
        require Logger
        module_name = to_string(__MODULE__)
        {function_name, arity} = __ENV__.function

        (Crossfire.Core.Util.hms_ms() <>
           " #{inspect(self())} #{module_name}.#{function_name}/#{arity} - " <>
           unquote(additional_info))
        |> Logger.info()
      end
    end
  end

  @doc """
  Given a value, find its corresponding key in a map.
  Return nil if not found.
  """
  def map_k_for_v(map, value, default \\ nil) do
    Enum.find_value(map, default, fn {k, v} -> if v == value, do: k end)
  end

  def guess_type(v) do
    cond do
      is_binary(v) -> :binary
      is_integer(v) -> :integer
      is_float(v) -> :float
      is_list(v) -> :list
      is_map(v) -> :map
      is_tuple(v) -> :tuple
      is_atom(v) -> :atom
      true -> :unknown
    end
  end

  def inspect_msg(msg) do
    cond do
      is_tuple(msg) && tuple_size(msg) == 3 && elem(msg, 0) == :event ->
        "{:event, #{inspect(elem(msg, 1))}}"

      is_tuple(msg) && tuple_size(msg) > 0 ->
        "{#{inspect(elem(msg, 0))}, ...}"

      is_binary(msg) ->
        "#{msg}"

      is_atom(msg) ->
        "#{inspect(msg)}"

      true ->
        "?other message?: inspect[#{inspect(msg)}]"
    end
  end

  # This may not be the best place for these position functions...
  @doc """
  Given a tuple of {row, column}, generate a single number representation of that position.
  """
  def to_position_key({r, c}), do: r * 100 + c

  @doc """
  Given a row and column, generate a single number representation of that position.
  """
  def to_position_key(r, c), do: r * 100 + c

  @doc """
  Given a single number representation of a position, return a tuple of {row, column}.
  """
  @spec from_position_key(integer) :: {integer, integer}
  def from_position_key(k), do: {div(k, 100), rem(k, 100)}

  # Web crawlers and bots usually have one of these in their user agent string.
  @bot_patterns ~w(facebookexternalhit Facebot Twitterbot LinkedInBot Slackbot-LinkExpanding
                   WhatsApp Discordbot SkypeUriPreview TelegramBot Google-HTTP-Java-Client Viber
                   Googlebot AdsBot-Google Mediapartners-Google Bingbot Slurp Baiduspider YandexBot
                   DuckDuckBot crawler spider bot Applebot)

  defp bot_user_agent_match?(user_agent) do
    Enum.any?(@bot_patterns, fn pattern ->
      String.contains?(user_agent, String.downcase(pattern))
    end)
  end

  @doc """
  Given a user agent string, attempt to determine if it is a crawler/web bot.
  """
  def bot_user_agent?(user_agent) do
    user_agent
    |> List.first()
    |> String.downcase()
    |> bot_user_agent_match?()
  end

  @doc """
  Given a list of tuples, return a list of lists.
  """
  def list_tuples_to_list_lists(list_tuples) do
    Enum.map(list_tuples, fn {a, b} -> [a, b] end)
  end
end
