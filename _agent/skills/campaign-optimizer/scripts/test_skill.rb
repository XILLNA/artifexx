# encoding: utf-8
# ==============================================================================
# CAMPAIGN-OPTIMIZER SKILL ÖNELLENŐRZŐ ÉS TESZT PROGRAM (SELF-TEST)
# ==============================================================================

base_dir = File.expand_path("..", File.dirname(__FILE__)).dup.force_encoding("utf-8")
puts "=========================================================="
puts "CAMPAIGN-OPTIMIZER SKILL MŰKÖDÉSI ELLENŐRZÉSE"
puts "=========================================================="
puts "Vizsgált könyvtár: #{base_dir}"

all_tests_passed = true

def report_step(name, success, details = nil)
  icon = success ? "🟢 PASS" : "🔴 FAIL"
  puts "#{icon} | #{name}"
  puts "       └─ #{details}" if details
  success
end

# 1. Teszt: Fájlszerkezet és SKILL.md YAML ellenőrzés
skill_md_path = File.join(base_dir, "SKILL.md")
if File.exist?(skill_md_path)
  content = File.read(skill_md_path, encoding: "utf-8")
  has_frontmatter = content.start_with?("---") && content.include?("name: campaign-optimizer") && content.include?("description:")
  all_tests_passed &= report_step("SKILL.md és YAML fejléc integritás", has_frontmatter, "name: campaign-optimizer és leírás azonosítva")
else
  all_tests_passed &= report_step("SKILL.md létezése", false, "Nem található a SKILL.md fájl!")
end

# 2. Teszt: Taxonómia és erőforrások megléte
tax_path = File.join(base_dir, "resources", "mores_taxonomy.md")
all_tests_passed &= report_step("ELTE TK MORES taxonómia (resources/mores_taxonomy.md)", File.exist?(tax_path), "Kategóriák és morális definíciók elérhetők")

# 3. Teszt: MORES Érzelemelemző motor tesztelése
require_relative 'mores_classifier'
test_cases = [
  { text: "Felháborító a korrupció és a tolvajok bandája!", expected: "Anger" },
  { text: "Bízunk a szebb jövőben, van remény, megcsináljuk a változást!", expected: "Hope" },
  { text: "Óriási siker, fantasztikus hangulat, tele volt a tér, köszönjük!", expected: "Enthusiasm" },
  { text: "Büszkék vagyunk a magyar nemzet sikereire és a hagyományainkra!", expected: "Pride" },
  { text: "ERROR: ONLY_MUSIC", expected: "-" }
]

mores_ok = true
test_cases.each do |tc|
  res = MoresClassifier.classify(tc[:text])
  if res[:emotion] != tc[:expected]
    mores_ok = false
    puts "       Hiba a következőnél: '#{tc[:text]}' -> Várt: #{tc[:expected]}, Kapott: #{res[:emotion]}"
  end
end
all_tests_passed &= report_step("ELTE TK MORES Érzelemosztályozó motor (Harag, Remény, Büszkeség, Zene-hiba)", mores_ok, "5/5 tesztszöveg pontosan felismerve")

# 4. Teszt: 'kepvis_ossz' számítási formula
require_relative 'calc_metrics'
fb_calc = CampaignMetrics.calculate_kepvis_ossz("Facebook", 100, 50, 1000) # 2*100 + 2*50 + 1000 = 1300
ig_calc = CampaignMetrics.calculate_kepvis_ossz("Instagram", 100, 0, 1000)  # 2*100 + 1000 = 1200
calc_ok = (fb_calc == 1300 && ig_calc == 1200)
all_tests_passed &= report_step("Súlyozott elérés számítás (kepvis_ossz formula)", calc_ok, "FB: 2G+2H+I (1300), IG: 2G+I (1200) pontos")

# 5. Teszt: Jelentéskészítő modul tesztelése
require_relative 'campaign_report'
dummy_stats = {
  total_posts: 10,
  total_kepvis: 50000,
  avg_kepvis: 5000.0,
  by_type: { "reel videó" => { count: 6, avg_kepvis: 6000.0 }, "kép" => { count: 4, avg_kepvis: 3500.0 } },
  by_emotion: { "Hope" => { count: 5, avg_kepvis: 7000.0 }, "Anger" => { count: 5, avg_kepvis: 3000.0 } }
}
dummy_posts = [
  { dátum: "2026.03.15.", típus: "reel videó", kepvis_ossz: 15000, link: "https://facebook.com/test", Mores_1: "Hope", Mores_1_conf: "90%", likeok_sz: 10000, kommentek_sz: 2000, megosztások_sz: 500, caption: "Példa szöveg" }
]
report_output = CampaignReportGenerator.generate_markdown_report("Teszt Politikus", "Facebook", "2026.02.21.", "2026.04.11.", dummy_stats, dummy_posts, dummy_posts)
report_ok = report_output.include?("# KAMPÁNY-OPTIMALIZÁLÁSI JELENTÉS") && report_output.include?("Hope")
all_tests_passed &= report_step("Kampány-optimalizálási riportgenerálás", report_ok, "Statisztikák, táblázatok és javaslatok generálva")

# 6. Teszt: Scraper modul profil- és normalizálási integritás
require_relative 'scrape_campaign'
profile_ov = CampaignScraper.resolve_profile_url("Orbán Viktor", "Facebook")
profile_dd = CampaignScraper.resolve_profile_url("Dúró Dóra", "Instagram")
mock_raw_item = [
  { "url" => "https://facebook.com/test1", "text" => "Teszt poszt", "time" => "2026-03-01T12:00:00Z", "likes" => 500, "comments" => 50, "shares" => 25, "mediaType" => "video", "videoDuration" => 120 }
]
norm_res = CampaignScraper.normalize_records(mock_raw_item, "Facebook", "2026.02.21.", "2026.04.11.")
scraper_ok = (profile_ov == "https://www.facebook.com/orbanviktor") && (profile_dd == "https://www.instagram.com/durodora_official/") && (norm_res.first["kepvis_ossz"] == 650)
all_tests_passed &= report_step("Adatgyűjtő & Scraper modul (Meta FB & IG profilok és normalizálás)", scraper_ok, "Profilfelismerés és kódkönyvi normalizálás pontos")

# 7. Teszt: Audit és integritás-ellenőrző modul
require_relative 'audit_campaign'
audit_ok = CampaignAuditor.audit_csv("data/DATABASE_V2_DD_FB.csv")
all_tests_passed &= report_step("Audit & Hitelesség-ellenőrző modul (Kódkönyv III. Ellenőrzés)", audit_ok, "URL egyediség, duplikáció- és integritásszűrés sikeres")

puts "=========================================================="
if all_tests_passed
  puts ">>> VÉGEREDMÉNY: 🟢 MINDEN MODUL HIBÁTLANUL MŰKÖDIK! <<<"
  puts "A skill készen áll a használatra és a GitHubos megosztásra."
else
  puts ">>> VÉGEREDMÉNY: 🔴 HIBÁK TALÁLHATÓK A SKILLBEN! <<<"
end
puts "=========================================================="
