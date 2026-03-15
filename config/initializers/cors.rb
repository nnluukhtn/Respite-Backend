allowed_origins = ENV.fetch("ALLOWED_ORIGINS", "*")

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins.split(",").map(&:strip))

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head]
  end
end
