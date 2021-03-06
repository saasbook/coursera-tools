require 'tempfile'
require 'open3'
require 'timeout'

require_relative 'rag_logger'

module AutoGraderSubprocess
  extend RagLogger
  class AutoGraderSubprocess::OutputParseError < StandardError ; end
  class AutoGraderSubprocess::SubprocessError < StandardError ; end

  # FIXME: This is a hack, remove later
  # This, and run_autograder, should really be part of a different module/class
  # Runs a separate process for grading
  def self.run_autograder_subprocess(submission, opts)
    stdout_text = stderr_text = nil
    exitstatus = 0
    Tempfile.open(['test', '.rb']) do |file|
      file.write(submission)
      file.flush

      raise "No command specified for assignment" if opts[:cmd].nil?

      opts[:cmd].gsub!(/%/, file.path)

      begin
        Timeout::timeout(opts[:timeout]) do
          Open3.popen3 opts[:cmd] do |stdin, stdout, stderr, wait_thr|
            #if grader_type == 'ManualGrader'
            #  # FIXME: This is really hacky
            #  last_iteration = true
            #  while (thread_alive = wait_thr.alive?) or last_iteration
            #    begin
            #      stdout_text = stdout.read_nonblock 1024
            #    rescue Errno::EAGAIN => e
            #    else
            #      print stdout_text
            #    end

            #    begin
            #      stdin_text = STDIN.read_nonblock 1024
            #    rescue Errno::EAGAIN => e
            #    else
            #      stdin.write(stdin_text)
            #    end
            #    sleep(0.05)
            #    last_iteration = false unless thread_alive
            #  end
            #else
              stdout_text = stdout.read; stderr_text = stderr.read
              stdin.close; stdout.close; stderr.close
              exitstatus = wait_thr.value.exitstatus
            #end
          end
        end
      rescue Timeout::Error => e
        exitstatus = -1
        stderr_text = "Program timed out"
      end

      if exitstatus != 0
        logger.fatal "AutograderSubprocess error: #{stderr_text}"
        raise AutoGraderSubprocess::SubprocessError, "AutograderSubprocess error: #{stderr_text}"
      end
    end
    score, comments = parse_grade(stdout_text)
    comments.gsub!(spec, 'spec.rb')
    [score, comments]
  rescue ArgumentError => e
    logger.error e.to_s
    score = 0
    comments = e.to_s
    [score, comments]
  end

  def run_autograder_subprocess(submission, grader_opts)
    AutoGraderSubprocess.run_autograder_subprocess(submission, grader_opts)
  end

  # FIXME: This is related to the below hack, remove later
  def self.parse_grade(str)
    # Used for parsing the stdout output from running grade as a shell command
    # FIXME: This feels insecure and fragile
    score_regex = /Score out of \d+:\s*(\d+(?:\.\d+)?)$/
    score = str.match(score_regex, str.rindex(score_regex))[1].to_f
    comments = str.match(/^---BEGIN (?:cucumber|rspec|grader) comments---\n#{'-'*80}\n(.*)#{'-'*80}\n---END (?:cucumber|rspec|grader) comments---$/m)[1]
    comments = comments.split("\n").map do |line|
      line.gsub(/\(FAILED - \d+\)/, "(FAILED)")
    end.join("\n")
    [score, comments]
  rescue ArgumentError => e
    logger.error "Error running parse_grade: #{e.to_s}; #{str}"
    [0, e.to_s]
  rescue StandardError => e
    logger.fatal "Failed to parse autograder output: #{str}"
    raise OutputParseError, "Failed to parse autograder output: #{str}"
  end

  def parse_grade(str)
    AutoGraderSubprocess.parse_grade(str)
  end
end
