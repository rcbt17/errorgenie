module ErrorGenie
  class ErrorRenderer
    def initialize(app)
      @app = app
    end

    def call(env)
      Rails.logger.info "ErrorGenie: Middleware called"

      # Call the original app and capture the response
      status, headers, response = @app.call(env)

      # Only process if it's a 500 error in development with HTML content
      if Rails.env.development? && status == 500 && headers["Content-Type"].to_s.include?("text/html")
        Rails.logger.info "ErrorGenie: Capturing and modifying error response"

        # Join response in case it's an array
        original_body = response.is_a?(Array) ? response.join : response.to_s

        # Extract error information for ChatGPT if available
        error_info = env["action_dispatch.exception"]
        if error_info
          error_message = error_info.message
          backtrace = error_info.backtrace
          file_path, line_number = parse_backtrace(backtrace.first)
          source_code = fetch_source_code(file_path, line_number)

          # Send request to ChatGPT
          ai_response = get_chatgpt_response(error_message, file_path, source_code)

          # Render the AI Help HTML from the ERB template with ChatGPT's response
          ai_help_html = render_ai_help_template(ai_response)
        else
          ai_help_html = "<div style='background-color: yellow; padding: 10px;'>ErrorGenie: No exception info available.</div>"
        end

        # Inject AI Help HTML into the original body **without replacing the entire page**
        modified_body = original_body.sub("<body>", "<body>#{ai_help_html}")

        # Update headers with the modified content length
        headers["Content-Length"] = modified_body.bytesize.to_s

        Rails.logger.info "ErrorGenie: Successfully modified the response body to display AI Help at the top"
        return [ status, headers, [ modified_body ] ]
      end

      # If not modified, pass through the response unmodified
      [ status, headers, response ]
    rescue StandardError => error
      Rails.logger.error("Error in ErrorRenderer middleware: #{error.message}")
      raise error
    end

    private

    # Extract file path and line number from the backtrace
    def parse_backtrace(backtrace_line)
      if backtrace_line =~ /(.*):(\d+)/
        [ $1, $2.to_i ]
      else
        [ nil, nil ]
      end
    end

    # Fetch source code around the line that caused the error
    def fetch_source_code(file_path, line_number, context_lines = 5)
      return "Source code not available" unless file_path && File.exist?(file_path)

      lines = File.readlines(file_path)
      start_line = [ line_number - context_lines - 1, 0 ].max
      end_line = [ line_number + context_lines - 1, lines.size - 1 ].min
      lines[start_line..end_line].join
    rescue
      "Unable to fetch source code"
    end

    # Send the error information to ChatGPT and get a response
    def get_chatgpt_response(error_message, file_path, source_code)
      uri = URI("https://api.openai.com/v1/chat/completions")
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}")
      request.body = {
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a helpful assistant for debugging Ruby on Rails applications." },
          { role: "user", content: "I encountered an error: #{error_message}. It occurred in the file #{file_path}. Here’s the relevant code:\n\n#{source_code}" }
        ]
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      JSON.parse(response.body)["choices"][0]["message"]["content"]
    rescue StandardError => e
      Rails.logger.error("ErrorGenie: Failed to get response from ChatGPT - #{e.message}")
      "Could not fetch AI assistance at this time."
    end

    # Render the AI Help HTML from an ERB template
    def render_ai_help_template(ai_response)
      template_path = File.expand_path("../../../views/ai_help.html.erb", __FILE__)
      template = ERB.new(File.read(template_path))
      template.result_with_hash(ai_response: ai_response)
    end
  end
end
