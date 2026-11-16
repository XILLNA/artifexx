---
name: campaign-optimizer
description: >-
  Politikai közösségi média kampányok optimalizálása, interaktív szűrés politikus, platform és időintervallum
  alapján. Elvégzi a videók leiratozását (max. 5 perc szabály, csak zene -> ERROR), az OCR idézetkártya-kezelést,
  kiszámítja a kepvis_ossz engagement mutatót, lefuttatja az ELTE TK MORES érzelem- és morál-osztályozást minden
  egyes bejegyzésre, és stratégiai kampány-optimalizálási elemzést generál. Aktiváld, ha a felhasználó
  kampányoptimalizálást, politikus/platform/időszak alapú elemzést, 'kepvis_ossz' számítást vagy MORES érzelemelemzést kér.
---

# CAMPAIGN-OPTIMIZER — Politikai Kampány- és Érzelem-optimalizáló Skill

A **`campaign-optimizer`** egy végponttól végpontig (end-to-end) automatizált ágens-skill, amely politikai közösségi média adatokat dolgoz fel három bemeneti paraméter alapján, elvégzi a multimodális leiratozást, kiszámítja a súlyozott elérést (`kepvis_ossz`), az **ELTE TK MORES** modell szerint érzelemelemzést hajt végre minden egyes sorra, és stratégiai kampány-optimalizálási döntéstámogató riportot készít.

---

## 1. Működési elv és bemeneti paraméterek

Amikor a felhasználó aktiválja a skillt (pl. `/campaign-optimizer` vagy természetes nyelvű kéréssel), az ágens a következő három változót kéri be vagy azonosítja a kérésből:

1. **Politikus neve:** pl. *Orbán Viktor*, *Magyar Péter* (vagy egyéb vizsgált szereplő).
2. **Közösségi média platform:** *Facebook* vagy *Instagram*.
3. **Időintervallum:** kezdő és záró dátum `YYYY.MM.DD.` formátumban (pl. *2026.02.21. – 2026.04.11.*).

---

## 2. A feldolgozási folyamat lépései

### 1. lépés: Adatbetöltés és időbeli szűrés
- A rendszer betölti a releváns adatbázist (pl. `DATABASE_V2_OV_FB.csv`, `DATABASE_V2_MP_IG.csv` stb.).
- Leválogatja a pontosan a megadott dátumhatárok közé eső rekordokat.

### 2. lépés: Multimodális leiratozás és OCR szabályok
- **Legfeljebb 5 perces videók:** A videók elhangzott beszéde leiratozásra kerül a `szöveg` mezőbe.
- **Kivételek szigorú kezelése:**
  - Ha a videó **5 percnél hosszabb**: a `szöveg` mező értéke kötelezően `ERROR: >5 MIN`.
  - Ha a videóban **kizárólag zene található** (nincs emberi beszéd): a `szöveg` mező értéke `ERROR: ONLY_MUSIC`.
- **Képi idézetek és feliratok (OCR):**
  - Ha a bejegyzés kép, de felirat/idézet van rajta, a típus automatikusan **`kép szöveggel`** kategóriára módosul, és az OCR szöveg a `szöveg` oszlopba kerül.

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
1. **Érzelmi hatékonyság:** Melyik érzelem hozta a legmagasabb átlagos `kepvis_ossz` értéket? (Pl. a remény és lelkesedés jobban mozgósított-e, mint a harag?)
2. **Formátum-hatékonyság:** A reel videók, a hosszú videók vagy a szöveges képek érték el a nagyobb interakciós arányt?
3. **Top performerek:** A legerősebb 5 poszt részletes boncolása (üzenet, közzétételi időpont, vizuális keretezés).
4. **Cselekvési javaslatok a kampánystábnak:** Milyen üzeneteket, mikor és milyen formában érdemes indítani a maximális konverzióhoz.

---

## 3. Futtatás és Használat

A pipeline a mellékelt Ruby szkriptekkel azonnal futtatható a terminálból, vagy közvetlenül az ágens által:

```bash
ruby .agent/skills/campaign-optimizer/scripts/process_campaign.rb \
  --politician "Magyar Péter" \
  --platform "Facebook" \
  --start "2026.02.21." \
  --end "2026.04.11." \
  --output "CAMPAIGN_OPTIMIZED_MP_FB.csv" \
  --report "CAMPAIGN_REPORT_MP_FB.md"
```

---

## 4. Kimeneti fájlok

1. **Optimalizált, kibővített adathalmaz (`.csv` / `.xlsx`):**  
   Minden sorban szerepelnek a nyers adatok, a `szöveg` (leirat vagy hibaérték), a `kepvis_ossz`, valamint a `Mores 1` és `Mores 1 conf.` mezők.
2. **Optimalizálási Jelentés (`.md` / artifact):**  
   Vezetői összefoglaló diagramokkal, hatékonysági indexekkel és stratégiai tanácsokkal.
