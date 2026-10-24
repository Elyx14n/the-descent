# frozen_string_literal: true

require 'open3'

# Development commands run in desktop Ruby; game code runs in DragonRuby.
module DragonRubyTasks
  ROOT = File.expand_path('..', __dir__)
  GAME = File.join(ROOT, 'mygame')
  RESULTS = /DESCENT_TEST_RESULTS expected=(\d+) passed=(\d+) failed=(\d+) inconclusive=(\d+) focused=(\d+)/

  class << self
    def run(path = nil, *arguments)
      sdk, executable = installation
      setup_editor_link(sdk)
      game = GAME
      if path&.end_with?('.json')
        arguments.unshift('--map', path)
      elsif path
        game = File.expand_path(path, ROOT)
      end
      abort "Game entry point not found: #{game}/app/main.rb" unless File.file?(File.join(game, 'app/main.rb'))

      success = system(executable, game, *arguments, chdir: sdk)
      abort 'DragonRuby exited unsuccessfully.' unless success
    end

    def test(path)
      abort "Test file does not exist: #{path}" unless File.file?(File.join(GAME, path))

      sdk, executable = installation
      setup_editor_link(sdk)
      results = []
      arguments = [executable, GAME, '--eval', 'tests/run.rb', '--no-tick', '--test-file', path]
      Open3.popen2e(test_environment, *arguments, chdir: sdk) do |stdin, output, process|
        stdin.close
        output.each_line do |line|
          print line
          match = RESULTS.match(line)
          results << match.captures.map(&:to_i) if match
        end
        abort 'DragonRuby exited unsuccessfully.' unless process.value.success?
      end
      abort 'Native tests did not finish with one result report; inspect the output above.' unless results.length == 1

      expected, passed, failed, inconclusive, focused = results.first
      abort 'No native tests were found.' if expected.zero?
      abort 'Native test execution was incomplete.' unless passed + failed + inconclusive == expected
      unless failed.zero? && inconclusive.zero?
        abort "Native tests failed: #{failed} failed, #{inconclusive} inconclusive."
      end
      abort 'Focused tests are not allowed in CI; remove focus_test_ methods.' if ci? && focused.positive?

      warn 'Focused tests ran; the rest of the selected suite was skipped.' if focused.positive?
    end

    private

    def ci?
      value = ENV.fetch('CI', '')
      !value.empty? && !%w[false 0].include?(value.downcase)
    end

    def installation
      sdk_home = ENV.fetch('DRAGONRUBY_HOME', nil)
      if sdk_home.nil? || sdk_home.strip.empty?
        abort 'Set DRAGONRUBY_HOME to your extracted Linux or macOS DragonRuby SDK directory.'
      end
      abort "DragonRuby SDK directory not found: #{sdk_home}" unless File.directory?(sdk_home)
      sdk = File.realpath(sdk_home)
      executable = File.join(sdk, 'dragonruby')
      abort "DragonRuby executable not found: #{executable}" unless File.file?(executable)
      unless File.executable?(executable)
        abort "DragonRuby is not executable: #{executable}. Give your SDK executable permission before launching."
      end
      [sdk, executable]
    end

    def test_environment
      return {} unless RUBY_PLATFORM.include?('linux') && (ENV['HEADLESS'] == '1' || ci?)

      { 'SDL_VIDEODRIVER' => ENV.fetch('SDL_VIDEODRIVER', 'offscreen'),
        'SDL_AUDIODRIVER' => ENV.fetch('SDL_AUDIODRIVER', 'dummy'),
        'LIBGL_ALWAYS_SOFTWARE' => ENV.fetch('LIBGL_ALWAYS_SOFTWARE', '1') }
    end

    def setup_editor_link(sdk)
      link = File.join(ROOT, '.dragonruby-lsp')
      unless File.directory?(File.join(sdk, 'docs/oss'))
        warn 'SDK docs/oss is missing; DragonRuby editor indexing is unavailable.'
        return
      end
      if File.symlink?(link)
        return if File.directory?(link) && File.realpath(link) == sdk

        File.unlink(link)
      elsif File.exist?(link)
        warn "#{link} is not a link; leaving it untouched."
        return
      end
      File.symlink(sdk, link)
    rescue SystemCallError => e
      warn "Could not set up DragonRuby editor indexing; continuing to launch. #{e.message}"
    end
  end
end
