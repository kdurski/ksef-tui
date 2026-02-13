namespace :TUI do
  desc "Run the KSeF TUI (usage: rake tui[profile_name])"
  task :run, [:profile] => :environment do |task, args|
    # Ensure standard output is not buffered
    $stdout.sync = true
    
    require "ksef/tui/runner"
    
    # Construct ARGV for the runner
    argv = []
    if args[:profile].present?
      argv.concat(["--profile", args[:profile]])
    elsif ENV["PROFILE"].present?
      argv.concat(["--profile", ENV["PROFILE"]])
    end

    # Run the TUI
    # We need to ensure we catch the interrupt to exit cleanly
    begin
      Ksef::Tui::Runner.run(argv)
    rescue Interrupt
      puts "\nExiting..."
    end
  end
end

desc "Alias for TUI:run"
task tui: "TUI:run"
