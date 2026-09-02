# Test report — Agenda Unificata

Test eseguiti realmente in Chromium headless (Playwright) su `index.html`, oltre
al controllo di sintassi (`node --check`) dell'intero script. Gli unici errori di
console sono di rete (CDN/font non raggiungibili nell'ambiente di test) e file
icona: **nessun errore di logica applicativa**.

| Area | Test | Risultato | Note / fix |
|---|---|---|---|
| Sintassi | `node --check` di tutto lo script (~1570 righe) | ✅ | nessun errore |
| Avvio | boot, splash, render iniziale, badge | ✅ | |
| Auth | form login/registrazione, "continua in locale", logout | ✅ | offline resta locale, nessun crash |
| Agenda unificata | crea evento (lavoro) da Quick Add | ✅ | compare in agenda e in "Oggi" |
| Agenda unificata | vista Giorno con griglia oraria + fascia "Orario di lavoro" derivata + now-line | ✅ | |
| Agenda unificata | vista Settimana (7 colonne) | ✅ | cols=7 |
| Agenda unificata | **sovrapposizioni**: due eventi 15:00–16:00 e 15:30–16:30 | ✅ | avviso nel modale + 2 badge "!" + banner "Possibile sovrapposizione" |
| Contesti | filtri contesto (lavoro/personale/studio/palestra/calcio) | ✅ | filtro di sola vista, dati unici |
| Modalità Lavoro | attivazione/disattivazione, flag topbar, dashboard operativa | ✅ | |
| Modalità Lavoro | Studio e Sport nascosti dal primo piano (restano in *Altro*) | ✅ | `study hidden: true, sport hidden: true` |
| Modalità Lavoro | vincoli personali visibili anche al lavoro | ✅ | pannello "Vincoli personali di oggi" |
| Persistenza | reload pagina → attività/eventi ancora presenti | ✅ | `task persisted after reload: true` |
| Lavoro | crea attività, categoria assegnata, filtri (tutte/da fare/urgenti/…) | ✅ | seed categorie Agenda Operativa presenti |
| Lavoro | gestore categorie (rinomina/colore/elimina con riassegnazione) | ✅ | |
| Da dire | punti per persona, tipo dire/chiedere, urgenza, completa | ✅ | |
| Studio | crea esame, avanzamento, fabbisogno settimanale, giorni all'esame | ✅ | calcolo velocità/fabbisogno da DayOS |
| Studio | allocazione automatica dei blocchi (materia + intervallo pagine) | ✅ | es. "pag. 21-29" assegnate per priorità |
| Studio | registra studio fatto → aggiorna pagine + sessione | ✅ | |
| Sport | schede palestra (crea/modifica), note palestra | ✅ | conteggio settimanale |
| Sport | calcio (allenamento/partita, ricorrente, orari/viaggio) | ✅ | genera blocchi in agenda con partenza/rientro |
| Statistiche | attività chiuse/aperte, ore studio, sport, per contesto, per priorità | ✅ | |
| Quick Add | "+" con contesto preselezionato (Lavoro in Modalità Lavoro) | ✅ | modificabile |
| Ricerca globale | Ctrl/⌘+K, cerca su attività/eventi/esami/categorie/persone/note/schede | ✅ | `search results for "riun": 1` |
| Backup | export JSON, export .ics (Europe/Rome), import JSON | ✅ | |
| Migrazione | import backup **DayOS** (esami/schede/calcio/blocchi) | ✅ | esame importato visibile in Studio |
| Migrazione | **idempotenza**: doppio import stesso backup | ✅ | `exam cards after double import: 1` (nessun doppione) |
| Responsive | 375 / 390 / 430 / 768 / 1024 / 1440 | ✅ | bottom-nav su mobile, sidebar/colonne su desktop, niente overflow |
| Sync (offline) | modifica → salvata in locale, stato "Offline/da inviare" | ✅ | pull/push/merge/realtime pronti (attivi con account + SQL) |

## Refactoring workspace + Pianifica settimana (2ª iterazione)

Test reali in Chromium headless (0 errori applicativi), oltre a `node --check`:

| Area | Test | Risultato | Note |
|---|---|---|---|
| Logo | monogramma MCVC iniettato in sidebar/splash/login + icone PWA full-bleed | ✅ | `#sideLogo` = data-URI PNG |
| Workspace switch | Generale↔Lavoro istantaneo (sidebar + switch mobile nel topbar) | ✅ | nessun reload |
| Home Lavoro | dashboard "Oggi al lavoro": agenda lavoro, da fare, scadenze, da dire | ✅ | vincoli personali discreti |
| Home Generale | timeline unificata + "Lavoro oggi" (urgente/pianificato) + prossimi + scadenze | ✅ | il lavoro non sparisce mai |
| Agenda Lavoro | impegni personali resi come blocchi grigi "Occupato" | ✅ | 2 blocchi busy verificati |
| Nav contestuale | in Lavoro: Studio/Sport/Settimana fuori dal primo piano, tabbar adattiva | ✅ | restano in *Altro* |
| Calcio preset | Mar/Gio allenamento + Dom partita ricorrenti (una volta, non distruttivo) | ✅ | 3 blocchi nella settimana |
| Corsa | nuovo contesto con colore/icona dedicati, in agenda e planner | ✅ | |
| Pianifica settimana | goal (palestra/corsa/studio/calcio), impegni fissi, +rapidi per giorno | ✅ | 4 goal + card giorno |
| Quick-add planner | +Palestra (rotazione scheda) / +Studio (esame urgente) / +Corsa | ✅ | 1 tocco, default intelligenti |
| Genera proposta | algoritmo deterministico sugli slot liberi | ✅ | 7 slot proposti |
| Applica settimana | proposte → eventi reali, poi svuotate | ✅ | idempotente per id |
| Integrazione | ciò che crei nel planner appare in Agenda/Studio/Sport | ✅ | unica source of truth |
| Responsive planner | desktop = griglia card; mobile (390px) = giorni impilati | ✅ | niente 7 colonne minuscole |
| Retrocompat dati | nuovi campi settings con default; nessun reset localStorage | ✅ | seed calcio con flag `_meta.seededFootball` |
| Regressione | tutte le suite precedenti (agenda/lavoro/studio/sport/import) | ✅ | 0 errori |

## Multi-dispositivo / conflitti (progettazione verificata a codice)

La sincronizzazione riusa lo schema robusto dell'Agenda Operativa, esteso al
modello unificato:

- **Fusione per collezione (CRDT)**: ogni record vince o cede in base alla "foto"
  dell'ultimo sync (`base`) — chi non ha toccato un record si fida dell'altro; a
  parità di modifica genuina vince la data più recente, con eccezioni per
  cancellazioni e attività completate.
- **Revisioni + conflitto**: `au_push(p_data, p_base_rev, p_device)` accetta solo
  se `p_base_rev` è ancora attuale; altrimenti risponde `conflict` con la versione
  buona, che il client fonde e riscrive (fino a 4 tentativi). PC a rev 25 e
  telefono a rev 24 → il telefono non cancella il lavoro del PC.
- **Anti-perdita**: `LOSS_GUARD` (client) + `au_live_count` (server) fermano un
  salvataggio che azzererebbe troppi record.
- **Realtime senza loop**: `muteUntil` dopo un push evita il ciclo pull→save→pull.
- **Storico**: ultime 40 versioni per utente in `agenda_unificata_storico`.

---

# Regression / matrice funzioni

Per ogni funzione delle due app originali: **MANTENUTA / MIGLIORATA / FUSA / SPOSTATA**.
Nessuna funzione è semplicemente scomparsa.

## Da Agenda Operativa (lavoro)

| Funzione | Esito | Dove |
|---|---|---|
| Attività (titolo, categoria, priorità 1-5, scadenza, stato, note, passaggi) | MANTENUTA | Lavoro / modale Attività |
| Sotto-attività (subtasks) | MANTENUTA | modale Attività |
| Piano del giorno / conferma / rinvii | MANTENUTA | campo "nel piano di oggi", badge "Piano di oggi" |
| Appuntamenti (agenda) | FUSA nell'agenda unica come `context:"work"` | Agenda |
| Categorie (crea/rinomina/colore/elimina+riassegna) | MANTENUTA | Lavoro → Categorie |
| Persone + "Da dire/Da chiedere" (urgenza) | MANTENUTA | Da dire |
| Scadenze / focus / prossime scadenze | MANTENUTA | Oggi, Lavoro |
| Vista Giorno / Settimana / mini-calendario | MIGLIORATA (ora multi-contesto) | Agenda |
| Inserimento rapido | MANTENUTA + esteso (Quick Add multi-tipo) | Oggi / "+" |
| Filtri ed elenco attività | MANTENUTA | Lavoro (chip filtro + ricerca) |
| Sincronizzazione Supabase (rev, conflitti, realtime, storico, anti-perdita) | MANTENUTA/MIGLIORATA | un solo backend unificato |
| Export / Import JSON, Stampa | MANTENUTA | Altro |
| Identità visiva (blu #061A31, Inter) | MANTENUTA | design system |
| Logo/brand GoProzionato/Confartigianato | RIMOSSO (spazio logo neutro) | sidebar |

## Da DayOS (personale)

| Funzione | Esito | Dove |
|---|---|---|
| Agenda giornaliera / timeline | FUSA nell'agenda unica | Agenda / Oggi |
| Organizzazione settimana / vista settimana | FUSA | Agenda → Settimana |
| Studio ed esami (pagine, velocità, ripasso, fabbisogno) | MANTENUTA | Studio |
| Allocazione automatica dello studio (materia + pagine per priorità) | MANTENUTA | Studio / blocchi `context:"study"` |
| Registrazione sessioni di studio | MANTENUTA | modale "Registra studio" |
| Palestra: schede/modelli, esercizi, note, conteggio settimanale | MANTENUTA | Sport |
| Calcio: allenamenti/partite, ricorrenza, convocazione/viaggio/margine | MANTENUTA | Sport (+ blocchi derivati in Agenda) |
| Orario di lavoro (7 giorni) | MANTENUTA come fascia derivata in agenda | Altro / Agenda |
| Obiettivi (goals) e impostazioni sonno | MANTENUTA (dati) | stato/Altro |
| Statistiche | MANTENUTA/MIGLIORATA (aggregate multi-contesto) | Statistiche |
| Export .ics (calendario) | MANTENUTA | Altro |
| Sincronizzazione DayOS (rev, realtime) | FUSA nell'unico backend | — |

## Novità introdotte dalla fusione

- **Agenda unica** con `context` per ogni evento e colori discreti.
- **Rilevazione sovrapposizioni** (avviso, badge, banner) fra qualunque contesto.
- **Modalità Generale / Lavoro** con navigazione e dashboard contestuali, persistenza per dispositivo.
- **Ricerca globale** (Ctrl/⌘+K) su tutte le entità.
- **Quick Add** unico con contesto preselezionato dalla modalità.
- **Migrazione automatica** da entrambe le app (localStorage + cloud legacy) idempotente.

## Limiti reali noti

- La migrazione **cloud** copre automaticamente solo la tabella legacy che sta
  sullo **stesso** progetto Supabase (`agenda_operativa`). I dati **cloud** di
  DayOS (progetto diverso) si portano con un **export/import JSON** una tantum:
  l'importatore riconosce il formato DayOS e fonde senza duplicati.
- L'orario di lavoro e il calcio ricorrente sono mostrati come **blocchi
  derivati** (calcolati, non salvati come eventi) per non duplicare i dati.
- Il trascina-e-rilascia sulla griglia oraria non è incluso: gli eventi si creano
  toccando una fascia o col "+".
