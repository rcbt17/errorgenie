# lib/errorgenie/middleware/error_renderer.rb
require "erb"

module ErrorGenie
  class ErrorRenderer
    def initialize(app)
      @app = app
    end

    def call(env)
      Rails.logger.info "ErrorGenie: Middleware called"

      # Call the original app and capture the response
      status, headers, response = @app.call(env)

      Rails.logger.info "ErrorGenie: Status = #{status}, Content-Type = #{headers['Content-Type']}"

      if Rails.env.development? && status == 500
        content_type = headers["Content-Type"] || "text/html"
        if content_type.include?("text/html")
          Rails.logger.info "ErrorGenie: Capturing and modifying error response"

          # Join the response if it's an array
          original_body = response.is_a?(Array) ? response.join : response.to_s

          # Render the AI Help HTML from the ERB template
          ai_help_html = render_ai_help_template

          # Inject AI Help HTML at the top of the body
          modified_body = original_body.sub("<body>", "<body>#{ai_help_html}")

          # Update headers with the modified content length
          headers["Content-Length"] = modified_body.bytesize.to_s
          Rails.logger.info "ErrorGenie: Successfully modified the response body to display AI Help at the top"

          # Return the modified response as an array
          return [ status, headers, [ modified_body ] ]
        end
      end

      # If not modified, pass through the response unmodified
      Rails.logger.info "ErrorGenie: Passing through unmodified response"
      [ status, headers, response ]
    rescue StandardError => error
      Rails.logger.error("Error in ErrorRenderer middleware: #{error.message}")
      raise error
    end

    private

    # Render the AI Help HTML from an ERB template
    def render_ai_help_template
      template_path = File.expand_path("../../../views/ai_help.html.erb", __FILE__)
      template = ERB.new(File.read(template_path))
      template.result(binding)
    end
  end
end
