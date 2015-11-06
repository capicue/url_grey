require "simpleidn"

require "url_grey/version"

class URLGrey
  AUTHORITY_TERMINATORS = "/\\?#"
  ABOUT_BLANK_URL = "about:blank"
  PATH_PASS_CHARS = "!$&'()*+,/:;=@[]"
  PATH_UNESCAPE_CHARS = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~"
  HOST_ESCAPE_CHARS = " !\"\#$&'()*,<=>@`{|}"
  HOST_NORMAL_CHARS = "+-.0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ[]_abcdefghijklmnopqrstuvwxyz"
  HOST_CHROME_DEFAULT = "version"
  QUERY_NORMAL_CHARS = "!$%&()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
  DEFAULT_PORTS = {
    ftp:    21,
    gopher: 70,
    http:   80,
    https:  443,
    ws:     80,
    wss:    443,
  }
  STANDARD_SCHEMES = ['http', 'https', 'file', 'ftp', 'gopher', 'ws', 'wss', 'filesystem']

  attr_accessor :original, :coerced
  attr_accessor :scheme, :username, :password, :host, :port, :path, :query, :ref
  attr_accessor :slashes

  def initialize(_original)
    self.original = _original.sub(%r{^\s*}, '')

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

  def fixed
    return ABOUT_BLANK_URL if self.original == ABOUT_BLANK_URL

    "#{fixed_scheme}#{fixed_credentials}#{fixed_host}#{fixed_port}#{fixed_path}#{fixed_query}#{fixed_ref}"
  end

  def fixed_credentials
    return "" unless (!self.username.empty? || !self.password.empty?)
    return "#{self.username}@" if self.password.empty?
    "#{self.username}:#{self.password}@"
  end

  # from components/url_formatter/url_fixer.cc FixupHost
  def fixed_host
    fixed = self.host.gsub(%r{\s}, '').downcase
    unless fixed.match(%r{^\.*$})
      fixed = fixed.sub(%r{^\.*}, '')
      fixed = fixed.sub(%r{(?<=\.)\.*$}, '')
    end
    if fixed.empty? && ["about", "chrome"].include?(self.scheme)
      fixed = HOST_CHROME_DEFAULT
    end
    unless fixed.match(%r{^[[:ascii:]]*$})
      fixed = SimpleIDN.to_ascii(fixed)
    end
    fixed
  end

  # from url/url_canon_path.cc CanonicalizePath
  def fixed_path
    fixed = self.path
    if (fixed[0] != '/') && ((STANDARD_SCHEMES + ["about", "chrome"]).include?(self.scheme))
      fixed = '/' + fixed
    end

    fixed.chars.map do |char|
      if PATH_PASS_CHARS.include?(char)
        char
      elsif PATH_UNESCAPE_CHARS.include?(char)
        char
      elsif char == "."
        # TODO: if the dot is preceded by a slash, do directory stuff:
        # google.com/abc/.././def -> google.com/def
        char
      else
        "%#{char.codepoints.first.to_s(16).upcase}"
      end
    end.join("")
  end

  def fixed_port
    return "" if (self.port.empty? || self.port.to_i == DEFAULT_PORTS[self.scheme.to_sym])
    ":#{self.port}"
  end

  def fixed_query
    fixed = self.query
    return "" if fixed.nil?
    fixed = fixed.bytes.map do |byte|
      if QUERY_NORMAL_CHARS.unpack("U*").include?(byte)
        [byte].pack("U")
      else
        "%#{byte.to_s(16).upcase}"
      end
    end.join('')
    "?#{fixed}"
  end

  def fixed_ref
    return "" if self.ref.nil?
    "\##{self.ref}"
  end

  def fixed_scheme
    fixed = self.scheme
    if fixed == "about"
      fixed = "chrome"
    end

    if (STANDARD_SCHEMES + ["about", "chrome"]).include?(fixed)
      "#{fixed}://"
    else
      "#{fixed}:#{self.slashes}"
    end
  end

  private

  def parse!
    parse_scheme!
    after_scheme = self.coerced.match(%r{:(.*)})[1]
    self.slashes, after_slashes = after_scheme.match(%r{^([\\\/]*)(.*)$})[1..2]

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
      self.ref = nil
    end

    if before_ref.include?("?")
      self.path, self.query = before_ref.match(%r{^(.*?)\?(.*)$})[1..2]
    else
      self.path = before_ref
      self.query = nil
    end
  end

  def parse_scheme!
    self.coerced = self.original

    if !find_scheme(self.original) && (self.original[0]!= ";")
      if find_scheme(self.original.sub(";", ":"))
        self.coerced = self.original.sub(";", ":")
      end
    end

    if !find_scheme(self.coerced)
      if self.coerced.match(%r{^ftp\.}i)
        self.coerced = "ftp://" + self.coerced
      else
        self.coerced = "http://" + self.coerced
      end
    end

    self.scheme = find_scheme(self.coerced) || ""
  end

  def find_scheme(text)
    # extract scheme
    return false unless match = text.match(%r{^(.*?):})

    component = match[1].downcase

    return "" if component.empty?

    # first character must be a letter
    return false unless component.match(%r{^[a-z]})

    # reject anything with invalid characters
    return false unless component.match(%r{^[+\-0-9a-z]*$})

    # fix up segmentation for "www:123/"
    return false if has_port(text)

    component
  end

  def has_port(text)
    return false unless text.include?(":")
    match = text.match(%r{:(.*?)[\\/\?#]}) || text.match(%r{:(.*)$})
    match[1].match(%r{^\d+$})
  end
end
