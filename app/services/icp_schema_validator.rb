# frozen_string_literal: true

class IcpSchemaValidator
  InvalidSchema = Class.new(StandardError)

  TOP_LEVEL_KEYS = %w[primary_segment confidence signals declined_reason].freeze
  VALID_CONFIDENCES = %w[high medium low].freeze

  def self.validate!(hash)
    raise InvalidSchema, "expected a Hash, got #{hash.class}" unless hash.is_a?(Hash)

    TOP_LEVEL_KEYS.each do |key|
      raise InvalidSchema, "missing key: #{key}" unless key?(hash, key)
    end

    signals = fetch(hash, "signals")
    raise InvalidSchema, "signals must be an Array" unless signals.is_a?(Array)

    validate_signals!(signals)

    confidence = fetch(hash, "confidence")
    unless confidence.nil? || VALID_CONFIDENCES.include?(confidence)
      raise InvalidSchema, "invalid confidence: #{confidence.inspect}"
    end

    primary_segment = fetch(hash, "primary_segment")
    if primary_segment.blank? && signals.present?
      raise InvalidSchema, "a decline (blank primary_segment) cannot carry signals"
    end
  end

  def self.validate_signals!(signals)
    signals.each_with_index do |signal, index|
      unless signal.is_a?(Hash)
        raise InvalidSchema, "signals[#{index}] must be a Hash"
      end

      quote = fetch(signal, "quote")
      raise InvalidSchema, "signals[#{index}] missing quote" if quote.blank?

      role_hint = fetch(signal, "role_hint")
      raise InvalidSchema, "signals[#{index}] missing role_hint" if role_hint.blank?
    end
  end
  private_class_method :validate_signals!

  def self.key?(hash, key)
    hash.key?(key.to_s) || hash.key?(key.to_sym)
  end
  private_class_method :key?

  def self.fetch(hash, key)
    hash.key?(key.to_s) ? hash[key.to_s] : hash[key.to_sym]
  end
  private_class_method :fetch
end
