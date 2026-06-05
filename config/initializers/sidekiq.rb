Sidekiq.configure_server { |c| c.redis = { url: ENV["REDIS_URL"] } }
Sidekiq.configure_client { |c| c.redis = { url: ENV["REDIS_URL"] } }
