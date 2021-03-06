module Yast
  module Y2StartHelpers

    # Parses ARGV of y2start. it returns map with keys:
    #
    # - :generic_options [Hash]
    # - :client_name [String]
    # - :client_options [Hash] always contains `params:` with Array of client arguments
    # - :server_name [String]
    # - :server_options [Array] ( of unparsed options as server parse it on its own)
    # @raise RuntimeError when unknown option appear or used wrongly
    def self.parse_arguments(args)
      ret = {}

      ret[:generic_options] = parse_generic_options(args)
      # for --help early quit as other argument are ignored
      return ret if ret[:generic_options][:help]
      ret[:client_name] = args.shift or raise "Missing client name."
      ret[:client_options] = parse_client_options(args)
      ret[:server_name] = args.shift or raise "Missing server name."
      ret[:server_options] = args

      ret
    end

    def self.help
      "Usage: y2start [GenericOpts] Client [ClientOpts] Server " \
      "[Specific ServerOpts]\n" \
      "\n" \
      "GenericOptions are:\n" \
      "    -h --help         : Sprint this help\n" \
      "\n" \
      "ClientOptions are:\n" \
      "    -a --arg          : add argument for client. Can be used multiple times.\n" \
      "\n" \
      "Specific ServerOptions are any options passed on unevaluated.\n" \
      "\n" \
      "Examples:\n" \
      "y2start installation qt\n" \
      "    Start binary y2start with intallation.ycp as client and qt as server\n" \
      "y2start installation -a initial qt\n" \
      "    Provide parameter initial for client installation\n" \
      "y2start installation qt -geometry 800x600\n" \
      "    Provide geometry information as specific server options\n"
    end

    # so how works signals in ruby version?
    # It logs what we know about signal and then continue with standard ruby
    # handler, which raises {SignalException} that can be processed. If it is
    # not catched, it show popup asking for report bug.
    def self.setup_signals
      Signal.trap("PIPE", "IGNORE")

      # SEGV, ILL and FPE is reserved, so cannot be set
      ["HUP", "INT", "QUIT", "ABRT", "TERM"].each do |name|
        Signal.trap(name) { signal_handler(name) }
      end
    end

    private_class_method def self.signal_handler(name)
      Signal.trap(name, "IGNORE")

      $stderr.puts "YaST got signal #{name}."

      signal_log_open do |f|
        f.puts "=== #{Time.now} ==="
        f.puts "YaST got signal #{name}."
        # TODO: print stored debug logs
        f.puts "Backtrace (only ruby one):"
        caller.each { |l| f.puts(l) }
      end

      system("/usr/lib/YaST2/bin/signal-postmortem")

      Signal.trap(name, "DEFAULT")
      Process.kill(name, Process.pid)
    end

    LOG_LOCATIONS = ["/var/log/YaST2/signal", "y2signal.log"]
    private_class_method def self.signal_log_open(&block)
      index = 0
      begin
        path = LOG_LOCATIONS[index]
        return unless path
        File.open(path, "a") { |f| block.call(f) }
      rescue IOError, SystemCallError
        index +=1
        retry
      end
    end

    private_class_method def self.parse_generic_options(args)
      res = {}
      loop do
        return res unless option?(args.first)


        arg = args.shift
        case arg
        when "-h", "--help"
          res[:help] = true
        else
          raise "Unknown option #{args.first}"
        end
      end
    end

    private_class_method def self.parse_client_options(args)
      res = {}
      res[:params] = []
      loop do
        return res unless option?(args.first)

        arg = args.shift
        case arg
        when "-a", "--arg"
          param = args.shift
          raise "Missing argument for --arg" unless param

          res[:params] << param
        else
          raise "Unknown option #{arg}"
        end
      end
    end

    private_class_method def self.option?(arg)
      return false unless arg
      return true if arg[0] == "-"

      return false
    end
  end
end
