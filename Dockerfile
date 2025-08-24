# Use a small official Ruby image
FROM ruby:3.1-slim

# Create non-root user and working dir
RUN useradd -m appuser
WORKDIR /app

# System deps for native gems + curl for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential pkg-config libssl-dev \
    curl ca-certificates git \
 && rm -rf /var/lib/apt/lists/*

# Copy gem manifests first for better caching
COPY Gemfile Gemfile.lock ./

# (Optional) If you hit platform issues, uncomment the next line:
# RUN bundle config set force_ruby_platform true
RUN bundle config set without 'development test' \
 && bundle config set path 'vendor/bundle' \
 && bundle install --jobs=4 --retry=3

# Copy app code (expects app.rb + config.ru in repo root)
COPY app.rb config.ru ./
# copy API modules and data
COPY api ./api
COPY monsters.json /data/monsters.json

# Data path inside the container
ENV MONSTERS_JSON=/data/monsters.json

# Expose API port
EXPOSE 4567

# Drop privileges
USER appuser

# IMPORTANT: run Puma directly (rackup -o is not supported by Puma)
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:4567", "config.ru"]
