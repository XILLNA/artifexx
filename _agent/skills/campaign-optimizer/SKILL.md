---
name: campaign-optimizer
description: >-
  Politikai közösségi média kampányok adatgyűjtése és optimalizálása (kizárólag Facebook és Instagram).
  Automatikusan lekaparja (scrape) a valós posztokat (Apify API), elvégzi a videók leiratozását
  (max. 5 perc szabály, csak zene -> ERROR), az OCR idézetkártya-kezelést, kiszámítja a kepvis_ossz
  engagement mutatót, lefuttatja az ELTE TK MORES érzelem- és morál-osztályozást minden egyes bejegyzésre,
  és stratégiai kampány-optimalizálási elemzést generál.
---

# CAMPAIGN-OPTIMIZER — Politikai Kampány- és Érzelem-optimalizáló Skill

A **`campaign-optimizer`** egy végponttól végpontig (end-to-end) automatizált ágens-skill, amely politikai közösségi média adatokat gyűjt be és dolgoz fel (kizárólag **Facebook** és **Instagram** felületeken), elvégzi a multimodális leiratozást, kiszámítja a súlyozott elérést (`kepvis_ossz`), az **ELTE TK MORES** modell szerint érzelemelemzést hajt végre minden egyes sorra, és stratégiai kampány-optimalizálási döntéstámogató riportot készít.

---

## 1. Működési elv és a 4 kötelező bemeneti paraméter

Amikor a felhasználó aktiválja a skillt (pl. `/campaign-optimizer` paranccsal vagy természetes nyelvű kéréssel), az ágensnek a következő **4 paramétert** kell azonosítania, illetve ha bármelyik hiányzik, **köteles rákérdezni a felhasználónál**:

1. **Apify API Token (`APIFY_TOKEN`):** A valós Meta (Facebook & Instagram) adatok lekaparásához szükséges hitelesítési kulcs (pl. `apify_api_...`).
2. **Politikus neve:** pl. *Orbán Viktor*, *Magyar Péter*, *Dúró Dóra*, *Toroczkai László* stb.
3. **Közösségi média platform:** kizárólag *Facebook* vagy *Instagram*.
4. **Időintervallum:** kezdő és záró dátum `YYYY.MM.DD.` formátumban (pl. *2026.02.21. – 2026.04.11.* vagy *2026.11.12. – 2026.11.17.*).

> [!IMPORTANT]
> **Kötelező paraméter-bekérés és szigorú adatintegritási szabály (Zero Hallucination):**  
> - Amennyiben a felhasználó bármelyik fenti paramétert nem adta meg a parancs kiadásakor, az ágens **azonnal kérdezzen rá a hiányzó érték(ek)re**, és csak az összes adat beérkezése után indítsa el a folyamatot!
> - A rendszer **soha nem generálhat szintetikus, kitalált vagy becsült posztadatokat**. Amennyiben nem áll rendelkezésre helyi adatbázis a `data/` mappában és nincs megadva érvényes Apify token, a skill kötelezően megáll, és bekéri a tokent vagy a kézi CSV exportot.

---

## 2. A feldolgozási folyamat lépései

### 0. lépés: Automatikus Adatgyűjtés (Scraping — Facebook & Instagram)
- Ha a kért politikushoz nem található előre elhelyezett CSV adatbázis a `data/` mappában, a rendszer automatikusan aktiválja a `scrape_campaign.rb` modult.
- **Támogatott platformok:** Kizárólag Facebook és Instagram.
- **Apify felhős aktorok:** A Meta botvédelmét és bejelentkezési falait kikerülő, kódkönyv szerinti adatgyűjtés (`apify~facebook-posts-scraper`, `apify~instagram-scraper`).
- A kinyert bejegyzéseket közvetlenül a kódkönyv szerinti `data/DATABASE_V2_[KÓD]_[PLATFORM].csv` struktúrára normalizálja.

### 1. lépés: Adatbetöltés és időbeli szűrés
- A rendszer betölti a releváns adatbázist (pl. `DATABASE_V2_OV_FB.csv`, `DATABASE_V2_MP_IG.csv` stb.).
- Leválogatja a pontosan a megadott dátumhatárok közé eső rekordokat.

### 2. lépés: Multimodális leiratozás és OCR szabályok
- **Legfeljebb 5 perces videók:** A videók elhangzott beszéde leiratozásra kerül a `szöveg` mezőbe.
- **Kivételek szigorú kezelése:**
  - Ha a videó **5 percnél hosszabb**: a `szöveg` mező értéke kötelezően `ERROR`.
  - Ha a videóban **kizárólag zene található** (nincs emberi beszéd): a `szöveg` mező értéke `ERROR`.
- **Képi idézetek és feliratok (OCR):**
  - Ha a bejegyzés kép, de felirat/idézet van rajta, a típus automatikusan **`kép szöveggel`** kategóriára módosul, és az OCR szöveg a `szöveg` oszlopba kerül.
  - A felirat nélküli fotók kötelezően kötőjelet (`"-"`) kapnak.

### 3. lépés: Súlyozott interakciós index (`kepvis_ossz`)
A kódkönyvben rögzített módszertan szerint minden sorban kiszámításra kerül a mutató:
* **Facebook:**
  $$\text{kepvis\_ossz} = 2 \times \text{komment} + 2 \times \text{megosztás} + \text{like}$$
* **Instagram:**
  $$\text{kepvis\_ossz} = 2 \times \text{komment} + \text{like}$$

### 4. lépés: ELTE TK MORES Érzelem- és Morál-osztályozás
Minden egyes bejegyzés sorára lefut az **ELTE TK MORES** (Moral and Emotional Sentiments in Politics) osztályozó:
* **`Mores 1` (Elsődleges érzelem):** A poszt leírása (`caption`) és kinyert szövege (`szöveg`) alapján meghatározott domináns politikai érzelem:
  * `Anger` (Harag / Felháborodás)
  * `Fear` (Félelem / Veszélyérzet)
  * `Hope` (Remény / Változás)
  * `Enthusiasm` (Lelkesedés / Mozgósítás)
  * `Pride` (Büszkeség / Nemzeti identitás)
  * `Sadness` (Szomorúság / Együttérzés)
  * `Disgust` (Undor / Morális elutasítás)
  * `Neutral` (Tárgyilagos információközlés)
* **`Mores 1 conf.` (Magabiztosság):** A besorolás konfidencia-értéke százalékban kifejezve (pl. `85%`).
* **`Mores_moral` (Morális alap):** A Jonathan Haidt-féle 6 morális dimenzió egyike (pl. *Fairness/Cheating*, *Care/Harm*, *Liberty/Oppression*).

### 5. lépés: Kampány-optimalizálási elemzés és riport
Az ágens kiszámítja az összesített statisztikákat, és egy strukturált döntéstámogató jelentést generál:
1. **Érzelmi hatékonyság:** Melyik érzelem hozta a legmagasabb átlagos `kepvis_ossz` értéket?
2. **Formátum-hatékonyság:** A reel videók, a hosszú videók vagy a szöveges képek értek el nagyobb interakciós arányt?
3. **Top performerek:** A legerősebb 5 poszt részletes boncolása.
4. **Cselekvési javaslatok a kampánystábnak:** Milyen üzeneteket és formátumokat érdemes indítani a maximális eléréshez.

---

## 3. Futtatás és Használat

### A. Teljes folyamat automatikus adatgyűjtéssel (ha hiányzik a CSV):
```bash
# Apify token beállítása után automatikus scraping és elemzés:
export APIFY_TOKEN="apify_api_..."

ruby .agent/skills/campaign-optimizer/scripts/process_campaign.rb \
  --politician "Dúró Dóra" \
  --platform "Facebook" \
  --scrape
```

### B. Önálló scraping futtatása:
```bash
ruby .agent/skills/campaign-optimizer/scripts/scrape_campaign.rb \
  --politician "Dúró Dóra" \
  --platform "Instagram" \
  --start "2026.02.21." \
  --end "2026.04.11." \
  --token "apify_api_..."
```

### C. Meglévő adatbázis feldolgozása:
```bash
ruby .agent/skills/campaign-optimizer/scripts/process_campaign.rb \
  --politician "Orbán Viktor" \
  --platform "Facebook" \
  --start "2026.02.21." \
  --end "2026.04.11."
```

---

## 4. Kimeneti fájlok

1. **Nyers begyűjtött adatbázis (`data/`):** `DATABASE_V2_[KÓD]_[PLATFORM].csv`
2. **Optimalizált, kibővített adathalmaz (`reports/`):** `CAMPAIGN_OPTIMIZED_[FÁJLNÉV].csv`  
   Minden sorban szerepelnek a nyers adatok, a `szöveg`, a `kepvis_ossz`, valamint a `Mores 1`, `Mores 1 conf.` és `Mores_moral` mezők.
3. **Optimalizálási Jelentés (`reports/`):** `CAMPAIGN_REPORT_[KÓD]_[PLATFORM].md` (és beépített artifact)
