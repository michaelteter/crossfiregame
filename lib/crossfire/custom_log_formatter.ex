# defmodule Crossfire.CustomLoggerFormatter do
#   def format(level, message, timestamp, metadata) do
#     color =
#       case Keyword.get(metadata, :module) do
#         Crossfire.Core.GameManager.Server -> IO.ANSI.green()
#         _ -> IO.ANSI.reset()
#       end

#     # Debug output to the console
#     IO.puts(
#       "ASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFA Reached the custom formatter"
#     )

#     # This will print the metadata for inspection
#     # IO.inspect(metadata, label: "Metadata")

#     formatted_message = "#{color}#{message}#{IO.ANSI.reset()}"
#     # formatted_message = "#{message}"
#     # "#{timestamp} [#{level}] #{formatted_message}\n"
#   end
# end
