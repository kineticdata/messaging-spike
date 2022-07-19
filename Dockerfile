FROM elixir:latest

RUN mkdir /app
COPY . /app
WORKDIR /app

ENV MIX_ENV="prod"
ENV SECRET_KEY_BASE="dI95JMc41U3fDgpcxWx7lhBecavnDnn2/prI/dwWK/vL8uqLONsHihtZ96qakwTk"

# Rabbit Configuration
ENV RABBIT_HOST="localhost"
ENV RABBIT_PORT="5672"
ENV RABBIT_USER="guest"
ENV RABBIT_PASS="guest"

# NATS Configuration
ENV NATS_HOST="localhost"
ENV NATS_PORT="4222"
ENV NATS_USER="_"
ENV NATS_PASS="_"

# Kafka Configuration
ENV KAFKA_HOST="spike-kafka-1"
ENV KAFKA_PORT="9092"

# NATS Configuration
ENV REDIS_HOST="localhost"
ENV REDIS_PORT="6379"
ENV REDIS_USER="_"
ENV REDIS_PASS="_"

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix do deps.get, deps.compile, compile

EXPOSE 4000/tcp

ENTRYPOINT [ "mix", "phx.server" ]
