# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe ShortenedUrl do
  describe '.valid_url?' do
    it 'accepts valid HTTP URLs' do
      expect(described_class.valid_url?('http://example.com')).to be true
      expect(described_class.valid_url?('http://example.com/path')).to be true
      expect(described_class.valid_url?('http://example.com/path?query=1')).to be true
    end

    it 'accepts valid HTTPS URLs' do
      expect(described_class.valid_url?('https://example.com')).to be true
      expect(described_class.valid_url?('https://www.example.com/path')).to be true
      expect(described_class.valid_url?('https://subdomain.example.com')).to be true
    end

    it 'rejects invalid URLs' do
      expect(described_class.valid_url?(nil)).to be false
      expect(described_class.valid_url?('')).to be false
      expect(described_class.valid_url?('not-a-url')).to be false
      expect(described_class.valid_url?('ftp://example.com')).to be false
      expect(described_class.valid_url?('javascript:alert(1)')).to be false
    end

    it 'rejects URLs that are too long' do
      long_url = "https://example.com/#{'a' * 2100}"
      expect(described_class.valid_url?(long_url)).to be false
    end
  end

  describe '.shorten' do
    let(:valid_url) { 'https://example.com/test' }

    it 'creates a new shortened URL' do
      result = described_class.shorten(valid_url)

      expect(result).to be_a(ShortenedUrl)
      expect(result.original_url).to eq(valid_url)
      expect(result.short_code).to be_a(String)
      expect(result.short_code.length).to eq(6)
    end

    it 'returns existing record for duplicate URLs' do
      first = described_class.shorten(valid_url)
      second = described_class.shorten(valid_url)

      expect(first.id).to eq(second.id)
      expect(first.short_code).to eq(second.short_code)
    end

    it 'returns nil for invalid URLs' do
      expect(described_class.shorten('invalid')).to be_nil
      expect(described_class.shorten(nil)).to be_nil
    end

    it 'creates URL with expiration' do
      expires_at = Time.now + 3600
      result = described_class.shorten(valid_url, expires_at: expires_at)

      expect(result.expires_at).to be_within(1).of(expires_at)
    end

    it 'creates new record if existing one is expired' do
      expired = described_class.create(
        original_url: valid_url,
        short_code: 'old123',
        expires_at: Time.now - 3600
      )

      new_record = described_class.shorten(valid_url)

      expect(new_record.id).not_to eq(expired.id)
      expect(new_record.short_code).not_to eq(expired.short_code)
    end
  end

  describe '.decode' do
    let!(:shortened) { described_class.shorten('https://example.com/decode-test') }

    it 'returns the record for valid short code' do
      result = described_class.decode(shortened.short_code)

      expect(result.id).to eq(shortened.id)
      expect(result.original_url).to eq(shortened.original_url)
    end

    it 'increments click count' do
      initial = shortened.click_count
      described_class.decode(shortened.short_code)
      shortened.refresh

      expect(shortened.click_count).to eq(initial + 1)
    end

    it 'returns nil for non-existent short code' do
      expect(described_class.decode('nonexistent')).to be_nil
    end

    it 'returns nil for expired URL' do
      expired = described_class.create(
        original_url: 'https://example.com/expired',
        short_code: 'exprd2',
        expires_at: Time.now - 3600
      )

      expect(described_class.decode(expired.short_code)).to be_nil
    end
  end

  describe '#expired?' do
    it 'returns false when no expiration set' do
      url = described_class.shorten('https://example.com/no-expiry')
      expect(url.expired?).to eq(false)
    end

    it 'returns false when not expired' do
      url = described_class.shorten('https://example.com/future', expires_at: Time.now + 3600)
      expect(url.expired?).to eq(false)
    end

    it 'returns true when expired' do
      url = described_class.create(
        original_url: 'https://example.com/past',
        short_code: 'past12',
        expires_at: Time.now - 3600
      )
      expect(url.expired?).to eq(true)
    end
  end

  describe '#to_json_response' do
    let(:url) { described_class.shorten('https://example.com/json-test') }

    it 'returns properly formatted hash' do
      response = url.to_json_response('http://short.io')

      expect(response[:short_code]).to eq(url.short_code)
      expect(response[:short_url]).to eq("http://short.io/#{url.short_code}")
      expect(response[:original_url]).to eq(url.original_url)
      expect(response[:click_count]).to eq(0)
      expect(response[:created_at]).to be_a(String)
    end
  end

  describe 'short code generation' do
    it 'generates unique short codes' do
      codes = 100.times.map do
        described_class.shorten("https://example.com/unique/#{SecureRandom.hex}").short_code
      end

      expect(codes.uniq.length).to eq(100)
    end

    it 'generates alphanumeric codes only' do
      url = described_class.shorten('https://example.com/alphanumeric')
      expect(url.short_code).to match(/\A[a-zA-Z0-9]+\z/)
    end
  end
end
