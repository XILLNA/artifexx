# encoding: utf-8
# ==============================================================================
# ELTE TK MORES Érzelem- és Morál-osztályozó Modul
# ==============================================================================

module MoresClassifier
  EMOTION_LEXICON = {
    "Anger" => [
      "düh", "dühös", "felháborító", "elég volt", "tűrhetetlen", "hazugság", "hazudik",
      "hazudnak", "szégyen", "szégyellje", "számonkérés", "tolvaj", "tolvajok", "korrupció",
      "rablás", "gazember", "gazemberek", "pofátlan", "botrány", "bűncselekmény", "bűnöző",
      "maffia", "felelősségre", "börtön", "megfélemlítés", "fenyegetnek", "elhallgatják",
      "propaganda", "elnyomás", "megbukik", "bukás", "áruló", "le kell váltani", "aljas"
    ],
    "Fear" => [
      "veszély", "veszélyes", "fenyegetés", "háború", "háborús", "katasztrófa", "válság",
      "összeomlás", "vigyázat", "félelem", "aggodalom", "kockázat", "megtámadták", "támadás",
      "veszélyben", "veszteség", "fenyeget", "megszorítás", "elszegényedés", "háborúba sodor",
      "katonák", "nukleáris", "infláció", "romlás", "kiszolgáltatott", "baj van"
    ],
    "Hope" => [
      "remény", "változás", "új korszak", "új kezdet", "hiszünk", "hit", "megcsináljuk",
      "felemelkedés", "győzni fogunk", "győzelem", "jövő", "szebb jövő", "bízunk", "bizalom",
      "talpra", "van remény", "megújulás", "szabadság", "rendszerváltás", "virágzó",
      "képesek vagyunk", "együtt sikerül", "megoldás", "fejlődés", "jobb élet", "megmentjük"
    ],
    "Enthusiasm" => [
      "óriási", "siker", "köszönjük", "rengetegen", "hatalmas", "energia", "fantasztikus",
      "csodálatos", "csoda", "hajrá", "együtt", "árad", "árad a tisza", "tele a tér",
      "megtelt", "ünnep", "tömeg", "lelkesedés", "taps", "erősek vagyunk", "lendület",
      "hangulat", "fantasztikusak vagytok", "találkozzunk", "történelmi", "rekord"
    ],
    "Pride" => [
      "büszkeség", "büszke", "magyarok", "magyar", "nemzet", "nemzeti", "szuverenitás",
      "hazánk", "haza", "tisztelet", "eredmény", "eredmények", "bajnokok", "hagyomány",
      "ősök", "örökség", "magyarország az első", "kitartás", "helytállás", "bátorság",
      "erős nemzet", "önbecsülés", "egyedülálló", "világhírű"
    ],
    "Sadness" => [
      "részvét", "tragédia", "fájdalom", "nehéz", "szomorú", "szomorúság", "emlékezünk",
      "gyász", "áldozat", "veszteség", "könnyek", "elveszítettük", "mély megrendülés",
      "fájó", "nyugodjék békében", "együttérzés", "elesettek", "szegénység", "elhagyatott"
    ],
    "Disgust" => [
      "undorító", "aljas", "gyomorforgató", "morális fertő", "lealacsonyító", "hitvány",
      "ocsmány", "mocskos", "szemét", "szánalmas", "képmutató", "hányinger", "erkölcstelen",
      "züllött", "megvetendő"
    ]
  }.freeze

  MORAL_FOUNDATIONS_MAP = {
    "Anger" => "Fairness/Cheating",
    "Fear" => "Care/Harm",
    "Hope" => "Liberty/Oppression",
    "Enthusiasm" => "Loyalty/Betrayal",
    "Pride" => "Loyalty/Betrayal",
    "Sadness" => "Care/Harm",
    "Disgust" => "Sanctity/Degradation"
  }.freeze

  def self.classify(text)
    clean_text = text.to_s.strip.downcase
    if clean_text.empty? || clean_text == "-" || clean_text.include?("error")
      return { emotion: "-", confidence: "0%", moral: "-" }
    end

    scores = Hash.new(0)

    EMOTION_LEXICON.each do |emotion, keywords|
      keywords.each do |kw|
        # Count keyword occurrences
        matches = clean_text.scan(/\b#{Regexp.escape(kw)}\b/).size
        scores[emotion] += matches * 2
        # Partial match if not caught by word boundary
        scores[emotion] += 1 if matches == 0 && clean_text.include?(kw)
      end
    end

    # Sentiment booster punctuation
    exclamation_count = clean_text.scan("!").size
    scores["Anger"] += [exclamation_count, 3].min if scores["Anger"] > 0
    scores["Enthusiasm"] += [exclamation_count, 4].min if scores["Enthusiasm"] > 0

    total_score = scores.values.sum
    if total_score == 0
      return { emotion: "Neutral", confidence: "75%", moral: "Liberty/Oppression" }
    end

    # Find winner
    top_emotion, top_score = scores.max_by { |_, score| score }
    conf_ratio = (top_score.to_f / total_score).round(2)
    # Scale confidence realistically between 55% and 95%
    scaled_conf = [55 + (conf_ratio * 40).round, 95].min

    {
      emotion: top_emotion,
      confidence: "#{scaled_conf}%",
      moral: MORAL_FOUNDATIONS_MAP[top_emotion] || "Fairness/Cheating"
    }
  end
end
