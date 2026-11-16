# ELTE TK MORES Érzelem- és Morál-taxonómia

Az **ELTE Társadalomtudományi Kutatóközpont (TK) Politikatudományi Intézet / PoltextLAB** és a nemzetközi **MORES** (Moral and Emotional Sentiments in Politics) kutatási keretrendszer alapján az alábbi érzelmi és morális kategóriákat alkalmazzuk a politikai közösségi média posztok osztályozására.

---

## 1. Diszkrét politikai érzelmek (Discrete Political Emotions)

| Érzelem (Kódkönyvi név) | Angol megnevezés | Definíció és politikai funkció | Tipikus nyelvi markerek és kulcsszavak |
|---|---|---|---|
| **Harag** | `Anger` | Igazságtalanság, korrupció, visszaélés vagy politikai ellenfél elleni felháborodás kifejezése. Erős mozgósító erő. | *düh, felháborító, elég volt, tűrhetetlen, gazemberek, hazugság, szégyen, számonkérés* |
| **Félelem** | `Fear` | Fenyegetettség, egzisztenciális veszély, háború, gazdasági összeomlás vagy külső támadás hangsúlyozása. | *veszély, fenyegetés, háború, katasztrófa, összeomlás, vigyázat, félelem, kockázat* |
| **Remény** | `Hope` | Pozitív jövőkép, rendszerváltás, felemelkedés, a nehézségek leküzdésének hite és optimizmus. | *változás, remény, új korszak, hiszünk, megcsináljuk, felemelkedés, győzni fogunk, jövő* |
| **Lelkesedés** | `Enthusiasm` | Közösségi siker, népszerűség, rendezvények dinamizmusa, tömeges támogatás öröme. | *óriási siker, köszönjük, rengetegen voltunk, csodálatos, hatalmas energia, hajrá, együtt* |
| **Büszkeség** | `Pride` | Nemzeti, közösségi vagy lokális identitás és elért sikerek, tradíciók elismerése. | *büszkeség, magyarok, szuverenitás, hazánk, tisztelet, eredmények, győzelem, bajnokok* |
| **Szomorúság** | `Sadness` | Veszteség, empátia, gyász, elesettek iránti részvét vagy csalódottság kifejezése. | *részvét, tragédia, fájdalom, nehéz napok, szomorú, emlékezünk, gyász, áldozat* |
| **Undor / Megvetés** | `Disgust` | Az ellenfél morális alkalmatlanságának, romlottságának vagy gusztustalan viselkedésének elutasítása. | *undorító, aljas, gyomorforgató, morális fertő, lealacsonyító, hitvány* |
| **Semleges** | `Neutral` | Tárgyilagos információközlés, esemény időpontja, technikai hirdetés érzelmi felhang nélkül. | *bejelentés, találkozó, közvetítés, időpont, részletek, sajtótájékoztató* |

---

## 2. Morális Alapok (Moral Foundations - Jonathan Haidt elmélete)

A MORES modell a beszédek és posztok mögött meghúzódó mélyebb morális dimenziókat is rögzíti:

1. **Gondoskodás / Ártás (`Care/Harm`):** Az elesettek, betegek, családok védelme vs. az embereknek okozott kár.
2. **Méltányosság / Csalás (`Fairness/Cheating`):** Igazságosság, jogállamiság, egyenlő esélyek vs. lopás, csalás, korrupció.
3. **Hűség / Árulás (`Loyalty/Betrayal`):** A közösséghez, nemzethez, mozgalomhoz való hűség vs. hazaárulás, átállás.
4. **Tekintély / Felforgatás (`Authority/Subversion`):** A rend, törvények, intézmények és vezetők tisztelete vs. anarchia, káosz.
5. **Szentség / Megszentségtelenítés (`Sanctity/Degradation`):** Vallási, nemzeti, kulturális tisztaság és értékek vs. züllés, rombolás.
6. **Szabadság / Elnyomás (`Liberty/Oppression`):** Személyes szabadság, függetlenség, szuverenitás vs. diktatúra, zsarnokság, elnyomás.

---

## 3. Osztályozási és Konfidencia-számítási Irányelvek

- **`Mores 1`:** A szövegben (leírás + OCR/videóleirat) dominánsan jelen lévő **elsődleges érzelem** neve.
- **`Mores 1 conf.`:** A besorolás valószínűségi értéke százalékos formában (`0% - 100%`).
  - `> 80%`: Egyértelmű, erős érzelmi szókincs és hangsúly.
  - `60% - 80%`: Érezhető érzelmi keretezés, de vegyes elemekkel.
  - `< 60%`: Halvány érzelmi töltet vagy több versengő érzelem jelenléte.
- **Szöveghiány kezelése:** Amennyiben egy poszt nem tartalmaz szöveget (pl. zenei videó `ERROR` státusszal és üres képleírással), a `Mores 1` értéke kötelezően `-`, a konfidencia `0%`.
