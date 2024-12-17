require 'uri'
require 'json'
require 'net/http'
require 'openssl'

# module AccountBlock
module LeanTechService
  class << self
    # LEAN_BASE_URL = 'https://api.leantech.me'
    # LEAN_APP_TOKEN = ENV['LEAN_APP_TOKEN']
    # CERT_PATH = 'public/Myne_certificate.crt'
    # KEY_PATH = 'public/Myne_private_key.pem'
    # CA_PATH = 'public/lean_public_cert_chain.pem'

# => sandbox credentials
    LEAN_BASE_URL = 'https://sandbox.leantech.me/data/v1'.freeze
    CERT_PATH = 'public/MYNE_certificate.crt'.freeze
    KEY_PATH = 'public/MYNE_private_key.pem'.freeze
    CA_PATH = 'public/lean_public_cert_chain.pem'.freeze
    LEAN_APP_TOKEN = 'b583988f-42b8-4453-879f-2fd70099e84f'.freeze

    def get_accounts(entity_id)
      uri = URI("#{LEAN_BASE_URL}/data/v1/accounts")
      post_request(uri, { entity_id: entity_id })
    end

    def get_results(results_id)
      uri = URI("#{LEAN_BASE_URL}/data/v1/results/#{results_id}")
      get_request(uri)
    end

    def create_customer(app_user_id)
      uri = URI("#{LEAN_BASE_URL}/customers/v1")
      post_request(uri, { app_user_id: app_user_id })
    end

    private

    def https_connection(uri)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.cert = OpenSSL::X509::Certificate.new(File.read(CERT_PATH))
      https.key = OpenSSL::PKey::RSA.new(File.read(KEY_PATH))
      https.ca_file = CA_PATH
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https
    end

    def post_request(uri, body)
      https = https_connection(uri)

      request = Net::HTTP::Post.new(uri)
      set_common_headers(request)
      request.body = JSON.dump(body)

      response = https.request(request)
      parse_response(response)
    end

    def get_request(uri)
      https = https_connection(uri)

      request = Net::HTTP::Get.new(uri)
      set_common_headers(request)

      response = https.request(request)
      parse_response(response)
    end

    def set_common_headers(request)
      request['lean-app-token'] = LEAN_APP_TOKEN
      request['Content-Type'] = 'application/json'
    end

    def parse_response(response)
      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        { error: "HTTP Error: #{response.message}", status: response.code }
      end
    rescue JSON::ParserError
      { error: 'Invalid JSON response from server' }
    end
  end
end
# end
