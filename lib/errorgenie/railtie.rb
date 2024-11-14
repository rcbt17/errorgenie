module ErrorGenie
  class Railtie < ::Rails::Railtie
    initializer "errorgenie.add_error_renderer_middleware" do |app|
      if Rails.env.development?
        app.middleware.insert_after ActionDispatch::ShowExceptions, ErrorGenie::ErrorRenderer
      end
    end
  end
end
