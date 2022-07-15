FROM elixir:latest

RUN mkdir /app
COPY . /app
WORKDIR /app

ENV MIX_ENV="prod"
ENV SECRET_KEY_BASE="dI95JMc41U3fDgpcxWx7lhBecavnDnn2/prI/dwWK/vL8uqLONsHihtZ96qakwTk"

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix do deps.get, deps.compile, compile

ENTRYPOINT [ "mix", "phx.server" ]
