ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "minitest/autorun"
require "active_support/test_case"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
  end
end
