require "errorgenie/version"
require "errorgenie/railtie"  # Ensure the Railtie is loaded
require "errorgenie/middleware/error_renderer"  # Explicitly require the middleware file

module ErrorGenie
  def self.handle_error(error)
    # General error message
    "An error occurred: #{error.class.name} - #{error.message}"
  end

  # General AI advice message for all errors
  def self.ai_help(error)
    "AI Suggestion: Try checking the error details above and ensure your code aligns with Rails conventions. For more help, consult Rails documentation or debugging tools."
  end
end
