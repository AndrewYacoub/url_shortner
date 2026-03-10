# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe UrlShortenerApp do
  describe 'GET /health' do
    it 'returns health status' do
      get '/health'

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('ok')
      expect(json_response[:timestamp]).to be_a(String)
    end
  end

  describe 'POST /encode' do
    context 'with valid URL' do
      let(:valid_url) { 'https://www.example.com/very/long/path/to/resource?param=value' }

      it 'creates a shortened URL' do
        post '/encode', { url: valid_url }.to_json, 'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(201)
        expect(json_response[:original_url]).to eq(valid_url)
        expect(json_response[:short_code]).to be_a(String)
        expect(json_response[:short_code].length).to eq(6)
        expect(json_response[:short_url]).to include(json_response[:short_code])
      end

      it 'returns the same short code for duplicate URLs' do
        post '/encode', { url: valid_url }.to_json, 'CONTENT_TYPE' => 'application/json'
        first_short_code = json_response[:short_code]

        post '/encode', { url: valid_url }.to_json, 'CONTENT_TYPE' => 'application/json'
        second_short_code = json_response[:short_code]

        expect(first_short_code).to eq(second_short_code)
      end

      it 'creates URL with expiration' do
        post '/encode', { url: valid_url, expires_in_hours: 24 }.to_json, 'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(201)
        expect(json_response[:expires_at]).not_to be_nil
      end
    end

    context 'with invalid URL' do
      it 'returns error for missing URL' do
        post '/encode', {}.to_json, 'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(400)
        expect(json_response[:error]).to include('required')
      end

      it 'returns error for empty URL' do
        post '/encode', { url: '' }.to_json, 'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(400)
        expect(json_response[:error]).to include('required')
      end

      it 'returns error for invalid URL format' do
        post '/encode', { url: 'not-a-valid-url' }.to_json, 'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(422)
        expect(json_response[:error]).to include('Invalid URL')
      end

      it 'returns error for non-http URL' do
        post '/encode', { url: 'ftp://example.com/file' }.to_json, 'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(422)
        expect(json_response[:error]).to include('Invalid URL')
      end

      it 'returns error for invalid JSON' do
        post '/encode', 'not-json', 'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(400)
        expect(json_response[:error]).to include('Invalid JSON')
      end
    end
  end

  describe 'GET /decode/:short_code' do
    let(:original_url) { 'https://www.example.com/original' }
    let!(:shortened_url) { ShortenedUrl.shorten(original_url) }

    context 'with valid short code' do
      it 'decodes the shortened URL' do
        get "/decode/#{shortened_url.short_code}"

        expect(last_response.status).to eq(200)
        expect(json_response[:original_url]).to eq(original_url)
        expect(json_response[:short_code]).to eq(shortened_url.short_code)
      end

      it 'increments click count' do
        initial_count = shortened_url.click_count

        get "/decode/#{shortened_url.short_code}"
        shortened_url.refresh

        expect(shortened_url.click_count).to eq(initial_count + 1)
      end
    end

    context 'with invalid short code' do
      it 'returns 404 for non-existent short code' do
        get '/decode/nonexistent'

        expect(last_response.status).to eq(404)
        expect(json_response[:error]).to include('not found')
      end

      it 'returns error for invalid format' do
        get '/decode/invalid-code!'

        expect(last_response.status).to eq(400)
        expect(json_response[:error]).to include('Invalid short code')
      end
    end

    context 'with expired URL' do
      let!(:expired_url) do
        ShortenedUrl.create(
          original_url: 'https://example.com/expired',
          short_code: 'exprd1',
          expires_at: Time.now - 3600
        )
      end

      it 'returns 410 Gone for expired URLs' do
        get "/decode/#{expired_url.short_code}"

        expect(last_response.status).to eq(410)
        expect(json_response[:error]).to include('expired')
      end
    end
  end

  describe 'POST /decode' do
    let(:original_url) { 'https://www.example.com/post-decode' }
    let!(:shortened_url) { ShortenedUrl.shorten(original_url) }

    it 'decodes using short_code in body' do
      post '/decode', { short_code: shortened_url.short_code }.to_json, 'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      expect(json_response[:original_url]).to eq(original_url)
    end

    it 'decodes using short_url in body' do
      post '/decode', { short_url: "http://example.com/#{shortened_url.short_code}" }.to_json, 'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      expect(json_response[:original_url]).to eq(original_url)
    end

    it 'returns error when neither short_code nor short_url provided' do
      post '/decode', {}.to_json, 'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(400)
      expect(json_response[:error]).to include('required')
    end
  end

  describe 'GET /:short_code (redirect)' do
    let(:original_url) { 'https://www.example.com/redirect-target' }
    let!(:shortened_url) { ShortenedUrl.shorten(original_url) }

    it 'redirects to the original URL' do
      get "/#{shortened_url.short_code}"

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to eq(original_url)
    end

    it 'returns 404 for non-existent short code' do
      get '/nonexistent'

      expect(last_response.status).to eq(404)
    end
  end
end
