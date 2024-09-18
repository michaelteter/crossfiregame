# Crossfire

## Purpose

Crossfire is a simple 4-player game. The project was an exercise and opportunity for the author (me) to learn/improve Elixir, Phoenix LiveView, and BEAM skills. This game should not be considered finished, and expectations of its entertainment value should be kept low.

## License and Terms of Use

This code is provided as-is, with no warranty or support. The author may respond
to issues or comments, but don't count on that. :)

This project is licensed under the Apache License 2.0. See the [LICENSE](./LICENSE) file for details.

The following copyright notice should applies to all source and asset files within
this project.

> Copyright 2024 Michael Teter
>
> Licensed under the Apache License, Version 2.0 (the "License");
> you may not use this file except in compliance with the License.
> You may obtain a copy of the License at
>
>     http://www.apache.org/licenses/LICENSE-2.0
>
> Unless required by applicable law or agreed to in writing, software
> distributed under the License is distributed on an "AS IS" BASIS,
> WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
> See the License for the specific language governing permissions and
> limitations under the License.

## Game Rules

Four players are arranged around a board, and each player has the goal of shooting a block forward and having that block reach the opposite side of the board.

Blocks (shots) always travel toward the player on the opposite side of the board, and blocks that collide are removed from the board.

If a block reaches the opposite edge of the board, the player who fired the shot
gains a point. When any player reaches 15 points, the game ends.

## Strategy

The strategy is simple: fire a shot and hope it reaches the other side without colliding with other
players' shots. While simple, this is actually difficult because of the constant crossfire from
your two adjacent players.

## Techy Stuff

The backend is written in Elixir, using Phoenix and LiveView for the web interface.

The human gameplay interface is written in JavaScript.

This frontend was put together quickly and then significantly modified on the second iteration when I decided to reorient the game display for each player so they appeared to be at the bottom. This is probably the least clean code of the project.

Throughout the project (and especially at the beginning), I leveraged ChatGPT, Copilot, and a little ClaudeAI for help and examples at times -- particularly
when looking for language-idiomatic approaches to doing certain tasks which were new to me.

There may be some awkward ways of doing some things
because of my reliance on these helpers, but I attempted to match standards or idioms.

The prompt I use to get started with ChatGPT is in [docs/prompt.txt](docs/prompt.txt) . It is worth a read as it provides an overview of the architecture.

## Comments

This was my first time doing anything significant with GenServers and multiprocessing with Elixir. There are probably
some questionable approaches or novice mistakes.

Keeping up with data and returns was a big challenge, given that in some places the practices or expectations
of return values are simple atoms or values or are tuples of some atoms and/or values. Partly because
of this, there are many places where I have very explicitly matched a struct type in a return, hoping it would
help me stay on track and not corrupt states.

There are many different ways this game could have been implemented, and the current version is probably the
third significant iteration. It is likely still not ideal, but it works :).

I consider somewhat carefully before relying on pattern matching
in function signatures. While I see the appeal in many cases, I
think this is really overdone in some Elixir examples.

There are times when a case/cond clearly illustrates the possible
paths in a concise way, whereas overloaded functions of the same
name scatter the cases across an area too difficult to see at once.
They can also be position dependent in terms of their order of definition within a
module, and I dislike the additional fragility that brings.

One approach I use, especially in GenServer/LiveView info handling, is to switch on the message within the handle_info(),
and call out to specific functions. I follow a naming pattern on
the functions, such as info_message_a(), info_message_b(), etc.

Also, having uniquely named functions allows me to use IDE (vscode) outline and CMD-click to much more easily navigate.

## Building

Follow the usual [Phoenix Framework setup and build guides](https://hexdocs.pm/phoenix/overview.html).
