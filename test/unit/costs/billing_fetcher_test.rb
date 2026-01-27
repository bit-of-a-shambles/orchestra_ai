# frozen_string_literal: true

require 'test_helper'
require 'webmock/minitest'

module OrchestraAI
  module Costs
    class BillingFetcherTest < Minitest::Test
      def setup
        WebMock.disable_net_connect!
      end

      def teardown
        WebMock.allow_net_connect!
      end

      # -- BillingResult tests --

      def test_billing_result_success_predicate
        result = BillingFetcher::BillingResult.new(
          provider: :openai,
          success: true,
          usage_data: { cost_this_month: 5.0 }
        )
        assert result.success?
      end

      def test_billing_result_failure_predicate
        result = BillingFetcher::BillingResult.new(
          provider: :openai,
          success: false,
          error_message: 'API error'
        )
        refute result.success?
      end

      def test_billing_result_cost_this_month
        result = BillingFetcher::BillingResult.new(
          provider: :openai,
          success: true,
          usage_data: { cost_this_month: 12.50 }
        )
        assert_equal 12.50, result.cost_this_month
      end

      def test_billing_result_cost_this_month_returns_nil_on_failure
        result = BillingFetcher::BillingResult.new(
          provider: :openai,
          success: false,
          error_message: 'error'
        )
        assert_nil result.cost_this_month
      end

      def test_billing_result_total_tokens
        result = BillingFetcher::BillingResult.new(
          provider: :openai,
          success: true,
          usage_data: { total_tokens: 100_000 }
        )
        assert_equal 100_000, result.total_tokens
      end

      # -- fetch_all tests --

      def test_fetch_all_returns_results_for_all_providers
        stub_openai_costs_api(success: false, code: '403')
        stub_openai_usage_api(success: false, code: '403')
        stub_anthropic_cost_api(success: false, code: '401')
        stub_anthropic_usage_api(success: false, code: '401')

        results = BillingFetcher.fetch_all(
          openai: 'test-key',
          anthropic: 'test-key',
          google: 'test-key'
        )

        assert_equal %i[anthropic openai google], results.keys
        assert(results.values.all? { |r| r.is_a?(BillingFetcher::BillingResult) })
      end

      def test_fetch_all_handles_missing_api_keys
        # Ensure no ENV keys are set that could provide fallback
        original_openai_admin = ENV['OPENAI_ADMIN_KEY']
        original_anthropic_admin = ENV['ANTHROPIC_ADMIN_KEY']
        ENV.delete('OPENAI_ADMIN_KEY')
        ENV.delete('ANTHROPIC_ADMIN_KEY')

        results = BillingFetcher.fetch_all({})

        results.each do |provider, result|
          refute result.success?, "Expected #{provider} to fail without API key"
          # All providers should fail without API keys
          assert result.error_message, "Expected #{provider} to have an error message"
        end
      ensure
        ENV['OPENAI_ADMIN_KEY'] = original_openai_admin if original_openai_admin
        ENV['ANTHROPIC_ADMIN_KEY'] = original_anthropic_admin if original_anthropic_admin
      end

      # -- OpenAI fetch tests --

      def test_fetch_openai_with_costs_api_success
        stub_openai_costs_api(success: true, cost: 15.25)

        result = BillingFetcher.fetch(:openai, 'test-key')

        assert result.success?
        assert_equal 15.25, result.cost_this_month
        assert_equal 'usd', result.usage_data[:currency]
      end

      def test_fetch_openai_falls_back_to_usage_api
        stub_openai_costs_api(success: false, code: '403')
        stub_openai_usage_api(success: true, input_tokens: 50_000, output_tokens: 10_000)

        result = BillingFetcher.fetch(:openai, 'test-key')

        assert result.success?
        assert_equal 60_000, result.total_tokens
        assert_equal 50_000, result.usage_data[:input_tokens]
        assert_equal 10_000, result.usage_data[:output_tokens]
      end

      def test_fetch_openai_both_apis_fail
        stub_openai_costs_api(success: false, code: '403')
        stub_openai_usage_api(success: false, code: '403')

        result = BillingFetcher.fetch(:openai, 'test-key')

        refute result.success?
        assert_match(/admin key/, result.error_message)
        assert_match(/OPENAI_ADMIN_KEY/, result.error_message)
      end

      def test_fetch_openai_without_api_key
        result = BillingFetcher.fetch(:openai, nil)

        refute result.success?
        assert_match(/No API key configured/, result.error_message)
      end

      # -- Anthropic fetch tests --

      def test_fetch_anthropic_with_cost_api_success
        stub_anthropic_cost_api(success: true, cost_cents: 1525)

        result = BillingFetcher.fetch(:anthropic, 'sk-ant-admin-test-key')

        assert result.success?
        assert_in_delta 15.25, result.cost_this_month, 0.01
        assert_equal 'usd', result.usage_data[:currency]
      end

      def test_fetch_anthropic_falls_back_to_usage_api
        stub_anthropic_cost_api(success: false, code: '401')
        stub_anthropic_usage_api(success: true, input_tokens: 50_000, output_tokens: 10_000)

        result = BillingFetcher.fetch(:anthropic, 'sk-ant-admin-test-key')

        assert result.success?
        assert_equal 60_000, result.total_tokens
        assert_equal 50_000, result.usage_data[:input_tokens]
        assert_equal 10_000, result.usage_data[:output_tokens]
      end

      def test_fetch_anthropic_with_cached_tokens
        stub_anthropic_cost_api(success: false, code: '401')
        stub_anthropic_usage_api(
          success: true,
          input_tokens: 50_000,
          output_tokens: 10_000,
          cached_input_tokens: 5_000,
          cache_creation_tokens: 2_000
        )

        result = BillingFetcher.fetch(:anthropic, 'sk-ant-admin-test-key')

        assert result.success?
        assert_equal 67_000, result.total_tokens
        assert_equal 5_000, result.usage_data[:cached_input_tokens]
        assert_equal 2_000, result.usage_data[:cache_creation_tokens]
      end

      def test_fetch_anthropic_both_apis_fail
        stub_anthropic_cost_api(success: false, code: '401')
        stub_anthropic_usage_api(success: false, code: '401')

        result = BillingFetcher.fetch(:anthropic, 'test-key')

        refute result.success?
        assert_match(/admin key/, result.error_message)
        assert_match(/ANTHROPIC_ADMIN_KEY/, result.error_message)
      end

      def test_fetch_anthropic_without_api_key
        result = BillingFetcher.fetch(:anthropic, nil)

        refute result.success?
        assert_match(/No API key configured/, result.error_message)
      end

      # -- Google fetch tests --

      def test_fetch_google_returns_informative_message
        result = BillingFetcher.fetch(:google, 'test-key')

        refute result.success?
        assert_match(/OAuth2 credentials/, result.error_message)
        assert_match(/console\.cloud\.google\.com/, result.error_message)
      end

      # -- Unknown provider tests --

      def test_fetch_unknown_provider
        result = BillingFetcher.fetch(:unknown, 'test-key')

        refute result.success?
        assert_match(/Unknown provider/, result.error_message)
      end

      # -- Error handling tests --

      def test_fetch_handles_network_errors
        stub_request(:get, /api\.openai\.com.*costs/)
          .to_timeout

        result = BillingFetcher.fetch(:openai, 'test-key')

        refute result.success?
        assert_match(/Net::OpenTimeout|execution expired/i, result.error_message)
      end

      def test_fetch_handles_invalid_json_response
        stub_request(:get, /api\.openai\.com.*costs/)
          .to_return(status: 200, body: 'not json', headers: { 'Content-Type' => 'application/json' })

        # When costs API returns invalid JSON, it falls back to usage API
        stub_request(:get, /api\.openai\.com.*completions/)
          .to_return(status: 200, body: 'also not json', headers: { 'Content-Type' => 'application/json' })

        result = BillingFetcher.fetch(:openai, 'test-key')

        # Both APIs failed, so we get the helpful admin key message
        refute result.success?
        assert_match(/admin key|Failed to parse/, result.error_message)
      end

      private

      def stub_openai_costs_api(success:, cost: nil, code: '200')
        body = if success
                 {
                   object: 'page',
                   data: [
                     {
                       object: 'bucket',
                       results: [{ amount: { value: cost, currency: 'usd' } }]
                     }
                   ]
                 }.to_json
               else
                 { error: { message: 'Forbidden' } }.to_json
               end

        status = success ? 200 : code.to_i

        stub_request(:get, /api\.openai\.com.*costs/)
          .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
      end

      def stub_openai_usage_api(success:, input_tokens: 0, output_tokens: 0, code: '200')
        body = if success
                 {
                   object: 'page',
                   data: [
                     {
                       object: 'bucket',
                       results: [{ input_tokens: input_tokens, output_tokens: output_tokens }]
                     }
                   ]
                 }.to_json
               else
                 { error: { message: 'Unauthorized' } }.to_json
               end

        status = success ? 200 : code.to_i

        stub_request(:get, /api\.openai\.com.*completions/)
          .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
      end

      def stub_anthropic_cost_api(success:, cost_cents: nil, code: '200')
        body = if success
                 {
                   object: 'page',
                   data: [
                     { cost_usd_cents: cost_cents.to_s }
                   ],
                   has_more: false
                 }.to_json
               else
                 { error: { message: 'Unauthorized' } }.to_json
               end

        status = success ? 200 : code.to_i

        stub_request(:get, /api\.anthropic\.com.*cost_report/)
          .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
      end

      def stub_anthropic_usage_api(success:, input_tokens: 0, output_tokens: 0, cached_input_tokens: 0,
                                   cache_creation_tokens: 0, code: '200')
        body = if success
                 {
                   object: 'page',
                   data: [
                     {
                       input_tokens: input_tokens,
                       output_tokens: output_tokens,
                       cache_read_input_tokens: cached_input_tokens,
                       cache_creation_input_tokens: cache_creation_tokens
                     }
                   ],
                   has_more: false
                 }.to_json
               else
                 { error: { message: 'Unauthorized' } }.to_json
               end

        status = success ? 200 : code.to_i

        stub_request(:get, /api\.anthropic\.com.*usage_report/)
          .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
      end
    end
  end
end
