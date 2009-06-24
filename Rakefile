require 'starling'

module StarlingUtils
  def self.running?
    config = YAML.load_file("#{File.dirname(__FILE__)}/config/apns.yml")
    pid_file = "#{File.dirname(__FILE__)}/tmp/starling/starling.pid"
    if File.exist?(pid_file)
      Process.getpgid(File.read(pid_file).to_i) rescue return false
    else
      return false
    end
  end
end

namespace :starling do
 
  desc "Start starling server"
  task :start do
    config = YAML.load_file("#{File.dirname(__FILE__)}/config/apns.yml")
    pid_file = "#{File.dirname(__FILE__)}/tmp/starling/starling.pid"
    unless StarlingUtils.running?
      host, port = config['starling_addr'].split(':')
      starling_binary = `which starling`.strip
      raise RuntimeError, "Cannot find starling" if starling_binary.empty?
      options = []
      options << "--queue_path #{File.dirname(__FILE__)}/tmp/starling/"
      options << "--host 0.0.0.0"
      options << "--port #{port}"
      options << "-d"
      options << "--pid #{pid_file}"
      # options << "--syslog #{config['syslog_channel']}"
      # options << "--timeout #{config['timeout']}"
      STDERR.puts("Launching Starling")
      system "#{starling_binary} #{options.join(' ')}"
    else
      STDERR.puts("Starling is already running")
    end
  end
 
  desc "Stop starling server"
  task :stop do
    config = YAML.load_file("#{File.dirname(__FILE__)}/config/apns.yml")
    pid_file = "#{File.dirname(__FILE__)}/tmp/starling/starling.pid"
    if File.exist?(pid_file)
      system "kill -9 `cat #{pid_file}`"
      STDERR.puts("Starling successfully stopped")
      File.delete(pid_file)
    else
      STDERR.puts("No Starling PID file")
    end
  end
  
  desc "Restart starling server"
  task :restart => ["stop", "start"]
end