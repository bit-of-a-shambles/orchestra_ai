# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'open3'
require 'shellwords'
require 'timeout'

module OrchestraAI
  module Development
    class Toolchain
      CODE_KEYWORDS = %w[
        code implement implementation refactor bug fix test testing
        function method class module api endpoint migration schema
        database sql ruby javascript typescript python cli
      ].freeze

      class << self
        def try_local_cli(task:, role:)
          config = OrchestraAI.configuration.development
          return nil unless config.enabled && config.coding_cli_enabled
          return nil unless config.role_enabled?(role)
          return nil unless code_task?(task)

          cli = first_available_cli(config.coding_cli_order)
          return nil unless cli

          prompt = local_cli_prompt(task, role)
          command = cli_command(cli, prompt)
          return nil unless command

          stdout, stderr, status = Timeout.timeout(config.coding_cli_timeout) do
            Open3.capture3(*command)
          end
          return nil unless status.success?

          output = stdout.to_s.strip
          return nil if output.empty?

          Tasks::Result.new(
            content: output,
            task: task,
            agent: role,
            model: "local-cli:#{cli}",
            usage: {},
            metadata: {
              provider: :local_cli,
              cli: cli,
              stderr: stderr.to_s.strip,
              timestamp: Time.now.utc
            }
          )
        rescue StandardError => e
          OrchestraAI.logger&.warn("[OrchestraAI] Local CLI fallback failed: #{e.message}")
          nil
        end

        def mcp_context(task:, workdir: Dir.pwd)
          config = OrchestraAI.configuration.development
          return nil unless config.enabled && config.mcp_enabled
          return nil if config.mcp_context_command.to_s.strip.empty?

          escaped_task = Shellwords.escape(task.description.to_s)
          command = config.mcp_context_command.gsub('%TASK%', escaped_task)
          stdout, _stderr, status = Timeout.timeout(config.mcp_timeout) do
            Open3.capture3('sh', '-lc', command, chdir: workdir)
          end
          return nil unless status.success?

          body = stdout.to_s.strip
          return nil if body.empty?

          truncate(body, config.mcp_context_max_chars)
        rescue StandardError => e
          OrchestraAI.logger&.warn("[OrchestraAI] MCP context fetch failed: #{e.message}")
          nil
        end

        def copilot_instructions(workdir: Dir.pwd)
          config = OrchestraAI.configuration.development
          return nil unless config.enabled && config.copilot_instructions_enabled

          path = File.expand_path(config.copilot_instructions_path, workdir)
          return nil unless File.exist?(path)

          content = File.read(path)
          return nil if content.strip.empty?

          truncate(content, config.copilot_instructions_max_chars)
        rescue StandardError => e
          OrchestraAI.logger&.warn("[OrchestraAI] Copilot instructions load failed: #{e.message}")
          nil
        end

        def status_report(workdir: Dir.pwd)
          config = OrchestraAI.configuration.development
          available = detect_available_clis(config.coding_cli_order)
          copilot_path = File.expand_path(config.copilot_instructions_path, workdir)

          {
            enabled: config.enabled,
            coding_cli_enabled: config.coding_cli_enabled,
            mcp_enabled: config.mcp_enabled,
            copilot_instructions_enabled: config.copilot_instructions_enabled,
            mcporter_available: command_available?('mcporter'),
            available_clis: available[:available],
            missing_clis: available[:missing],
            copilot_path: copilot_path,
            copilot_present: File.exist?(copilot_path),
            mcp_command_configured: !config.mcp_context_command.to_s.strip.empty?
          }
        end

        def bootstrap!(workdir: Dir.pwd)
          created = []
          mcp_file = File.join(workdir, '.mcp.json')
          copilot_file = File.expand_path(
            OrchestraAI.configuration.development.copilot_instructions_path,
            workdir
          )

          unless File.exist?(mcp_file)
            File.write(mcp_file, JSON.pretty_generate(default_mcp_config))
            created << mcp_file
          end

          unless File.exist?(copilot_file)
            FileUtils.mkdir_p(File.dirname(copilot_file))
            File.write(copilot_file, default_copilot_instructions)
            created << copilot_file
          end

          created
        end

        def code_task?(task)
          text = task.description.to_s.downcase
          CODE_KEYWORDS.any? { |keyword| text.include?(keyword) }
        end

        private

        def truncate(text, max_chars)
          return text if text.length <= max_chars

          "#{text[0, max_chars]}\n\n[truncated by OrchestraAI]"
        end

        def first_available_cli(order)
          detect_available_clis(order)[:available].first
        end

        def detect_available_clis(order)
          available = []
          missing = []

          order.each do |cli|
            if command_available?(cli)
              available << cli
            else
              missing << cli
            end
          end

          { available: available, missing: missing }
        end

        def command_available?(command)
          ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? do |path|
            full_path = File.join(path, command)
            File.file?(full_path) && File.executable?(full_path)
          end
        end

        def cli_command(cli, prompt)
          case cli
          when 'codex' then ['codex', 'exec', '--full-auto', prompt]
          when 'opencode' then ['opencode', 'run', prompt]
          when 'pi' then ['pi', '-p', prompt]
          when 'claude' then ['claude', '-p', prompt]
          end
        end

        def local_cli_prompt(task, role)
          <<~PROMPT
            You are acting as the #{role} agent.
            Complete the following development task and return only the final answer:
            #{task.description}
          PROMPT
        end

        def default_mcp_config
          {
            'mcpServers' => {
              'filesystem' => {
                'command' => 'npx',
                'args' => ['-y', '@modelcontextprotocol/server-filesystem', '.']
              },
              'git' => {
                'command' => 'npx',
                'args' => ['-y', '@modelcontextprotocol/server-git']
              },
              'github' => {
                'command' => 'npx',
                'args' => ['-y', '@modelcontextprotocol/server-github'],
                'env' => {
                  'GITHUB_TOKEN' => '${GITHUB_TOKEN}'
                }
              }
            }
          }
        end

        def default_copilot_instructions
          <<~MD
            # Copilot Instructions For OrchestraAI

            - Prefer short diffs and focused edits over large rewrites.
            - Use existing architecture and naming in this repository.
            - Before generating code, inspect existing files and tests.
            - For coding tasks, prefer local CLI tooling and MCP context where available.
            - Include or update tests for behavior changes.
            - Keep outputs concise and production-ready.
          MD
        end
      end
    end
  end
end
