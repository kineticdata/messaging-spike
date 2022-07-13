FROM elixir:latest

RUN mkdir /app
COPY . /app
WORKDIR /app
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix do deps.get, deps.compile, compile

ENTRYPOINT [ "mix", "phx.server" ]