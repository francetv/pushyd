require 'openssl'
require 'base64'

module Shared
  module HmacSignature

    def headers_md5 headers, payload
      headers['Content-MD5'] = Digest::MD5.hexdigest(payload.to_s)
    end

    def headers_sign headers, config
      # Extract and check
      return unless config.is_a? Hash
      hmac_method   = config[:method]
      hmac_user     = config[:user]
      hmac_secret   = config[:secret]
      log_debug "headers_sign config", config

      # Check params
      unless hmac_method && hmac_user && hmac_secret
        log_error "headers_sign: missing method/user/secret"
        return
      end

      # Check headers, and translate names to strings
      unless config[:headers].is_a? Array
        log_error "headers_sign: [headers] should be an array of headers to be signed"
        return
      end
      hmac_headers = config[:headers].map(&:to_s)

      # Update date
      headers['Date'] = Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT')

      # Let's apply the requested method
      case hmac_method
      when 'hmac-kong'
        hmac_sign_kong headers, hmac_user, hmac_secret, hmac_headers
      else
        log_error "headers_sign: only [hmac-kong] method is supported"
        return
      end
    end

  private

    def hmac_sign_kong headers, client_id, client_secret, selection
      # Ensure we have :date in headers and no dup
      selected = selection.push("date").uniq

      # Signe string of headers
      signature = hmac_headers_hash headers, selected, client_secret
      log_debug "hmac_sign_kong: signed [#{signature}] from #{selected.inspect}"

      # Add auth header
      headers['Authorization'] = hmac_build_header(client_id, selection, signature)
      #headers['test'] = "testing123"

      # That's OK
      return headers
    end

    def hmac_build_header client_id, selection, signature
      sprintf 'hmac username="%s", algorithm="hmac-sha1", headers="%s", signature="%s"',
        client_id,
        selection.map(&:downcase).join(' '),
        signature
    end

    def hmac_headers_hash headers, selection, client_secret
      # Init
      selected = []

      # For each selected header
      selection.each do |sel|
        this = sel.downcase

        # For each header, stack it or not
        headers.each do |header_name, header_value|
          next unless this == header_name.downcase
          selected << sprintf("%s: %s", this, header_value)
        end
      end

      # Build headers string and hash it
      data = selected.join("\n")
      digest  = OpenSSL::Digest.new('sha1')
      Base64.encode64(OpenSSL::HMAC.digest(digest, client_secret, data)).strip
    end

  end
end
