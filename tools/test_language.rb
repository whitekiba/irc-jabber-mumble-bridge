require_relative '../lib/language'

@lang = Language.new
puts @lang.get('non_existing')
