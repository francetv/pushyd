require 'openssl'
require 'base64'

module Shared
  module HmacSignature

    def headers_sign request, hmac_method, hmac_user, hmac_secret, names = ['date']
      return unless hmac_user
      unless hmac_secret && hmac_method
        log_error "headers_sign: hmac: missing secret or method"
        return
      end

      # OK, lets go
      log_info "headers_sign: before: user[#{hmac_user}] secret[#{hmac_secret}] method[#{hmac_method}]", request.headers
      hmac_sign_kong request.headers, hmac_user, hmac_secret, names
      log_info "headers_sign: after:", request.headers
    end

    def headers_md5 request
      request.headers['Content-MD5'] = Digest::MD5.hexdigest(request.payload.to_s)
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
      headers_signature = hmac_headers_hash myheaders, client_secret
      log_debug "hmac_sign_kong #{myheaders.keys.inspect} #{headers_signature}"

      # Add auth header
      # headers['Authorization'] = hmac_build_header(client_id, myheaders, headers_signature)
      headers['test'] = "testing123"

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
