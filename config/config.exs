use Mix.Config

config :logger,
  backend: [:console],
  level: :debug,
  truncate: :infinity

config :logger, :console,
  format: "$time ( $metadata) [$level] $levelpad$message\n",
  metadata: [:module]
