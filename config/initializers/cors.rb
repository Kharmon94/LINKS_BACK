# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins_list = %w[
      http://localhost:3000
      http://localhost:5173
      http://127.0.0.1:5173
    ]
    fo = ENV["FRONTEND_ORIGIN"].presence
    origins_list << fo if fo
    origins(*origins_list.uniq)

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Authorization]
  end
end
