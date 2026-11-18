# encoding: utf-8
# ==============================================================================
# CAMPAIGN-OPTIMIZER: Közösségi Média Adatgyűjtő és Scraper Modul (Meta FB & IG)
# ==============================================================================

require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'date'
require 'csv'
require 'optparse'
require 'fileutils'

module CampaignScraper
  KNOWN_PROFILES = {
    "orbán viktor" => {
      facebook: "https://www.facebook.com/orbanviktor",
      instagram: "https://www.instagram.com/orbanviktor/"
    },
    "magyar péter" => {
      facebook: "https://www.facebook.com/peter.magyar.102",
      instagram: "https://www.instagram.com/peter_magyar_official/"
    },
    "dúró dóra" => {
      facebook: "https://www.facebook.com/durodora",
      instagram: "https://www.instagram.com/durodora_official/"
    },
    "toroczkai lászló" => {
      facebook: "https://www.facebook.com/toroczkailaszlo",
      instagram: "https://www.instagram.com/toroczkailaszlo/"
    },
    "dobrev klára" => {
      facebook: "https://www.facebook.com/dobrevklara",
      instagram: "https://www.instagram.com/dobrevklara/"
    }
  }.freeze

  def self.resolve_profile_url(politician, platform)
    key = politician.to_s.strip.downcase
    plat_sym = platform.to_s.downcase.include?("face") ? :facebook : :instagram
    match = KNOWN_PROFILES[key]
    match ? match[plat_sym] : nil
  end

  def self.candidate_key(politician)
    politician.to_s.strip.split(/\s+/).map { |w| w[0] }.join.upcase
  end

  # ============================================================================
  # 1. APIFY FELHŐS SCRAPER (Facebook Posts Scraper & Instagram Scraper)
  # ============================================================================
  def self.scrape_via_apify(token, platform, profile_url, start_date, end_date, limit: 100)
    is_fb = platform.downcase.include?("face") || platform.downcase == "fb"
    actor_id = is_fb ? "apify~facebook-posts-scraper" : "apify~instagram-scraper"

    puts "📡 Kapcsolódás az Apify API-hoz..."
    puts "   Aktor: #{actor_id}"
    puts "   Célprofil: #{profile_url}"
    puts "   Időszak: #{start_date} -> #{end_date}"

    d_start = start_date.to_s.tr(".", "-").sub(/-$/, "")
    d_end = end_date.to_s.tr(".", "-").sub(/-$/, "")

    # Build input payload
    input_payload = if is_fb
      {
        "startUrls" => [{ "url" => profile_url }],
        "resultsLimit" => limit,
        "captionText" => true,
        "onlyPostsNewerThan" => d_start
      }
    else
      {
        "directUrls" => [profile_url],
        "resultsType" => "posts",
        "resultsLimit" => limit,
        "onlyPostsNewerThan" => d_start
      }
    end

    uri = URI("https://api.apify.com/v2/acts/#{actor_id}/runs?token=#{token}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    req = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
    req.body = input_payload.to_json

    res = http.request(req)
    unless res.is_a?(Net::HTTPSuccess)
      raise "Apify futtatási hiba (#{res.code}): #{res.body}"
    end

    run_data = JSON.parse(res.body)["data"]
    run_id = run_data["id"]
    dataset_id = run_data["defaultDatasetId"]
    puts "🚀 Scraping futás elindítva (ID: #{run_id}). Várakozás az adatokra..."

    # Poll status
    status = "RUNNING"
    start_time = Time.now
    while ["RUNNING", "READY"].include?(status)
      sleep 8
      status_uri = URI("https://api.apify.com/v2/actor-runs/#{run_id}?token=#{token}")
      s_http = Net::HTTP.new(status_uri.host, status_uri.port)
      s_http.use_ssl = true
      s_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      status_res = s_http.get(status_uri.request_uri)
      if status_res.is_a?(Net::HTTPSuccess)
        status = JSON.parse(status_res.body)["data"]["status"]
        elapsed = (Time.now - start_time).to_i
        print "\r   Állapot: #{status} (#{elapsed} mp eltelt)..."
        $stdout.flush
      end
      if Time.now - start_time > 600
        puts "\nIdőtúllépés (timeout) a scraping során."
        break
      end
    end
    puts ""

    unless status == "SUCCEEDED"
      raise "A scraping nem zárult sikerrel. Állapot: #{status}"
    end

    # Fetch dataset items
    data_uri = URI("https://api.apify.com/v2/datasets/#{dataset_id}/items?token=#{token}&format=json")
    d_http = Net::HTTP.new(data_uri.host, data_uri.port)
    d_http.use_ssl = true
    d_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    items_res = d_http.get(data_uri.request_uri)
    unless items_res.is_a?(Net::HTTPSuccess)
      raise "Nem sikerült letölteni a kinyert adatokat: #{items_res.body}"
    end

    JSON.parse(items_res.body)
  end

  # ============================================================================
  # 2. ADATOK ÁTALAKÍTÁSA KÓDKÖNYVI STRUKTÚRÁRA (DATABASE_V2 FORMÁTUM)
  # ============================================================================
  def self.normalize_records(raw_items, platform, start_date, end_date)
    is_fb = platform.downcase.include?("face") || platform.downcase == "fb"
    normalized = []

    raw_items.each_with_index do |item, idx|
      # Extract date
      raw_time = item["time"] || item["timestamp"] || item["publishedAt"] || item["date"]
      date_str = ""
      if raw_time
        begin
          d = DateTime.parse(raw_time.to_s)
          date_str = d.strftime("%Y.%m.%d.")
        rescue
          date_str = raw_time.to_s[0..9].tr("-", ".") + "."
        end
      end

      # Filter date
      next if !start_date.to_s.empty? && date_str < start_date
      next if !end_date.to_s.empty? && date_str > end_date

      # Extract metrics
      likes = (item["likes"] || item["likesCount"] || item["reactionCount"] || 0).to_i
      comments = (item["comments"] || item["commentsCount"] || 0).to_i
      shares = (item["shares"] || item["sharesCount"] || 0).to_i

      # Extract texts
      caption = (item["text"] || item["caption"] || item["postText"] || "").to_s.strip
      text_ocr = (item["captionText"] || item["ocrText"] || item["transcript"] || "-").to_s.strip

      # Determine type
      type_raw = (item["mediaType"] || item["type"] || "").to_s.downcase
      url_raw = (item["url"] || item["postUrl"] || item["link"] || "").to_s.downcase
      tipus = if url_raw.include?("/reel/") || type_raw.include?("reel")
        "reel videó"
      elsif url_raw.include?("/videos/") || type_raw.include?("video")
        "videó"
      elsif !text_ocr.empty? && text_ocr != "-"
        "kép szöveggel"
      else
        "kép"
      end

      # 5 min and music rules
      duration = (item["videoDuration"] || item["duration"] || 0).to_i
      only_music = item["onlyMusic"] == true || text_ocr.downcase.include?("zene:")

      if duration > 300
        text_ocr = "ERROR"
      elsif only_music
        text_ocr = "ERROR"
      elsif tipus == "kép" && (text_ocr.empty? || text_ocr == "")
        text_ocr = "-"
      end

      # Calculate kepvis_ossz
      kepvis_ossz = if is_fb
        (2 * comments) + (2 * shares) + likes
      else
        (2 * comments) + likes
      end

      row = {
        "nr" => idx + 1,
        "caption" => caption,
        "link" => item["url"] || item["postUrl"] || item["link"] || "",
        "dátum" => date_str,
        "típus" => tipus,
        "szöveg" => text_ocr,
        "kommentek sz." => comments,
        "likeok sz." => likes
      }
      row["megosztások sz."] = shares if is_fb
      row["kepvis_ossz"] = kepvis_ossz

      normalized << row
    end

    normalized
  end

  # ============================================================================
  # 3. CSV MENTÉS A DATA/ MAPPÁBA
  # ============================================================================
  def self.save_to_csv(rows, output_path, is_fb)
    return false if rows.empty?

    headers = if is_fb
      ["nr", "caption", "link", "dátum", "típus", "szöveg", "kommentek sz.", "megosztások sz.", "likeok sz.", "kepvis_ossz"]
    else
      ["nr", "caption", "link", "dátum", "típus", "szöveg", "kommentek sz.", "likeok sz."]
    end

    FileUtils.mkdir_p(File.dirname(output_path))
    CSV.open(output_path, "w", col_sep: ";", encoding: "utf-8", write_headers: true, headers: headers) do |csv|
      rows.each do |r|
        csv << headers.map { |h| r[h] }
      end
    end
    true
  end
end

# CLI Execution
if __FILE__ == $0
  options = {
    politician: "Dúró Dóra",
    platform: "Facebook",
    start_date: "2026.02.21.",
    end_date: "2026.04.11.",
    profile_url: nil,
    output_csv: nil,
    apify_token: ENV["APIFY_TOKEN"],
    limit: 100
  }

  # Load .env if present
  env_paths = [".env", File.expand_path("../../../.env", File.dirname(__FILE__))]
  env_paths.each do |ep|
    if File.exist?(ep)
      File.foreach(ep) do |line|
        if line =~ /^\s*APIFY_TOKEN\s*=\s*["']?([^"'\s#]+)["']?/
          options[:apify_token] ||= $1
          ENV["APIFY_TOKEN"] ||= $1
        end
      end
    end
  end

  OptionParser.new do |opts|
    opts.banner = "Használat: ruby scrape_campaign.rb [opciók]"
    opts.on("-p", "--politician NAME", "Politikus neve") { |v| options[:politician] = v.to_s.dup.force_encoding("utf-8") }
    opts.on("-f", "--platform PLATFORM", "Platform ('Facebook' vagy 'Instagram')") { |v| options[:platform] = v.to_s.dup.force_encoding("utf-8") }
    opts.on("-s", "--start DATE", "Kezdő dátum (YYYY.MM.DD.)") { |v| options[:start_date] = v }
    opts.on("-e", "--end DATE", "Záró dátum (YYYY.MM.DD.)") { |v| options[:end_date] = v }
    opts.on("-u", "--url URL", "Profil URL-címe") { |v| options[:profile_url] = v }
    opts.on("-o", "--output PATH", "Kimeneti CSV fájl") { |v| options[:output_csv] = v }
    opts.on("-t", "--token TOKEN", "Apify API Token") { |v| options[:apify_token] = v }
    opts.on("-l", "--limit N", Integer, "Maximális posztszám") { |v| options[:limit] = v }
  end.parse!

  # Interaktív bekérés terminálban, ha hiányzik a token
  if (!options[:apify_token] || options[:apify_token].strip.empty?) && STDIN.tty?
    print "Kérlek, add meg az Apify API Tokenedet (apify_api_...): "
    input_tok = STDIN.gets.to_s.strip
    if !input_tok.empty?
      options[:apify_token] = input_tok
      ENV["APIFY_TOKEN"] = input_tok
      File.write(".env", "APIFY_TOKEN=#{input_tok}\n", mode: "a") unless File.exist?(".env") && File.read(".env").include?("APIFY_TOKEN")
      puts "💾 Apify token elmentve a .env fájlba."
    end
  end

  puts "=========================================================="
  puts "CAMPAIGN-OPTIMIZER ADATGYŰJTŐ & SCRAPER MODUL"
  puts "=========================================================="
  puts "Politikus: #{options[:politician]}"
  puts "Platform:  #{options[:platform]}"
  puts "Időszak:   #{options[:start_date]} -> #{options[:end_date]}"

  # Platform validation
  platform_lower = options[:platform].downcase
  unless platform_lower.include?("face") || platform_lower.include?("insta") || platform_lower == "fb" || platform_lower == "ig"
    puts "HIBA: Jelenleg kizárólag a 'Facebook' és 'Instagram' platformok támogatottak!"
    exit 1
  end

  # Resolve profile URL
  options[:profile_url] ||= CampaignScraper.resolve_profile_url(options[:politician], options[:platform])
  unless options[:profile_url]
    puts "HIBA: Nem található mentett profil URL a következőhöz: #{options[:politician]} (#{options[:platform]})"
    puts "Kérlek, add meg a profil linkjét a --url kapcsolóval!"
    exit 1
  end

  # Resolve output path
  is_fb = platform_lower.include?("face") || platform_lower == "fb"
  plat_key = is_fb ? "FB" : "IG"
  cand_key = CampaignScraper.candidate_key(options[:politician])
  options[:output_csv] ||= "data/DATABASE_V2_#{cand_key}_#{plat_key}.csv"

  puts "Célprofil: #{options[:profile_url]}"
  puts "Célfájl:   #{options[:output_csv]}"

  # Check Apify token
  token = options[:apify_token]
  if token && !token.strip.empty?
    begin
      raw_items = CampaignScraper.scrape_via_apify(token, options[:platform], options[:profile_url], options[:start_date], options[:end_date], limit: options[:limit])
      puts "✅ Letöltve: #{raw_items.size} nyers bejegyzés az Apify-tól."

      rows = CampaignScraper.normalize_records(raw_items, options[:platform], options[:start_date], options[:end_date])
      puts "✅ Kódkönyv szerint szűrve és normalizálva: #{rows.size} bejegyzés."

      if rows.any?
        CampaignScraper.save_to_csv(rows, options[:output_csv], is_fb)
        puts "🟢 Valós adatbázis sikeresen elmentve: #{options[:output_csv]}"
      else
        puts "⚠️ A megadott időszakban nem találtunk posztokat a profilról."
      end
    rescue => e
      puts "🔴 HIBA az Apify scraping során: #{e.message}"
      exit 1
    end
  else
    puts "----------------------------------------------------------"
    puts "⚠️ APIFY_TOKEN HIÁNYZIK"
    puts "A Meta (Facebook & Instagram) botvédelme és bejelentkezési fala"
    puts "miatt az automatikus lekaparáshoz Apify API token szükséges."
    puts ""
    puts "Megoldási lehetőségek:"
    puts "1. Állítsd be az Apify tokent: export APIFY_TOKEN=\"apify_api_...\""
    puts "   vagy futtasd így: ruby .agent/skills/campaign-optimizer/scripts/scrape_campaign.rb --token \"apify_api_...\""
    puts "2. Vagy helyezd el az exportált CSV adatbázist a 'data/' mappába:"
    puts "   -> #{options[:output_csv]}"
    puts "----------------------------------------------------------"
    puts "❌ SZIGORÚ INTEGRITÁSI SZABÁLY: A rendszer nem generál fals/fiktív adatokat."
    exit 1
  end
end
