require 'childprocess'

$logger = Logger.new(File.dirname(__FILE__) + '/bridge.log')
class AssistantManager
  def startAssistants
    @assistants = ['telegram']

    @assistants.each { |proto|
      @assistants[proto] = ChildProcess.build('ruby', "protocols/#{proto}_assistant.rb")
      @assistants[proto].start
    }
  end
  def monitorAssistants
    loop do
      begin
        @assistants.each_key { |proc|
          if @assistants[proc].exited?
            puts "#{proc} started or restarted."
            @assistants[proc].start
          end
        }
        sleep 1
      rescue StandardError => e
        $logger.error e
      end
    end
  end
end

a = AssistantManager.new
a.startAssistants
a.monitorAssistants