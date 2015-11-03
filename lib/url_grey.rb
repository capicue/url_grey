require "url_grey/version"

class URLGrey
  attr_accessor :original, :coerced
  attr_accessor :scheme, :username, :password, :host, :port, :path, :query, :ref

  def initialize(_original)
    self.original = _original.gsub(%r{\s}, '')

    parse!
  end

  def parts
    {
      scheme:   self.scheme,
      username: self.username,
      password: self.password,
      host:     self.host,
      port:     self.port,
      path:     self.path,
      query:    self.query,
      ref:      self.ref
    }
  end

  private

  def parse!
    parse_scheme!
    after_scheme = self.coerced.match(%r{:(.*)})[1]
    _, after_slashes = after_scheme.match(%r{^([\\\/]*)(.*)$})[1..2]

    # authority terminators: '/', '\', '?', '#'
    if (after_slashes.chars & ['/', '\\', '?', '#']).any?
      authority, full_path = after_slashes.match(%r{^(.*?)([\\\/?#].*)$})[1..2]
    else
      authority = after_slashes
      full_path = ""
    end

    if authority.include?("@")
      user_info, server_info = authority.match(%r{^(.*)@(.*)$})[1..2]
    else
      user_info   = ""
      server_info = authority
    end

    # parse user_info
    if user_info.empty?
      self.username = ""
      self.password = ""
    else
      if user_info.include?(":")
        self.username, self.password = user_info.match(%r{^(.*?):(.*)$})[1..2]
      else
        self.username = user_info
        self.password = ""
      end
    end

    # parse server_info
    if !server_info.include?(":")
      self.host = server_info
      self.port = ""
    elsif server_info.include?("]")
      if server_info.reverse.index(":") < server_info.reverse.index("]")
        self.host, self.port = server_info.match(%r{^(.*):(.*)$})[1..2]
      else
        self.host = server_info
        self.port = ""
      end
    elsif server_info.chars.first == "["
      self.host = server_info
      self.port = ""
    else
      self.host, self.port = server_info.match(%r{^(.*):(.*)$})[1..2]
    end

    # parse full_path
    if full_path.include?("#")
      before_ref, self.ref = full_path.match(%r{^(.*?)#(.*)$})[1..2]
    else
      before_ref = full_path
      self.ref = ""
    end

    if before_ref.include?("?")
      self.path, self.query = before_ref.match(%r{^(.*?)\?(.*)$})[1..2]
    else
      self.path = before_ref
      self.query = ""
    end
  end

  def parse_scheme!
    self.coerced = self.original

    if !find_scheme(self.original)
      if find_scheme(self.original.sub(";", ":"))
        self.coerced = self.original.sub(";", ":")
      end
    end

    if !find_scheme(self.coerced)
      if self.coerced.match(%r{^ftp\.})
        self.coerced = "ftp://" + self.coerced
      else
        self.coerced = "http://" + self.coerced
      end
    end

    self.scheme = find_scheme(self.coerced)
  end

  def find_scheme(text)
    # extract scheme
    return false unless match = text.match(%r{^(.*?):})

    component = match[1].downcase

    # first character must be a letter
    return false unless component.match(%r{^[a-z]})

    # reject anything with invalid characters
    return false unless component.match(%r{^[+\-0-9a-z]*$})

    component
  end
end
