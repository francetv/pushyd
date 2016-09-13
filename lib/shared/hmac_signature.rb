require 'openssl'
require 'base64'

module Shared
  module HmacSignature

    def headers_sign headers, config, names = ['date']
      # Extract and check
      return unless config.is_a? Hash
      hmac_method = config[:method]
      hmac_user   = config[:user]
      hmac_secret = config[:secret]
      #log_debug "headers_sign config", config

      # Check params
      unless config[:method] && config[:user] && config[:secret]
        log_error "headers_sign: missing method/user/secret"
        return
      end

      # Check params
      unless config[:method] == 'hmac-kong'
        log_error "headers_sign: only [hmac-kong] method is supported"
        return
      end

      # OK, lets go
      hmac_sign_kong headers, config[:user], config[:secret], names
      # log_info "headers_sign: after signing", headers
    end

    def headers_md5 headers, payload
      headers['Content-MD5'] = Digest::MD5.hexdigest(payload.to_s)
    end

  private

    def hmac_sign_kong headers, client_id, client_secret, names
      # Update date
      headers['Date'] = Time.now.strftime('%a, %d %b %Y %H:%M:%S GMT')
      # headers['Content-MD5'] = Date.now.strftime('%a, %d %b %Y %H:%M:%S GMT')
      # log_debug "hmac_sign_kong: headers", headers

      # Filter headers we're going to hash
      myheaders = hmac_headers_filter headers, names

      # Signe string of headers
      signature = hmac_headers_hash myheaders, client_secret
      log_debug "hmac_sign_kong signed [#{signature}] from headers #{myheaders.keys.inspect}"

      # Add auth header
      headers['Authorization'] = hmac_build_header(client_id, myheaders, signature)
      #headers['test'] = "testing123"

      # That's OK
      return headers
    end

    def hmac_build_header client_id, myheaders, signature
      sprintf 'hmac username="%s", algorithm="hmac-sha1", headers="%s", signature="%s"',
        client_id,
        myheaders.keys.map(&:downcase).join(' '),
        signature
    end

    def hmac_headers_filter headers, selection
      out = {}

      # Build array of keys as strings, downcase
      selection_names = selection.map{|h| h.to_s.downcase}

      # For each header, stack it or not
      headers.each do |name, value|
        name_down = name.downcase
        next unless selection_names.include? name_down
        out[name_down] = value
      end

      # We're done
      return out
    end

    def hmac_headers_hash myheaders, client_secret
      # Build headers string
      data = myheaders.map do |name, value|
        sprintf("%s: %s", name, value)
      end.join("\n")

      # Hash this
      digest  = OpenSSL::Digest.new('sha1')
      Base64.encode64(OpenSSL::HMAC.digest(digest, client_secret, data)).strip
    end

    def hmac_sign_data client_secret, data
    end

  end
end
