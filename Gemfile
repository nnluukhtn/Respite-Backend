source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.6"
gem "puma", ">= 5.0"
gem "rack-cors"
gem "redis", "~> 5.4"
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri mingw mswin x64_mingw ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rspec-rails", "~> 8.0"
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "webmock"
end
