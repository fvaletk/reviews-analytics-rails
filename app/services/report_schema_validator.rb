# frozen_string_literal: true

class ReportSchemaValidator
  InvalidSchema = Class.new(StandardError)

  TOP_LEVEL_ARRAY_KEYS = %w[pain_points complaints feature_requests strengths opportunities].freeze
  TOP_LEVEL_KEYS = (%w[summary] + TOP_LEVEL_ARRAY_KEYS).freeze

  PAIN_POINT_REQUIRED_KEYS = %w[title severity frequency description].freeze
  VALID_SEVERITIES = %w[critical high medium low].freeze

  def self.validate!(hash)
    raise InvalidSchema, "expected a Hash, got #{hash.class}" unless hash.is_a?(Hash)

    TOP_LEVEL_KEYS.each do |key|
      raise InvalidSchema, "missing key: #{key}" unless key?(hash, key)
    end

    TOP_LEVEL_ARRAY_KEYS.each do |key|
      value = fetch(hash, key)
      raise InvalidSchema, "#{key} must be an Array" unless value.is_a?(Array)
    end

    validate_pain_points!(fetch(hash, "pain_points"))
  end

  def self.validate_pain_points!(pain_points)
    pain_points.each_with_index do |item, index|
      unless item.is_a?(Hash)
        raise InvalidSchema, "pain_points[#{index}] must be a Hash"
      end

      PAIN_POINT_REQUIRED_KEYS.each do |key|
        raise InvalidSchema, "pain_points[#{index}] missing key: #{key}" unless key?(item, key)
      end

      severity = fetch(item, "severity")
      unless VALID_SEVERITIES.include?(severity)
        raise InvalidSchema, "pain_points[#{index}] has invalid severity: #{severity.inspect}"
      end
    end
  end
  private_class_method :validate_pain_points!

  def self.key?(hash, key)
    hash.key?(key.to_s) || hash.key?(key.to_sym)
  end
  private_class_method :key?

  def self.fetch(hash, key)
    hash.key?(key.to_s) ? hash[key.to_s] : hash[key.to_sym]
  end
  private_class_method :fetch
end
