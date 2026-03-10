# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'json'
require_relative 'lib/shortened_url'

class UrlShortenerApp < Sinatra::Base
  configure do
    set :show_exceptions, false
    set :raise_errors, true
  end

  before do
    content_type :json
  end

  helpers do
    def json_body
      @json_body ||= begin
        request.body.rewind
        body = request.body.read
        body.empty? ? {} : JSON.parse(body, symbolize_names: true)
      rescue JSON::ParserError
        halt 400, { 'Content-Type' => 'application/json' }, { error: 'Invalid JSON format' }.to_json
      end
    end

    def base_url
      @base_url ||= "#{request.scheme}://#{request.host_with_port}"
    end

    def error_response(status_code, message, extra = {})
      halt status_code, { 'Content-Type' => 'application/json' }, { error: message }.merge(extra).to_json
    end
  end

  # Health check endpoint
  get '/health' do
    json(status: 'ok', timestamp: Time.now.iso8601)
  end

  # POST /encode - Encode a URL to a shortened URL
  post '/encode' do
    url = json_body[:url]

    if url.nil? || url.to_s.strip.empty?
      error_response(400, 'URL is required', field: 'url')
    end

    unless ShortenedUrl.valid_url?(url)
      error_response(422, 'Invalid URL format. Must be a valid HTTP or HTTPS URL.', field: 'url', provided: url)
    end

    expires_at = nil
    if json_body[:expires_in_hours]
      hours = json_body[:expires_in_hours].to_i
      expires_at = Time.now + (hours * 3600) if hours.positive?
    end

    shortened = ShortenedUrl.shorten(url, expires_at: expires_at)

    if shortened
      status 201
      json(shortened.to_json_response(base_url))
    else
      error_response(500, 'Failed to create shortened URL')
    end
  end

  # GET /decode/:short_code - Decode a shortened URL back to original
  get '/decode/:short_code' do
    short_code = params[:short_code]

    if short_code.nil? || short_code.strip.empty?
      error_response(400, 'Short code is required')
    end

    unless short_code.match?(/\A[a-zA-Z0-9]+\z/)
      error_response(400, 'Invalid short code format')
    end

    record = ShortenedUrl.find_by_short_code(short_code)

    if record.nil?
      error_response(404, 'Short URL not found', short_code: short_code)
    end

    if record.expired?
      error_response(410, 'Short URL has expired', short_code: short_code)
    end

    record.increment_click_count!
    json(record.to_json_response(base_url))
  end

  # POST /decode - Alternative decode endpoint (accepts JSON body)
  post '/decode' do
    short_code = json_body[:short_code]
    short_url = json_body[:short_url]

    if short_code.nil? && short_url
      short_code = short_url.to_s.split('/').last
    end

    if short_code.nil? || short_code.to_s.strip.empty?
      error_response(400, 'short_code or short_url is required')
    end

    unless short_code.match?(/\A[a-zA-Z0-9]+\z/)
      error_response(400, 'Invalid short code format')
    end

    record = ShortenedUrl.find_by_short_code(short_code)

    if record.nil?
      error_response(404, 'Short URL not found', short_code: short_code)
    end

    if record.expired?
      error_response(410, 'Short URL has expired', short_code: short_code)
    end

    record.increment_click_count!
    json(record.to_json_response(base_url))
  end

  # GET /:short_code - Redirect to original URL
  get '/:short_code' do
    short_code = params[:short_code]
    
    pass if short_code == 'favicon.ico'

    record = ShortenedUrl.find_by_short_code(short_code)

    if record.nil?
      error_response(404, 'Short URL not found')
    end

    if record.expired?
      error_response(410, 'Short URL has expired')
    end

    record.increment_click_count!
    redirect record.original_url, 302
  end

  not_found do
    content_type :json
    { error: 'Endpoint not found' }.to_json
  end
end
