# frozen_string_literal: true

require 'securerandom'
require 'time'
require_relative 'storage'

class ShortenedUrl
  SHORT_CODE_LENGTH = 6
  VALID_URL_REGEX = %r{\Ahttps?://[^\s/$.?#].[^\s]*\z}i
  BASE62_CHARS = ('0'..'9').to_a + ('a'..'z').to_a + ('A'..'Z').to_a

  attr_accessor :id, :short_code, :original_url, :click_count, :expires_at, :created_at, :updated_at

  def initialize(attrs = {})
    @id = attrs[:id]
    @short_code = attrs[:short_code]
    @original_url = attrs[:original_url]
    @click_count = attrs[:click_count] || 0
    @expires_at = parse_time(attrs[:expires_at])
    @created_at = parse_time(attrs[:created_at]) || Time.now
    @updated_at = parse_time(attrs[:updated_at]) || Time.now
  end

  def increment_click_count!
    @click_count += 1
    @updated_at = Time.now
    save
  end

  def expired?
    return false if expires_at.nil?
    expires_at < Time.now
  end

  def to_hash
    {
      id: id,
      short_code: short_code,
      original_url: original_url,
      click_count: click_count,
      expires_at: expires_at&.iso8601,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end

  def to_json_response(base_url = '')
    {
      short_code: short_code,
      short_url: "#{base_url}/#{short_code}",
      original_url: original_url,
      click_count: click_count,
      created_at: created_at&.iso8601,
      expires_at: expires_at&.iso8601
    }
  end

  def save
    data = Storage.load_data
    index = data[:urls].find_index { |u| u[:id] == id }
    
    if index
      data[:urls][index] = to_hash
    else
      @id ||= (data[:counter] += 1)
      data[:urls] << to_hash
    end
    
    Storage.save_data(data)
    self
  end

  def refresh
    data = Storage.load_data
    record = data[:urls].find { |u| u[:id] == id }
    return self unless record

    @click_count = record[:click_count]
    @updated_at = parse_time(record[:updated_at])
    self
  end

  class << self
    def all
      Storage.load_data[:urls].map { |attrs| new(attrs) }
    end

    def find_by_short_code(code)
      data = Storage.load_data
      record = data[:urls].find { |u| u[:short_code] == code }
      record ? new(record) : nil
    end

    def find_by_original_url(url)
      data = Storage.load_data
      record = data[:urls].find { |u| u[:original_url] == url }
      record ? new(record) : nil
    end

    def create(attrs)
      url = new(attrs)
      url.short_code ||= generate_unique_short_code
      url.save
    end

    def shorten(original_url, expires_at: nil)
      return nil unless valid_url?(original_url)

      normalized_url = normalize_url(original_url)
      
      existing = find_by_original_url(normalized_url)
      return existing if existing && !existing.expired?

      create(original_url: normalized_url, expires_at: expires_at)
    end

    def decode(short_code)
      record = find_by_short_code(short_code)
      return nil unless record
      return nil if record.expired?

      record.increment_click_count!
      record
    end

    def valid_url?(url)
      return false if url.nil? || url.to_s.strip.empty?
      return false if url.length > 2048
      
      !!(url =~ VALID_URL_REGEX)
    end

    def normalize_url(url)
      url.strip
    end

    private

    def generate_unique_short_code
      loop do
        code = SHORT_CODE_LENGTH.times.map { BASE62_CHARS.sample }.join
        return code unless find_by_short_code(code)
      end
    end
  end

  private

  def parse_time(value)
    return nil if value.nil?
    return value if value.is_a?(Time)
    Time.parse(value)
  rescue ArgumentError
    nil
  end
end
