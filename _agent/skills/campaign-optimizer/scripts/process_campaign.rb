# encoding: utf-8
require 'fileutils'
require 'date'
require 'optparse'
require 'csv'

require_relative 'mores_classifier'
require_relative 'calc_metrics'
require_relative 'campaign_report'

# Load .env if present
env_paths = [".env", File.expand_path("../../../.env", File.dirname(__FILE__))]
env_paths.each do |ep|
  if File.exist?(ep)
    File.foreach(ep) do |line|
      if line =~ /^\s*APIFY_TOKEN\s*=\s*["']?([^"'\s#]+)["']?/
        ENV["APIFY_TOKEN"] ||= $1
      end
    end
  end
end

options = {
  politician: "Orbán Viktor",
  platform: "Facebook",
  start_date: "2026.02.21.",
  end_date: "2026.04.11.",
  input_csv: nil,
  output_csv: nil,
  output_report: nil,
  apify_token: ENV["APIFY_TOKEN"],
  auto_scrape: false
}

OptionParser.new do |opts|
  opts.banner = "Használat: ruby process_campaign.rb [opciók]"
  opts.on("-p", "--politician NAME", "Politikus neve (pl: 'Orbán Viktor', 'Magyar Péter')") { |v| options[:politician] = v }
  opts.on("-f", "--platform PLATFORM", "Közösségi platform ('Facebook', 'Instagram')") { |v| options[:platform] = v }
  opts.on("-s", "--start DATE", "Kezdő dátum (YYYY.MM.DD.)") { |v| options[:start_date] = v }
  opts.on("-e", "--end DATE", "Záró dátum (YYYY.MM.DD.)") { |v| options[:end_date] = v }
  opts.on("-i", "--input PATH", "Bemeneti CSV fájl") { |v| options[:input_csv] = v }
  opts.on("-o", "--output PATH", "Kimeneti CSV fájl") { |v| options[:output_csv] = v }
  opts.on("-r", "--report PATH", "Kimeneti elemző jelentés elérési útja") { |v| options[:output_report] = v }
  opts.on("-t", "--token TOKEN", "Apify API Token automatikus scrapinghez") { |v| options[:apify_token] = v }
  opts.on("--scrape", "Automatikus scraping indítása, ha hiányzik az adatbázis") { options[:auto_scrape] = true }
end.parse!

options.each do |k, v|
  options[k] = v.to_s.dup.force_encoding("utf-8") if v.is_a?(String)
end

puts "=========================================================="
puts "CAMPAIGN-OPTIMIZER ELEMZŐ FOLYAMAT"
puts "=========================================================="
puts "Politikus: #{options[:politician]}"
puts "Platform: #{options[:platform]}"
puts "Időintervallum: #{options[:start_date]} -> #{options[:end_date]}"

# Auto-locate default CSV if not provided
unless options[:input_csv] && File.exist?(options[:input_csv])
  name_clean = options[:politician].to_s.strip
  name_parts = name_clean.split(/\s+/)
  cand_key = name_parts.map { |w| w[0] }.join.upcase
  plat_key = options[:platform].to_s.downcase.include?("face") ? "FB" : "IG"

  patterns = [
    "DATABASE_V2_#{cand_key}_#{plat_key}.csv",
    "#{cand_key}_#{plat_key}.csv",
    "*#{cand_key}*#{plat_key}*.csv",
    "*#{name_parts.first}*#{plat_key}*.csv",
    "*#{name_parts.last}*#{plat_key}*.csv",
    "*#{cand_key}*.csv"
  ]

  search_dirs = ["data", ".", "reports", "artifex_skill_pilot"]
  found = nil

  search_dirs.each do |dir|
    next unless Dir.exist?(dir)
    patterns.each do |pat|
      matches = Dir.glob(File.join(dir, pat), File::FNM_CASEFOLD)
      filtered = matches.select { |f| f.downcase.include?(cand_key.downcase) || (name_parts.first && f.downcase.include?(name_parts.first.downcase)) }
      match_to_use = filtered.first || matches.first
      if match_to_use && File.exist?(match_to_use)
        found = match_to_use
        break
      end
    end
    break if found
  end

  # Ha nem található helyi CSV, ellenőrizzük az automatikus adatgyűjtést (Scraping)
  unless found
    target_csv = "data/DATABASE_V2_#{cand_key}_#{plat_key}.csv"
    scraper_script = File.expand_path("scrape_campaign.rb", File.dirname(__FILE__))
    token_to_use = options[:apify_token] || ENV["APIFY_TOKEN"]

    if File.exist?(scraper_script) && (token_to_use || options[:auto_scrape])
      puts "ℹ️ Nincs előre betöltött adatbázis. Automatikus adatgyűjtő (scraper) indítása..."
      cmd = [
        "ruby", scraper_script,
        "--politician", options[:politician],
        "--platform", options[:platform],
        "--start", options[:start_date],
        "--end", options[:end_date],
        "--output", target_csv
      ]
      cmd += ["--token", token_to_use] if token_to_use && !token_to_use.empty?

      success = system(*cmd)
      if success && File.exist?(target_csv)
        found = target_csv
        puts "🟢 Automatikus adatgyűjtés befejeződött: #{found}"
      end
    end
  end

  if found && File.exist?(found)
    options[:input_csv] = found
    puts "Automatikusan kiválasztott forrás: #{found}"
  else
    puts "HIBA: Nem található bemeneti CSV adatfájl a következőhöz: #{options[:politician]} (#{options[:platform]})"
    puts ""
    puts "Megoldási lehetőségek:"
    puts "1. Automatikus adatgyűjtés (Scraping):"
    puts "   Állítsd be az Apify tokent (export APIFY_TOKEN=\"...\"), majd futtasd a skillt a --scrape kapcsolóval:"
    puts "   ruby .agent/skills/campaign-optimizer/scripts/process_campaign.rb --politician \"#{options[:politician]}\" --platform \"#{options[:platform]}\" --scrape"
    puts "2. Kézi import:"
    puts "   Helyezd el az exportált CSV adatbázist a 'data/' mappába:"
    puts "   -> data/DATABASE_V2_#{cand_key}_#{plat_key}.csv"
    puts ""
    puts "❌ SZIGORÚ INTEGRITÁSI SZABÁLY: A rendszer soha nem generál fals vagy kitalált adatokat."
    exit 1
  end
end

# Auto-detect separator
first_line = File.open(options[:input_csv], "r:bom|utf-8", &:readline)
sep = first_line.include?(";") ? ";" : ","

rows = []
CSV.foreach(options[:input_csv], headers: true, col_sep: sep, encoding: "bom|utf-8") do |row|
  d = row["dátum"].to_s.strip
  next if d < options[:start_date] || d > options[:end_date]

  h = row.to_h

  # 1. 5 perces és zenei videó szabály érvényesítése
  video_duration_sec = h["video_hossz_mp"].to_i # ha rögzítve van
  only_music = h["csak_zene"].to_s.downcase == "true" || h["szöveg"].to_s.downcase.include?("zene:")

  if video_duration_sec > 300
    h["szöveg"] = "ERROR: >5 MIN"
  elsif only_music
    h["szöveg"] = "ERROR: ONLY_MUSIC"
  end

  # 2. Idézetkártyák és képek kezelése
  if h["típus"] == "kép" && h["szöveg"] && !h["szöveg"].strip.empty? && h["szöveg"] != "-" && !h["szöveg"].include?("ERROR")
    h["típus"] = "kép szöveggel"
  elsif h["típus"] == "kép" && (h["szöveg"].nil? || h["szöveg"].strip.empty?)
    h["szöveg"] = "-"
  end

  # 3. kepvis_ossz számítása
  comments = h["kommentek sz."].to_f
  shares = h["megosztások sz."].to_f
  likes = h["likeok sz."].to_f
  kepvis = CampaignMetrics.calculate_kepvis_ossz(options[:platform], comments, shares, likes)
  h["kepvis_ossz"] = kepvis.to_i

  # 4. ELTE TK MORES Érzelemelemzés minden sorra
  combined_text = "#{h['caption']} #{h['szöveg']}".strip
  mores_result = MoresClassifier.classify(combined_text)

  h["Mores 1"] = mores_result[:emotion]
  h["Mores 1 conf."] = mores_result[:confidence]
  h["Mores_moral"] = mores_result[:moral]

  rows << h
end

puts "Talált és feldolgozott sorok száma a vizsgált időszakban: #{rows.size} db"

# Sort by kepvis_ossz desc
sorted_rows = rows.sort_by { |r| -r["kepvis_ossz"].to_i }

# Format rows for stats
struct_rows = sorted_rows.map do |r|
  {
    nr: r["nr"],
    caption: r["caption"],
    link: r["link"],
    dátum: r["dátum"],
    típus: r["típus"],
    tipus: r["típus"],
    szöveg: r["szöveg"],
    kommentek_sz: r["kommentek sz."],
    megosztások_sz: r["megosztások sz."],
    likeok_sz: r["likeok sz."],
    kepvis_ossz: r["kepvis_ossz"],
    Mores_1: r["Mores 1"],
    Mores_1_conf: r["Mores 1 conf."],
    Mores_moral: r["Mores_moral"],
    mores_emotion: r["Mores 1"]
  }
end

stats = CampaignMetrics.engagement_distribution(struct_rows)

# Generate report
cand_key = options[:politician].to_s.strip.split(/\s+/).map { |w| w[0] }.join.upcase
plat_key = options[:platform].to_s.downcase.include?("face") ? "FB" : "IG"
default_report = Dir.exist?("reports") ? File.join("reports", "CAMPAIGN_REPORT_#{cand_key}_#{plat_key}.md") : "CAMPAIGN_REPORT_#{cand_key}_#{plat_key}.md"
options[:output_report] ||= default_report

report_content = CampaignReportGenerator.generate_markdown_report(
  options[:politician],
  options[:platform],
  options[:start_date],
  options[:end_date],
  stats,
  struct_rows.first(5),
  struct_rows.last(5)
)

File.write(options[:output_report], report_content, encoding: "utf-8")
puts "🟢 Kampány-optimalizálási jelentés elmentve: #{options[:output_report]}"

# Export updated CSV if requested
default_out_csv = Dir.exist?("reports") ? File.join("reports", "CAMPAIGN_OPTIMIZED_#{File.basename(options[:input_csv])}") : "CAMPAIGN_OPTIMIZED_#{File.basename(options[:input_csv])}"
options[:output_csv] ||= default_out_csv

if rows.any?
  headers = rows.first.keys
  CSV.open(options[:output_csv], "w", col_sep: sep, encoding: "utf-8", write_headers: true, headers: headers) do |csv|
    rows.each { |r| csv << r.values }
  end
  puts "🟢 Bővített, érzelemelemzett adatbázis elmentve: #{options[:output_csv]}"
else
  puts "ℹ️ Nincs exportálható sor a megadott időszakban (#{options[:start_date]} -> #{options[:end_date]})."
end
puts "Feldolgozás sikeresen befejeződött!"
