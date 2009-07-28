task :git_commands do
  module GitCommands
    require "colored"
    class ShellError < RuntimeError; end

    @logging = ENV['LOGGING'] != "false"

    def self.run(cmd, *expected_exitstatuses)
      log_output("+ #{cmd}", :bold, :green)

      output = `#{cmd} 2>&1`

      log_output(output, :strip, lambda {|s| s.gsub(/^/, "  ") }, :bold, :yellow)
      log_output("\n")

      expected_exitstatuses << 0 if expected_exitstatuses.empty?

      unless [expected_exitstatuses].flatten.include?( $?.exitstatus )
        raise ShellError.new("ERROR: '#{cmd}' failed with exit status #{$?.exitstatus}")
      end

      output
    end

    def self.current_branch
      run("git branch --no-color | grep '*' | cut -d ' ' -f 2").chomp
    end

    def self.remote_branch_exists?(branch)
      ! run("git branch -r --no-color | grep '#{branch}'").blank?
    end

    def self.ensure_clean_working_directory!
      return if run("git status", 0, 1).match(/working directory clean/)
      raise "Must have clean working directory"
    end

    def self.diff_staging
      run("git diff HEAD origin/staging")
    end

    def self.diff_production
      run("git diff origin/staging origin/production")
    end

    def self.push(src_branch, dst_branch)
      raise "origin/#{dst_branch} branch does not exist" unless remote_branch_exists?("origin/#{dst_branch}")
      ensure_clean_working_directory!
      begin
        run "git fetch"
        run "git push -f origin #{src_branch}:#{dst_branch}"
      rescue
        log_output("  Pushing #{src_branch} to origin/#{dst_branch} failed.", true, :bold, :red)
        raise
      end
    end

    def self.push_staging
      push(current_branch, "staging")
    end

    def self.push_production
      push("origin/staging", "production")
    end

    def self.branch_production(branch)
      raise "You must specify a branch name." if branch.blank?
      ensure_clean_working_directory!
      run "git fetch"
      run "git branch -f #{branch} origin/production"
      run "git checkout #{branch}"
    end

    def self.pull_template
      ensure_clean_working_directory!
      run "git pull git://github.com/thoughtbot/suspenders.git master"
    end

    private

    def self.log_output(string, *args)
      logging = args.shift if args.first === true
      return unless @logging || logging
      args.each do |arg|
        string = if arg.respond_to?(:call)
                   arg.call(string)
                 else
                   string.send(arg)
                 end
      end
      puts string unless string.strip.blank?
    end
  end
end

namespace :git do
  namespace :push do
    desc "Reset origin's staging branch to be the current branch."
    task :staging => :git_commands do
      GitCommands.push_staging
    end

    desc "Reset origin's production branch to origin's staging branch."
    task :production => :git_commands do
      GitCommands.push_production
    end
  end

  namespace :diff do
    desc "Show the difference between current branch and origin/staging."
    task :staging => :git_commands do
      GitCommands.diff_staging
    end

    desc "Show the difference between origin/staging and origin/production."
    task :production => :git_commands do
      GitCommands.diff_production
    end
  end

  namespace :pull do
    desc "Pull updates from suspenders, the thoughtbot rails template."
    task :suspenders => :git_commands do
      GitCommands.pull_template
    end
  end

  namespace :branch do
    desc "Branch origin/production into BRANCH locally."
    task :production => :git_commands do
      GitCommands.branch_production(branch)
    end
  end
end

