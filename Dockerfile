FROM ruby:3.2-alpine

RUN apk add --no-cache build-base

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install --without development test

COPY . .

RUN mkdir -p data

EXPOSE 8080

ENV PORT=8080
ENV RACK_ENV=production

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
