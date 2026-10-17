# frozen_string_literal: true

require_relative 'lib/dragonruby_tasks'

requested_tasks = Rake.application.top_level_tasks
# OptionParser leaves ARGV intact; -- separates engine flags from Rake flags.
engine_arguments = []
if requested_tasks.include?('run') && (separator = ARGV.index('--'))
  engine_arguments = ARGV[(separator + 1)..]
  engine_arguments.reverse_each do |argument|
    index = requested_tasks.rindex(argument)
    requested_tasks.delete_at(index) if index
  end
end

# Rake normally treats positional paths as task names. Consume only the path
# directly after run/test so commands such as `bin/rake test lint` still work.
paths = {}
{ 'run' => '.json', 'test' => '.rb' }.each do |command, extension|
  index = requested_tasks.index(command)
  next unless index

  candidate = requested_tasks[index + 1]
  paths[command] = requested_tasks.delete_at(index + 1) if candidate&.end_with?(extension)
end

desc 'Run the game (optional map path and additional DragonRuby arguments)'
task :run do
  map = paths['run']
  options = map ? ['--map', map] : []
  DragonRubyTasks.run(*(options + engine_arguments))
end

desc 'Run native tests (default: tests/all_test.rb; HEADLESS=1 on Linux)'
task :test do
  DragonRubyTasks.test(paths['test'] || 'tests/all_test.rb')
end

desc 'Lint project Ruby with RuboCop'
task :lint do
  ruby 'bin/rubocop', '--parallel'
end

desc 'Run lint and native tests'
task check: %i[lint test]

namespace :assets do
  desc 'Generate game occluder data (MAP=..., TOLERANCE=2, OUT=mygame/data)'
  task :occluders do
    require_relative 'lib/occluder_assets'

    map = ENV.fetch('MAP', 'mygame/tiled/ritual_gate.json')
    output = ENV.fetch('OUT', 'mygame/data')
    generator = OccluderAssets.new(tolerance: Float(ENV.fetch('TOLERANCE', '2')))
    generator.generate(map, output: output)
    puts "Generated #{output}/occluders.json"
  end

  desc 'Test asset generation (requires GEOS)'
  task :test do
    ruby 'test/occluder_assets_test.rb'
  end
end

task default: :check
