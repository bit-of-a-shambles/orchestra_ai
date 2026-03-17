# frozen_string_literal: true

module OrchestraAI
  module Costs
    # Manages per-provider budget limits and spending tracking
    class Budget
      PROVIDERS = %i[anthropic openai google mistral].freeze

      attr_reader :limits, :spent, :alert_threshold

      def initialize(limits: {}, alert_threshold: 0.8)
        @limits = normalize_limits(limits)
        @spent = PROVIDERS.to_h { |p| [p, 0.0] }
        @alert_threshold = alert_threshold.to_f
        @alerts_fired = PROVIDERS.to_h { |p| [p, false] }
      end

      def remaining(provider = nil)
        if provider
          provider = provider.to_sym
          validate_provider!(provider)
          limit = @limits[provider]
          return Float::INFINITY if limit.nil?

          [limit - @spent[provider], 0.0].max
        else
          PROVIDERS.to_h { |p| [p, remaining(p)] }
        end
      end

      def can_afford?(amount, provider)
        provider = provider.to_sym
        validate_provider!(provider)

        limit = @limits[provider]
        return true if limit.nil? # No limit set

        remaining(provider) >= amount
      end

      def record_spend(amount, provider)
        provider = provider.to_sym
        validate_provider!(provider)

        @spent[provider] += amount
        check_alert_threshold(provider)
        @spent[provider]
      end

      def total_spent
        @spent.values.sum
      end

      def total_limit
        limited = @limits.compact
        return Float::INFINITY if limited.empty?

        limited.values.sum
      end

      def total_remaining
        [total_limit - total_spent, 0.0].max
      end

      def at_alert_threshold?(provider)
        provider = provider.to_sym
        limit = @limits[provider]
        return false if limit.nil? || limit.zero?

        (@spent[provider] / limit) >= @alert_threshold
      end

      def exceeded?(provider = nil)
        if provider
          provider = provider.to_sym
          limit = @limits[provider]
          return false if limit.nil?

          @spent[provider] > limit
        else
          PROVIDERS.any? { |p| exceeded?(p) }
        end
      end

      def reset(provider = nil)
        if provider
          provider = provider.to_sym
          validate_provider!(provider)
          @spent[provider] = 0.0
          @alerts_fired[provider] = false
        else
          PROVIDERS.each { |p| reset(p) }
        end
      end

      def set_limit(provider, amount)
        provider = provider.to_sym
        validate_provider!(provider)
        @limits[provider] = amount&.to_f
      end

      def to_h
        {
          limits: @limits.dup,
          spent: @spent.dup,
          remaining: remaining,
          alert_threshold: @alert_threshold,
          exceeded: exceeded?
        }
      end

      def status_summary
        PROVIDERS.map do |provider|
          limit = @limits[provider]
          spent = @spent[provider]
          rem = remaining(provider)

          status = if limit.nil?
                     :unlimited
                   elsif exceeded?(provider)
                     :exceeded
                   elsif at_alert_threshold?(provider)
                     :warning
                   else
                     :ok
                   end

          [provider, { limit: limit, spent: spent, remaining: rem, status: status }]
        end.to_h
      end

      private

      def normalize_limits(limits)
        PROVIDERS.to_h do |provider|
          value = limits[provider] || limits[provider.to_s]
          [provider, value&.to_f]
        end
      end

      def validate_provider!(provider)
        return if PROVIDERS.include?(provider)

        raise ArgumentError, "Unknown provider: #{provider}. Valid providers: #{PROVIDERS.join(', ')}"
      end

      def check_alert_threshold(provider)
        return if @alerts_fired[provider]
        return unless at_alert_threshold?(provider)

        @alerts_fired[provider] = true
        fire_alert(provider)
      end

      def fire_alert(provider)
        # Hook for alert callbacks - can be extended
        warn "[OrchestraAI] Budget alert: #{provider} has reached #{(@alert_threshold * 100).to_i}% of limit"
      end
    end
  end
end
