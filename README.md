# Campaign Optimizer Skill

Autonóm mesterséges intelligencia ágens-készség (skill) közösségi média politikai kampányadatok többdimenziós feldolgozásához, súlyozott elérés-számításához (`kepvis_ossz`), valamint érzelemelemzéséhez (ELTE TK MORES).

---

## Fő funkciók

1. **Kampányszűrés:** Politikus, platform (Facebook, Instagram) és időintervallum alapján.
2. **Multimodális szabályok:** Legfeljebb 5 perces videók leiratozása; 5 percnél hosszabb vagy zenei videók jelölése (`ERROR`); képi idézetek kezelése (`kép szöveggel`).
3. **Súlyozott elérés:** A `kepvis_ossz` metrika kiszámítása a hozzászólások, megosztások és kedvelések alapján.
4. **Érzelemelemzés (ELTE TK MORES):** Minden bejegyzés sorához hozzárendeli a domináns érzelmet (`Mores 1`), a konfidencia-értéket (`Mores 1 conf.`) és a morális alapot (`Mores_moral`).
5. **Stratégiai riport:** Kampány-optimalizálási összefoglaló készítése a legjobban és leggyengébben teljesítő tartalmakról.

---

## Mappaszerkezet

```text
campaign-optimizer/
├── README.md                  # Dokumentáció
├── SKILL.md                   # Ágens vezérlőfájl
├── resources/
│   └── mores_taxonomy.md      # Érzelmi és morális kategóriák definíciói
└── scripts/
    ├── mores_classifier.rb    # Érzelemosztályozó modul
    ├── calc_metrics.rb        # Metrika kalkulátor
    ├── campaign_report.rb     # Jelentéskészítő modul
    └── process_campaign.rb    # Futtatható vezérlőprogram
```

---

## Használat

### Ágens környezetben
Másold a mappát a projekt `.agent/skills/` könyvtárába, majd hívd meg az ágensben:
> *Meglévő adatbázis esetében: „Futtasd a campaign-optimizer skillt Magyar Péter Facebook posztjaira 2026.02.21 és 2026.04.11 között.”*
> 
> *Meglévő adatbázis hiányában: „Futtasd a campaign-optimizer skillt Magyar Péter Facebook posztjaira 2026.02.21 és 2026.04.11 között. Használd az API tokent az adatok elérése érdekében; <api tokened helye>”*

### Parancssorból
```bash
ruby scripts/process_campaign.rb \
  --politician "Magyar Péter" \
  --platform "Facebook" \
  --start "2026.02.21." \
  --end "2026.04.11." \
  --input "bemeneti_adatok.csv" \
  --output "optimalizalt_kimenet.csv" \
  --report "kampany_jelentes.md"
```
