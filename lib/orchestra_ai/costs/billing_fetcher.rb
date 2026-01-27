# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module OrchestraAI
  module Costs
    # Fetches billing and usage information from provider APIs
    #
    # Note: Each provider has different APIs and capabilities:
    # - OpenAI: Has a Costs API (requires admin key) and Usage API
    # - Anthropic: Limited API access, usage visible in console
    # - Google: Uses Google Cloud Billing API (requires separate auth)
    class BillingFetcher
      PROVIDERS = %i[anthropic openai google].freeze

      # OpenAI endpoints
      OPENAI_COSTS_URL = 'https://api.openai.com/v1/organization/costs'
      OPENAI_USAGE_URL = 'https://api.openai.com/v1/organization/usage/completions'

      # Anthropic endpoints (Admin API)
      ANTHROPIC_COST_URL = 'https://api.anthropic.com/v1/organizations/cost_report'
      ANTHROPIC_USAGE_URL = 'https://api.anthropic.com/v1/organizations/usage_report/messages'

      # Result structure for billing data
      BillingResult = Struct.new(:provider, :success, :usage_data, :error_message, keyword_init: true) do
        def success?
          success == true
        end

        def cost_this_month
          return nil unless success? && usage_data

          usage_data[:cost_this_month]
        end

        def total_tokens
          return nil unless success? && usage_data

          usage_data[:total_tokens]
        end
      end

      class << self
        def fetch_all(api_keys = {})
          PROVIDERS.each_with_object({}) do |provider, results|
            api_key = api_keys[provider] || api_keys[provider.to_s]
            # For OpenAI, prefer admin key for billing access
            if provider == :openai
              api_key = api_keys[:openai_admin] || api_keys['openai_admin'] ||
                        ENV['OPENAI_ADMIN_KEY'] || api_key
            end
            # For Anthropic, prefer admin key for billing access
            if provider == :anthropic
              api_key = api_keys[:anthropic_admin] || api_keys['anthropic_admin'] ||
                        ENV['ANTHROPIC_ADMIN_KEY'] || api_key
            end
            results[provider] = fetch(provider, api_key)
          end
        end

        def fetch(provider, api_key)
          unless api_key
            return BillingResult.new(
              provider: provider,
              success: false,
              error_message: "No API key configured for #{provider}"
            )
          end

          case provider.to_sym
          when :openai
            fetch_openai(api_key)
          when :anthropic
            fetch_anthropic(api_key)
          when :google
            fetch_google(api_key)
          else
            BillingResult.new(
              provider: provider,
              success: false,
              error_message: "Unknown provider: #{provider}"
            )
          end
        rescue StandardError => e
          BillingResult.new(
            provider: provider,
            success: false,
            error_message: "#{e.class}: #{e.message}"
          )
        end

        private

        def fetch_openai(api_key)
          # OpenAI Costs/Usage API requires OPENAI_ADMIN_KEY for organization access
          # Regular API keys will get 403 Forbidden
          costs_result = fetch_openai_costs(api_key)
          return costs_result if costs_result.success?

          # Try usage API as fallback (also requires admin key)
          usage_result = fetch_openai_usage(api_key)
          return usage_result if usage_result.success?

          # Both failed - provide helpful message
          BillingResult.new(
            provider: :openai,
            success: false,
            error_message: 'OpenAI Costs/Usage API requires an admin key. ' \
                           'Set OPENAI_ADMIN_KEY env var (get it from platform.openai.com/settings/organization/admin-keys). ' \
                           'Check usage at: https://platform.openai.com/settings/organization/usage'
          )
        end

        def fetch_openai_costs(api_key)
          # Get costs for the current month
          start_of_month = Time.now.strftime('%Y-%m-01')
          start_time = Time.parse("#{start_of_month} 00:00:00 UTC").to_i
          end_time = Time.now.to_i

          uri = URI("#{OPENAI_COSTS_URL}?start_time=#{start_time}&end_time=#{end_time}&limit=31")

          response = make_request(uri, api_key)

          unless response.is_a?(Net::HTTPSuccess)
            return BillingResult.new(
              provider: :openai,
              success: false,
              error_message: "HTTP #{response.code}: #{response.message}"
            )
          end

          data = JSON.parse(response.body)
          total_cost = extract_openai_total_cost(data)

          BillingResult.new(
            provider: :openai,
            success: true,
            usage_data: {
              cost_this_month: total_cost,
              currency: 'usd',
              period: 'current_month',
              raw_data: data
            }
          )
        rescue JSON::ParserError => e
          BillingResult.new(
            provider: :openai,
            success: false,
            error_message: "Failed to parse response: #{e.message}"
          )
        end

        def fetch_openai_usage(api_key)
          # Get usage (tokens) for the current month
          start_of_month = Time.now.strftime('%Y-%m-01')
          start_time = Time.parse("#{start_of_month} 00:00:00 UTC").to_i

          uri = URI("#{OPENAI_USAGE_URL}?start_time=#{start_time}&limit=31")

          response = make_request(uri, api_key)

          unless response.is_a?(Net::HTTPSuccess)
            return BillingResult.new(
              provider: :openai,
              success: false,
              error_message: "HTTP #{response.code}: #{response.message}"
            )
          end

          data = JSON.parse(response.body)
          tokens = extract_openai_tokens(data)

          BillingResult.new(
            provider: :openai,
            success: true,
            usage_data: {
              total_tokens: tokens[:total],
              input_tokens: tokens[:input],
              output_tokens: tokens[:output],
              period: 'current_month',
              raw_data: data
            }
          )
        rescue JSON::ParserError => e
          BillingResult.new(
            provider: :openai,
            success: false,
            error_message: "Failed to parse response: #{e.message}"
          )
        end

        def fetch_anthropic(api_key)
          # Anthropic Admin API for Usage & Cost
          # Requires an admin key starting with sk-ant-admin...
          # https://docs.anthropic.com/en/docs/administration-and-monitoring/usage-and-cost-api

          # Try cost endpoint first (provides USD costs)
          cost_result = fetch_anthropic_costs(api_key)
          return cost_result if cost_result.success?

          # Fall back to usage endpoint (provides token counts)
          usage_result = fetch_anthropic_usage(api_key)
          return usage_result if usage_result.success?

          # Both failed - provide helpful message
          BillingResult.new(
            provider: :anthropic,
            success: false,
            error_message: 'Anthropic Usage/Cost API requires an admin key (sk-ant-admin...). ' \
                           'Set ANTHROPIC_ADMIN_KEY env var (get it from console.anthropic.com). ' \
                           'Check usage at: https://console.anthropic.com/settings/usage'
          )
        end

        def fetch_anthropic_costs(api_key)
          # Get costs for the current month
          start_of_month = Time.now.utc.strftime('%Y-%m-01T00:00:00Z')
          end_of_month = Time.now.utc.strftime('%Y-%m-%dT23:59:59Z')

          uri = URI("#{ANTHROPIC_COST_URL}?starting_at=#{start_of_month}&ending_at=#{end_of_month}")

          response = make_anthropic_request(uri, api_key)

          unless response.is_a?(Net::HTTPSuccess)
            return BillingResult.new(
              provider: :anthropic,
              success: false,
              error_message: "HTTP #{response.code}: #{response.message}"
            )
          end

          data = JSON.parse(response.body)
          total_cost = extract_anthropic_total_cost(data)

          BillingResult.new(
            provider: :anthropic,
            success: true,
            usage_data: {
              cost_this_month: total_cost,
              currency: 'usd',
              period: 'current_month',
              raw_data: data
            }
          )
        rescue JSON::ParserError => e
          BillingResult.new(
            provider: :anthropic,
            success: false,
            error_message: "Failed to parse response: #{e.message}"
          )
        end

        def fetch_anthropic_usage(api_key)
          # Get usage (tokens) for the current month with daily buckets
          start_of_month = Time.now.utc.strftime('%Y-%m-01T00:00:00Z')
          end_of_month = Time.now.utc.strftime('%Y-%m-%dT23:59:59Z')

          uri = URI("#{ANTHROPIC_USAGE_URL}?starting_at=#{start_of_month}&ending_at=#{end_of_month}&bucket_width=1d")

          response = make_anthropic_request(uri, api_key)

          unless response.is_a?(Net::HTTPSuccess)
            return BillingResult.new(
              provider: :anthropic,
              success: false,
              error_message: "HTTP #{response.code}: #{response.message}"
            )
          end

          data = JSON.parse(response.body)
          tokens = extract_anthropic_tokens(data)

          BillingResult.new(
            provider: :anthropic,
            success: true,
            usage_data: {
              total_tokens: tokens[:total],
              input_tokens: tokens[:input],
              output_tokens: tokens[:output],
              cached_input_tokens: tokens[:cached_input],
              cache_creation_tokens: tokens[:cache_creation],
              period: 'current_month',
              raw_data: data
            }
          )
        rescue JSON::ParserError => e
          BillingResult.new(
            provider: :anthropic,
            success: false,
            error_message: "Failed to parse response: #{e.message}"
          )
        end

        def fetch_google(_api_key)
          # Google Cloud Billing API requires:
          # 1. A GCP project with billing enabled
          # 2. OAuth2 credentials (not just an API key)
          # 3. Billing Account Viewer IAM role
          # This is significantly more complex than the standard Gemini API key
          BillingResult.new(
            provider: :google,
            success: false,
            error_message: 'Google Billing API requires OAuth2 credentials and GCP project setup. ' \
                           'Check usage at: https://console.cloud.google.com/billing'
          )
        end

        def make_request(uri, api_key)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = 10
          http.read_timeout = 30
          # Some environments have certificate verification issues
          # Users can set ORCHESTRA_SSL_VERIFY=false to disable (not recommended for production)
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE if ENV['ORCHESTRA_SSL_VERIFY'] == 'false'

          request = Net::HTTP::Get.new(uri)
          request['Authorization'] = "Bearer #{api_key}"
          request['Content-Type'] = 'application/json'

          http.request(request)
        end

        def make_anthropic_request(uri, api_key)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = 10
          http.read_timeout = 30
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE if ENV['ORCHESTRA_SSL_VERIFY'] == 'false'

          request = Net::HTTP::Get.new(uri)
          # Anthropic Admin API uses x-api-key header (not Bearer token)
          request['x-api-key'] = api_key
          request['anthropic-version'] = '2023-06-01'
          request['Content-Type'] = 'application/json'

          http.request(request)
        end

        def extract_openai_total_cost(data)
          return 0.0 unless data['data'].is_a?(Array)

          data['data'].sum do |bucket|
            next 0.0 unless bucket['results'].is_a?(Array)

            bucket['results'].sum do |result|
              amount = result.dig('amount', 'value')
              amount.is_a?(Numeric) ? amount : 0.0
            end
          end
        end

        def extract_openai_tokens(data)
          input_tokens = 0
          output_tokens = 0

          return { input: 0, output: 0, total: 0 } unless data['data'].is_a?(Array)

          data['data'].each do |bucket|
            next unless bucket['results'].is_a?(Array)

            bucket['results'].each do |result|
              input_tokens += result['input_tokens'].to_i
              output_tokens += result['output_tokens'].to_i
            end
          end

          { input: input_tokens, output: output_tokens, total: input_tokens + output_tokens }
        end

        def extract_anthropic_total_cost(data)
          # Anthropic cost API returns costs in cents as decimal strings
          return 0.0 unless data['data'].is_a?(Array)

          data['data'].sum do |bucket|
            # Cost is in cents, convert to dollars
            cost_cents = bucket['cost_usd_cents'].to_f
            cost_cents / 100.0
          end
        end

        def extract_anthropic_tokens(data)
          input_tokens = 0
          output_tokens = 0
          cached_input_tokens = 0
          cache_creation_tokens = 0

          return { input: 0, output: 0, cached_input: 0, cache_creation: 0, total: 0 } unless data['data'].is_a?(Array)

          data['data'].each do |bucket|
            input_tokens += bucket['input_tokens'].to_i
            output_tokens += bucket['output_tokens'].to_i
            cached_input_tokens += bucket['cache_read_input_tokens'].to_i
            cache_creation_tokens += bucket['cache_creation_input_tokens'].to_i
          end

          {
            input: input_tokens,
            output: output_tokens,
            cached_input: cached_input_tokens,
            cache_creation: cache_creation_tokens,
            total: input_tokens + output_tokens + cached_input_tokens + cache_creation_tokens
          }
        end
      end
    end
  end
end
