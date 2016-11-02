#Eine Hilfsklasse für das Logging und verarbeiten von Exceptions.
# Es werden einfach Exceptions an new_exception übergeben und der kümmert sich um alles
# Optional kann mit poll_for_limit ein Thread gestartet werden welcher nach 5 Excepeptions in Folge alles abwürgt.
# Das abwürgen dient dem verhindern von dauerhaften Blocks die wir nicht sicher erkennen können
# üblicherweise nutzen wir poll_for_limit für Gems welche keine brauchbaren Exceptions werfen
# oder aber noch nicht sauber alles abfangen
class ExceptionHelper
  attr_writer :exception_limit
  def initialize
    reset_counter #auf 0 setzen
    @exception_limit = 5
  end

  def new_exception(e)
    #TODO: Hier sollte noch Code hin um Exceptions zu loggen und evtl. in InfluxDB zu schreiben
    @num_exceptions += 1
  end

  def reset_counter
    @num_exceptions = 0
  end

  #startet einen thread welcher prüft wie viele exceptions seit dem letzten reset auftraten
  #falls wir tatsächlich zu viele exceptions haben müssen wir den prozess abwürgen
  def poll_for_limit
    Thread.new do
      loop do
        sleep 15
        abort if @num_exceptions > @exception_limit
      end
    end
  end
end