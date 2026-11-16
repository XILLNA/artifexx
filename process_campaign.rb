# encoding: utf-8
require 'fileutils'
require 'date'
require 'optparse'
require 'csv'

require_relative 'mores_classifier'
require_relative 'calc_metrics'
require_relative 'campaign_report'

options = {
  politician: "Orbán Viktor",
  platform: "Facebook",
  start_date: "2026.02.21.",
  end_date: "2026.04.11.",
  input_csv: nil,
  output_csv: nil,
  output_report: nil
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
end.parse!

puts "=========================================================="
puts "CAMPAIGN-OPTIMIZER ELEMZŐ FOLYAMAT"
puts "=========================================================="
puts "Politikus: #{options[:politician]}"
puts "Platform: #{options[:platform]}"
puts "Időintervallum: #{options[:start_date]} -> #{options[:end_date]}"

# Auto-locate default CSV if not provided
unless options[:input_csv] && File.exist?(options[:input_csv])
  cand_key = options[:politician].downcase.include?("orb") ? "OV" : "MP"
  plat_key = options[:platform].downcase.include?("face") ? "FB" : "IG"
  default_csv = "DATABASE_V2_#{cand_key}_#{plat_key}.csv"
  
  # Search in workspace root or current dir
  candidates = [default_csv, "../#{default_csv}", "../../#{default_csv}", "artifex_skill_pilot/#{default_csv}"]
  found = candidates.find { |c| File.exist?(c) }
  if found
    options[:input_csv] = found
    puts "Automatikusan kiválasztott forrás: #{found}"
  else
    puts "HIBA: Nem található bemeneti CSV fájl a következőhöz: #{cand_key}_#{plat_key}"
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
  only_music = h["csak_zene"].to_s.downcase == "true"

  if video_duration_sec > 300
    h["szöveg"] = "ERROR: >5 MIN"
  elsif only_music
    h["szöveg"] = "ERROR: ONLY_MUSIC"
  end

  # 2. Idézetkártyák kezelése
  if h["típus"] == "kép" && h["szöveg"] && !h["szöveg"].strip.empty? && h["szöveg"] != "-" && !h["szöveg"].include?("ERROR")
    h["típus"] = "kép szöveggel"
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
options[:output_report] ||= "campaign_optimization_report.md"
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
options[:output_csv] ||= "CAMPAIGN_OPTIMIZED_#{File.basename(options[:input_csv])}"
headers = rows.first.keys
CSV.open(options[:output_csv], "w", col_sep: sep, encoding: "utf-8", write_headers: true, headers: headers) do |csv|
  rows.each { |r| csv << r.values }
end
puts "🟢 Bővített, érzelemelemzett adatbázis elmentve: #{options[:output_csv]}"
puts "Feldolgozás sikeresen befejeződött!"
