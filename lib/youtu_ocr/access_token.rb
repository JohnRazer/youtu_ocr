require 'openssl'
require 'digest'
require 'date'
require 'base64'

module YoutuOcr

  def initialize
    @app_id = '10115415'
    @user_id = '3334262361'
    @secret_id = 'AKIDsZHm24kc1A3mFS88bolSuAAvRhhRtA9q'
    @secret_key = 'e7MPCpCJBn9F5f181f4E9pGTRAetsb5J'
    @end_point = "http://api.youtu.qq.com/youtu/ocrapi/"
    @types = %w(id_card id_card_back bank_card driving_license driving_license_vice vehicle_license business_license)
  end

  def self.access_token
    expires_in = 86400
    now = Time.now.to_i
    random_number = rand(99999999)
    expired = now + expires_in
    plain_text = "u=#{@user_id}&a=#{@app_id}&k=#{@secret_id}&e=#{expired}&t=#{now}&r=#{random_number}&f="
    digest = OpenSSL::Digest.new("SHA1")
    bin = OpenSSL::HMAC.digest(digest, @secret_key, plain_text)
    bin = "#{bin}#{plain_text}"
    Base64.encode64(bin).gsub("\n", "")
  end

end