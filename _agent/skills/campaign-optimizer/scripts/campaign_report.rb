# encoding: utf-8
require 'json'

module CampaignReportGenerator
  def self.generate_markdown_report(politician, platform, start_date, end_date, stats, top_posts, low_posts)
    politician = politician.to_s.dup.force_encoding("utf-8")
    platform = platform.to_s.dup.force_encoding("utf-8")
    start_date = start_date.to_s.dup.force_encoding("utf-8")
    end_date = end_date.to_s.dup.force_encoding("utf-8")
    md = []
    md << "# KAMPÁNY-OPTIMALIZÁLÁSI JELENTÉS"
    md << ""
    md << "> **Vizsgált alany:** #{politician}  "
    md << "> **Platform:** #{platform}  "
    md << "> **Vizsgált időszak:** #{start_date} – #{end_date}  "
    md << "> **Összes elemzett bejegyzés:** #{stats[:total_posts]} db  "
    md << "> **Összesített súlyozott interakció (kepvis_ossz):** #{stats[:total_kepvis].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse}  "
    md << "> **Átlagos posztonkénti elérés:** #{stats[:avg_kepvis].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse}  "
    md << ""
    md << "---"
    md << ""
    md << "## 1. Mely érzelmek mozgósítanak a legjobban? (ELTE TK MORES Elemzés)"
    md << ""
    md << "A posztok szövege és átirata alapján a MORES modell szerinti érzelmek hatása a súlyozott elérésre (`kepvis_ossz`):"
    md << ""
    md << "| Érzelem (`Mores 1`) | Bejegyzések száma | Átlagos interakció (`kepvis_ossz`) | Hatékonysági index |"
    md << "|---|:---:|:---:|:---:|"

    sorted_emotions = stats[:by_emotion].sort_by { |_, v| -v[:avg_kepvis] }
    max_avg = sorted_emotions.first ? sorted_emotions.first[1][:avg_kepvis] : 1.0

    sorted_emotions.each do |emo, data|
      ratio = ((data[:avg_kepvis] / (stats[:avg_kepvis] > 0 ? stats[:avg_kepvis] : 1.0)) * 100).round
      indicator = ratio >= 120 ? "🔥 Kiemelkedő" : (ratio >= 90 ? "🟢 Átlag feletti" : "🟡 Mérsékelt")
      md << "| **#{emo}** | #{data[:count]} db | **#{data[:avg_kepvis].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse}** | #{ratio}% (#{indicator}) |"
    end

    md << ""
    md << "---"
    md << ""
    md << "## 2. Formátumok teljesítménye (Reel vs. Videó vs. Képek)"
    md << ""
    md << "| Formátum típusa | Darabszám | Átlagos `kepvis_ossz` | Részarány |"
    md << "|---|:---:|:---:|:---:|"

    sorted_types = stats[:by_type].sort_by { |_, v| -v[:avg_kepvis] }
    sorted_types.each do |type, data|
      share = ((data[:count].to_f / stats[:total_posts]) * 100).round(1)
      md << "| `#{type}` | #{data[:count]} db | **#{data[:avg_kepvis].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse}** | #{share}% |"
    end

    md << ""
    md << "---"
    md << ""
    md << "## 3. Top 5 legsikeresebb bejegyzés (Mi tette őket virálissá?)"
    md << ""
    top_posts.first(5).each_with_index do |p, i|
      md << "### #{i + 1}. [#{p[:dátum]}] `#{p[:típus]}` — #{p[:kepvis_ossz]} elérés"
      md << "- **Link:** #{p[:link]}"
      md << "- **Domináns érzelem (MORES):** `#{p[:Mores_1]}` (Konfidencia: #{p[:Mores_1_conf]})"
      md << "- **Interakciók:** #{p[:likeok_sz]} like | #{p[:kommentek_sz]} komment | #{p[:megosztások_sz] || 0} megosztás"
      md << "- **Szövegrészlet / Idézet:** *„#{p[:caption].to_s[0..140]}...”*"
      md << ""
    end

    md << "---"
    md << ""
    md << "## 4. Stratégiai kampány-optimalizálási javaslatok"
    md << ""
    best_emotion = sorted_emotions.first ? sorted_emotions.first[0] : "Remény"
    best_type = sorted_types.first ? sorted_types.first[0] : "reel videó"

    md << "1. **Domináns érzelmi vezérfonal:** A kutatási adatok alapján a **#{best_emotion}** érzelmi keretezés váltotta ki a legintenzívebb reszponzivitást a választókból. Javasolt a kampányüzenetek fókuszát erre építeni."
    md << "2. **Optimális tartalomformátum:** A leghatékonyabb elérést a **`#{best_type}`** biztosítja. A szöveges képeket és hagyományos fotókat érdemes feliratozott, dinamikus rövid videókká formálni."
    md << "3. **Multimodális megerősítés (Idézetkártyák és feliratok):** A videók első 5 másodpercében elhelyezett hangsúlyos feliratok és a képre égetett kulcsmondatok drasztikusan növelik a megosztások arányát."
    md << "4. **Időzítés:** A kampánycsúcsok idején a napi többszöri, különböző érzelmi polaritású (pl. délelőtt tájékoztató/mozgósító, este lelkesítő/összefoglaló) posztok tartják fenn a legmagasabb átlagos engagementet."

    md.join("\n")
  end
end
