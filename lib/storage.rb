# frozen_string_literal: true

require 'json'
require 'fileutils'

module Storage
  class << self
    def data_file
      @data_file ||= begin
        env = ENV.fetch('RACK_ENV', 'development')
        filename = env == 'test' ? 'urls_test.json' : 'urls.json'
        
        # Use DATA_DIR env var if set (for cloud deployments with volumes)
        data_dir = ENV.fetch('DATA_DIR', File.join(File.dirname(__FILE__), '..', 'data'))
        File.join(data_dir, filename)
      end
    end

    def load_data
      ensure_data_file_exists
      JSON.parse(File.read(data_file), symbolize_names: true)
    rescue JSON::ParserError
      { urls: [], counter: 0 }
    end

    def save_data(data)
      ensure_data_file_exists
      File.write(data_file, JSON.pretty_generate(data))
    end

    def reset!
      @data_file = nil
      File.delete(data_file) if File.exist?(data_file)
    end

    private

    def ensure_data_file_exists
      dir = File.dirname(data_file)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      
      unless File.exist?(data_file)
        File.write(data_file, JSON.pretty_generate({ urls: [], counter: 0 }))
      end
    end
  end
end
