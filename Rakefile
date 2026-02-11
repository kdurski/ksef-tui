# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

desc "Run the TUI (use PROFILE=<name> or rake tui[<name>] to select profile)"
task :tui, [:profile] do |_task, args|
  require_relative "lib/ksef/tui/runner"

  profile = args[:profile] || ENV["PROFILE"]
  argv = []
  argv.concat(["--profile", profile]) if profile && !profile.strip.empty?

  Ksef::Tui::Runner.run(argv)
end

task default: :test
