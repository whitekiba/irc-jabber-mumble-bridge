class BaseHelpers
end

class String
  def initial
    self[0,1]
  end
  def valid_url?(url)
    if url =~ URI::regexp
      true
    end
  end
end