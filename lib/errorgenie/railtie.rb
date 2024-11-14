module ErrorGenie
  class Railtie < ::Rails::Railtie
    initializer "errorgenie.configure_middleware" do |app|
      app.middleware.insert_after ActionDispatch::DebugExceptions, ErrorGenie::ErrorRenderer
    end
  end
end
