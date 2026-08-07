# App Store Connect API를 직접 호출해 원본 응답을 그대로 출력한다.
#
# fastlane은 에러 메시지를 한 줄로 요약해 버려서, "어느 계약이 문제인지" 같은
# 구체적인 정보가 사라진다. 이 스크립트는 HTTP 상태와 응답 본문 전문을 남긴다.
#
# 함께 확인되는 것:
#   - 이 API 키가 실제로 어느 팀의 앱을 볼 수 있는지 (= 키가 어느 계정 소속인지)
#   - 계약 문제라면 Apple이 지목하는 정확한 사유
#
# 주의: 비밀키(.p8) 본문은 절대 출력하지 않는다.

require "base64"
require "json"
require "jwt"
require "net/http"
require "openssl"
require "uri"

BUNDLE_ID = "com.jungmin.tomyongji.ios".freeze

def id_tail(value)
  v = value.to_s
  return "(비어 있음)" if v.strip.empty?
  return "(너무 짧음)" if v.length < 4

  "...#{v[-4..]}"
end

key_id = ENV["APP_STORE_CONNECT_API_KEY_ID"].to_s
issuer_id = ENV["APP_STORE_CONNECT_API_KEY_ISSUER_ID"].to_s
key_b64 = ENV["APP_STORE_CONNECT_API_KEY_KEY"].to_s

missing = {
  "APP_STORE_CONNECT_API_KEY_ID" => key_id,
  "APP_STORE_CONNECT_API_KEY_ISSUER_ID" => issuer_id,
  "APP_STORE_CONNECT_API_KEY_KEY" => key_b64
}.select { |_, v| v.strip.empty? }.keys

unless missing.empty?
  puts "::error::시크릿이 비어 있습니다: #{missing.join(', ')}"
  exit 1
end

# Key ID / Issuer ID는 시크릿으로 등록돼 있어 전체를 찍으면 ***로 마스킹된다.
# 뒤 4자리만 남겨서 App Store Connect 화면의 값과 눈으로 대조할 수 있게 한다.
puts "=" * 60
puts "사용 중인 자격 정보"
puts "=" * 60
puts "Key ID    : #{id_tail(key_id)}"
puts "Issuer ID : #{id_tail(issuer_id)}"
puts

# .p8 본문이 base64로 인코딩돼 있는지부터 확인한다.
# Fastfile이 Base64.decode64를 하므로, 인코딩 없이 넣으면 여기서 걸린다.
p8 = Base64.decode64(key_b64)
unless p8.include?("PRIVATE KEY")
  puts "::error::APP_STORE_CONNECT_API_KEY_KEY 를 base64 디코드한 결과가 .p8 키 형식이 아닙니다."
  puts "        .p8 파일 전체를 base64로 인코딩한 값이어야 합니다:"
  puts "        gh secret set APP_STORE_CONNECT_API_KEY_KEY < <(base64 -i AuthKey_XXXX.p8)"
  exit 1
end

begin
  private_key = OpenSSL::PKey::EC.new(p8)
rescue OpenSSL::PKey::ECError => e
  puts "::error::.p8 키를 파싱하지 못했습니다: #{e.message}"
  exit 1
end

token = JWT.encode(
  { iss: issuer_id, exp: Time.now.to_i + 600, aud: "appstoreconnect-v1" },
  private_key,
  "ES256",
  { kid: key_id, typ: "JWT" }
)

def request(token, path, description)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "Bearer #{token}"

  res = http.request(req)

  puts "=" * 60
  puts description
  puts "=" * 60
  puts "GET #{path}"
  puts "HTTP #{res.code}"
  puts
  begin
    puts JSON.pretty_generate(JSON.parse(res.body))
  rescue JSON::ParserError
    puts res.body
  end
  puts

  res
end

# 이 키가 볼 수 있는 앱 전체. 여기 나오는 목록이 곧 "키가 소속된 팀"의 앱이다.
# 목록에 대상 번들 ID가 없으면 키가 다른 계정의 것이라는 뜻이다.
apps_res = request(
  token,
  "/v1/apps?fields[apps]=bundleId,name,sku&limit=50",
  "이 API 키로 조회되는 앱 목록"
)

# 실제 Team ID 를 확정한다.
# App Store Connect API 는 팀 ID 를 직접 알려주는 엔드포인트가 없지만,
# 프로비저닝 프로파일 본문(.mobileprovision 플리스트)에 TeamIdentifier 가 들어 있다.
# Project.swift 의 DEVELOPMENT_TEAM 과 대조하기 위한 값이다.
profiles_res = request(
  token,
  "/v1/profiles?fields[profiles]=name,profileType,profileContent&limit=20",
  "프로비저닝 프로파일에서 실제 Team ID 추출"
)

if profiles_res.code == "200"
  teams = JSON.parse(profiles_res.body).fetch("data", []).flat_map do |profile|
    content = profile.dig("attributes", "profileContent")
    next [] if content.nil?

    plist = Base64.decode64(content)
    plist.scan(%r{<key>TeamIdentifier</key>\s*<array>\s*<string>([A-Z0-9]+)</string>}m).flatten
  end.uniq

  puts "=" * 60
  puts "실제 Team ID"
  puts "=" * 60
  if teams.empty?
    puts "프로파일에서 Team ID 를 찾지 못했습니다."
  else
    teams.each { |t| puts "  #{t}" }
    puts
    puts "Project.swift 의 DEVELOPMENT_TEAM, Appfile / Matchfile 의 team_id 가"
    puts "위 값과 같아야 합니다. 다르면 xcodebuild 가 프로파일을 찾지 못합니다."
  end
  puts
end

puts "=" * 60
puts "판정"
puts "=" * 60

if apps_res.code == "200"
  apps = JSON.parse(apps_res.body).fetch("data", [])
  bundle_ids = apps.map { |a| a.dig("attributes", "bundleId") }.compact

  puts "조회된 앱 #{apps.size}개: #{bundle_ids.join(', ')}"
  puts

  if bundle_ids.include?(BUNDLE_ID)
    puts "→ 키는 정상이고 #{BUNDLE_ID} 도 이 팀에 있습니다."
    puts "  계약 문제가 아니라면 원인은 다른 곳입니다. 위 응답과 배포 로그를 함께 보세요."
  else
    puts "→ 이 키로는 #{BUNDLE_ID} 가 보이지 않습니다."
    puts "  GitHub Secrets의 API 키가 현재 앱이 올라간 계정이 아닌,"
    puts "  다른 Apple 계정/팀에서 발급된 것입니다. 새 계정에서 키를 재발급해 시크릿 3종을 교체하세요."
  end
else
  puts "→ 앱 목록 조회가 HTTP #{apps_res.code} 로 실패했습니다. 위 응답 본문의 detail 필드가 정확한 사유입니다."
  puts "  'agreement' 가 언급되면, 지금 확인하신 계정이 아니라"
  puts "  이 키가 소속된 다른 계정 쪽 계약이 실효된 것입니다."
end
