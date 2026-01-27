# frozen_string_literal: true

module OrchestraAI
  module Tasks
    class DifficultyScorer
      # Complexity indicators (keywords that suggest higher difficulty)
      COMPLEXITY_KEYWORDS = {
        high: %w[
          architecture design system distributed scalable
          security authentication authorization encryption
          optimization performance concurrent parallel async
          migrate refactor legacy integration
          machine learning neural network ai model training
          real-time streaming websocket
        ],
        medium: %w[
          api rest graphql database query
          test testing coverage validation
          cache caching session state
          error handling exception logging
          deploy deployment ci cd
          configuration environment
        ],
        low: %w[
          fix bug typo update change modify
          add simple basic create new
          readme documentation comment
          rename move copy
          format style lint
        ]
      }.freeze

      # Task length thresholds
      LENGTH_THRESHOLDS = {
        short: 50,   # < 50 chars
        medium: 200, # 50-200 chars
        long: 500    # > 200 chars
      }.freeze

      class << self
        # Score a task's difficulty from 0.0 (trivial) to 1.0 (very complex)
        # @param task [Tasks::Definition] The task to score
        # @return [Float] Difficulty score between 0.0 and 1.0
        def score(task)
          return task.difficulty if task.difficulty

          description = task.description.downcase
          scores = []

          # Keyword-based scoring
          scores << keyword_score(description)

          # Length-based scoring
          scores << length_score(description)

          # Context complexity (more context = more complex coordination)
          scores << context_score(task.context)

          # Combine scores with weights
          weighted_average(scores, weights: [0.5, 0.2, 0.3])
        end

        # Quick classification into tiers
        def classify(task)
          score = score(task)
          thresholds = OrchestraAI.configuration.config.difficulty

          if score < thresholds.simple_threshold
            :simple
          elsif score < thresholds.moderate_threshold
            :moderate
          else
            :complex
          end
        end

        private

        def keyword_score(description)
          words = description.split(/\W+/)

          high_count = count_matches(words, COMPLEXITY_KEYWORDS[:high])
          medium_count = count_matches(words, COMPLEXITY_KEYWORDS[:medium])
          low_count = count_matches(words, COMPLEXITY_KEYWORDS[:low])

          total = high_count + medium_count + low_count
          return 0.5 if total.zero? # Default to medium if no keywords match

          weighted_sum = (high_count * 1.0) + (medium_count * 0.5) + (low_count * 0.1)
          normalized = weighted_sum / total

          # Scale to 0-1 range
          [normalized, 1.0].min
        end

        def length_score(description)
          length = description.length

          if length < LENGTH_THRESHOLDS[:short]
            0.2
          elsif length < LENGTH_THRESHOLDS[:medium]
            0.4
          elsif length < LENGTH_THRESHOLDS[:long]
            0.6
          else
            0.8
          end
        end

        def context_score(context)
          return 0.0 if context.nil? || context.empty?

          # More context items = more complex coordination
          count = context.size
          total_length = context.sum { |c| c.to_s.length }

          item_score = [[count * 0.15, 0.5].min, 0.0].max
          length_score = [[total_length / 5000.0, 0.5].min, 0.0].max

          item_score + length_score
        end

        def count_matches(words, keywords)
          words.count { |word| keywords.any? { |kw| word.include?(kw) } }
        end

        def weighted_average(scores, weights:)
          total_weight = weights.sum
          weighted_sum = scores.zip(weights).sum { |score, weight| score * weight }
          weighted_sum / total_weight
        end
      end
    end
  end
end
