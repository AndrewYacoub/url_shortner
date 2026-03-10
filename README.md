# URL Shortener Service

A lightweight URL shortening service built with Ruby and Sinatra.

## Features

- **Encode URLs**: Convert long URLs into short, shareable links
- **Decode URLs**: Retrieve original URLs from shortened codes
- **Persistence**: JSON file storage ensures URLs survive server restarts (no database required!)
- **Click Tracking**: Track how many times each short URL is accessed
- **URL Expiration**: Optional expiration time for shortened URLs
- **Redirect Support**: Direct redirect to original URL via short code

## Requirements

- Ruby >= 3.0.0
- Bundler

**No database required!** Data is stored in a simple JSON file.

## Installation

```bash
# Navigate to the project directory
cd url_shortener

# Install dependencies
bundle install

# That's it! No database setup needed.
```

## Running the Server

### Development

```bash
# Start with auto-reload
bundle exec rerun -- rackup -p 9292

# Or without auto-reload
bundle exec puma -C config/puma.rb
```

### Production

```bash
RACK_ENV=production bundle exec puma -C config/puma.rb
```

The server runs on `http://localhost:9292` by default.

## API Endpoints

### Health Check

```bash
GET /health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2026-03-09T23:00:00Z"
}
```

### Encode URL

```bash
POST /encode
Content-Type: application/json

{
  "url": "https://www.example.com/very/long/path/to/resource",
  "expires_in_hours": 24  // optional
}
```

Response (201 Created):
```json
{
  "short_code": "abc123",
  "short_url": "http://localhost:9292/abc123",
  "original_url": "https://www.example.com/very/long/path/to/resource",
  "click_count": 0,
  "created_at": "2026-03-09T23:00:00Z",
  "expires_at": null
}
```

### Decode URL (GET)

```bash
GET /decode/:short_code
```

Response (200 OK):
```json
{
  "short_code": "abc123",
  "short_url": "http://localhost:9292/abc123",
  "original_url": "https://www.example.com/very/long/path/to/resource",
  "click_count": 5,
  "created_at": "2026-03-09T23:00:00Z",
  "expires_at": null
}
```

### Decode URL (POST)

```bash
POST /decode
Content-Type: application/json

{
  "short_code": "abc123"
}
# OR
{
  "short_url": "http://localhost:9292/abc123"
}
```

### Redirect

```bash
GET /:short_code
```

Redirects (302) to the original URL.

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with verbose output
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/app_spec.rb
```

## Project Structure

```
url_shortener/
├── app.rb                    # Main Sinatra application
├── config.ru                 # Rack configuration
├── Gemfile                   # Ruby dependencies
├── Rakefile                  # Rake tasks
├── README.md                 # This file
├── config/
│   └── puma.rb              # Puma server configuration
├── data/
│   └── urls.json            # URL data storage (created automatically)
├── lib/
│   ├── storage.rb           # JSON file storage manager
│   └── shortened_url.rb     # URL model with business logic
└── spec/
    ├── spec_helper.rb       # Test configuration
    ├── app_spec.rb          # API endpoint tests
    └── shortened_url_spec.rb # Model unit tests
```

## How Data is Stored

Data is persisted in a simple JSON file (`data/urls.json`):

```json
{
  "urls": [
    {
      "id": 1,
      "short_code": "abc123",
      "original_url": "https://example.com/long-url",
      "click_count": 5,
      "expires_at": null,
      "created_at": "2026-03-09T23:00:00Z",
      "updated_at": "2026-03-09T23:05:00Z"
    }
  ],
  "counter": 1
}
```

## Security Considerations

### 1. URL Validation

The service validates all incoming URLs to ensure they:
- Are valid HTTP or HTTPS URLs only (no `javascript:`, `file:`, etc.)
- Don't exceed 2048 characters (prevents memory exhaustion)
- Are properly formatted using regex validation

### 2. Input Sanitization

- All user input is validated before processing
- Short codes are restricted to alphanumeric characters only (`[a-zA-Z0-9]`)
- JSON parsing errors are caught and return appropriate error responses

### 3. Potential Attack Vectors & Mitigations

| Attack Vector | Risk | Mitigation |
|---------------|------|------------|
| **Open Redirect** | Attackers could use the service for phishing | URL validation; consider implementing a blocklist of known malicious domains |
| **Enumeration Attack** | Brute-forcing short codes to find URLs | 6-character base62 codes = 56B+ combinations; rate limiting recommended |
| **Denial of Service** | Overwhelming the server | Implement rate limiting (e.g., `rack-attack` gem); limit URL length |
| **Malicious URLs** | Users shortening malware/phishing links | Integrate with URL reputation services (Google Safe Browsing API) |
| **Data Exposure** | Short codes predictable | Random generation using secure methods; avoid sequential IDs |
| **File System Attack** | JSON file manipulation | File permissions; validate all data before writing |

### 4. Recommended Production Security Enhancements

```ruby
# Add to Gemfile for rate limiting:
gem 'rack-attack'

# Configure in app.rb:
use Rack::Attack
Rack::Attack.throttle('requests/ip', limit: 100, period: 60) do |req|
  req.ip
end
```

## Scalability Considerations

### Current Implementation (JSON File)

- **Best for**: Small deployments, demos, personal use
- **Capacity**: ~10,000-100,000 URLs
- **Limitations**: Single server only, file locking on writes

### Scaling Strategies

#### Phase 1: Stay Simple (Low Traffic)

The JSON file approach works well for:
- Demos and prototypes
- Personal URL shorteners
- Low-traffic internal tools

#### Phase 2: Add Database (Medium Traffic)

If you need more capacity:
```ruby
# Replace storage.rb with database adapter
# Options: SQLite, PostgreSQL, MySQL
```

#### Phase 3: Distributed Architecture (High Traffic)

1. **Redis for Caching** - Cache decoded URLs
2. **Database** - PostgreSQL with connection pooling
3. **Load Balancer** - Multiple app servers
4. **CDN** - Cache redirects at edge

### Estimated Capacity

| Configuration | Requests/Second | Storage |
|---------------|-----------------|---------|
| JSON File | ~50-100 | ~100K URLs |
| SQLite | ~100-500 | ~1M URLs |
| PostgreSQL + Redis | ~5,000-10,000 | ~100M URLs |

## Deployment

### Simple Deployment (No Database!)

1. Copy the project to your server
2. Install Ruby and Bundler
3. Run `bundle install`
4. Start with `bundle exec puma -C config/puma.rb`

### Docker (Optional)

```dockerfile
FROM ruby:3.2-alpine
WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY . .
EXPOSE 9292
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

## License

MIT License

## Author

Andrew Yacoub
