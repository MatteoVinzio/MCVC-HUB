# Migrazione dati — Agenda Operativa + DayOS → Agenda Unificata

Principio guida: **non si perde nulla**. I formati vecchi non vengono cancellati,
la migrazione è **idempotente** (eseguirla due volte non duplica), gli id sono
**stabili**.

Flusso: `detect → validate → migrate → verify → preserve old data`.

---

## 1. Dati trovati (inventario)

### Agenda Operativa (lavoro)
- **localStorage**
  - `confartigianato_agenda_operativa_v2` — archivio attuale (schema 2+)
  - `confartigianato_agenda_operativa_v1` — archivio legacy (migrato dall'app stessa)
  - `confartigianato_agenda_backup_pre_v2`, `..._base_v4`, `..._rev_v4`, `..._device_v4`, `..._last_rollover` — supporto/sync
- **Supabase**: progetto `dzcyiirkrklojzaljgwn`, tabella `agenda_operativa` (`user_id, data, rev, updated_at`), RPC `agenda_pull`/`agenda_push`, realtime.
- **Entità**: `categories`, `tasks` (con `subtasks`, priorità, scadenza, stato, piano, rinvii), `agenda` (appuntamenti), `people`, `notes` (da dire/chiedere). Soft-delete + `updatedAt` per record.

### DayOS (personale / studio / sport)
- **localStorage**
  - `regia_v2` — stato principale (chiave interna `DB_KEY`)
  - `dayos_device` — id dispositivo
- **Supabase**: progetto `dlssifklsezqwdcjavmm`, tabella `dayos_state` (`user_id, data, rev, updated_at`), RPC `dayos_pull`/`dayos_push`, realtime.
- **Entità**: `esami`, `workouts` (schede), `calcio`, `fixed`, `plan.blocks` (blocchi giorno: studio/palestra/vita), `settings` (orario lavoro, sonno…), `goals`, `gymNotes`, `profile`.

## 2. Modello unificato di destinazione

Un solo oggetto, `schemaVersion: 1`:

```
categories, tasks, events, people, notes,   // collezioni CRDT (fusione per id)
exams, workouts, football,                   // collezioni CRDT
settings, goals, profile, gymNotes,          // scalari (timestamp in _meta)
selectedDate, updatedAt
```

Chiave dell'unificazione: **`events`** è l'agenda unica. Ogni evento ha un
`context`: `work | personal | study | gym | football`.

| Origine | Diventa |
|---|---|
| Agenda Operativa `agenda[]` (appuntamenti) | `events` con `context:"work"` |
| DayOS `plan.blocks` tipo *studio* | `events` `context:"study"` (con `alloc` calcolata) |
| DayOS `plan.blocks` tipo *palestra* | `events` `context:"gym"` (con `workoutId`) |
| DayOS `plan.blocks` tipo *calcio/vita* | `events` `context:"football" / "personal"` |
| DayOS `fixed[]` con data | `events` `context:"personal"` |
| DayOS `esami` | `exams` |
| DayOS `workouts` | `workouts` |
| DayOS `calcio` | `football` (genera i blocchi calcio ricorrenti sull'agenda) |
| Orario di lavoro (`settings.lavoro`) | fascia **derivata** mostrata in agenda (non duplicata) |

## 3. Come avviene la migrazione

- **Automatica su dispositivo** (all'avvio, `importLegacy()`): legge da localStorage
  `confartigianato_agenda_operativa_v2/v1` e `regia_v2`, converte e **fonde** nel
  modello unificato. Ogni sorgente è marcata (per contenuto) e importata una sola
  volta → nessun doppione.
- **Automatica dal cloud** (`importLegacyCloud()`): al primo accesso, se la riga
  unificata non esiste ancora, legge la tabella legacy `agenda_operativa` **dello
  stesso progetto** e la fonde. La tabella legacy **non** viene toccata.
- **Manuale/cross-progetto** (per i dati cloud di DayOS, che stanno su un altro
  progetto): dalla vecchia app DayOS → *Esporta* JSON, poi nell'Agenda Unificata
  *Altro → Importa backup*. L'importatore riconosce il formato DayOS e lo fonde.

## 4. Idempotenza e id stabili

- Le categorie di sistema hanno id derivato dal nome (`cat_benessere`, …): due
  dispositivi partono dagli stessi id, la fusione le riconosce.
- Gli eventi migrati da DayOS usano id deterministici (`dpb_…`, `dfx_…`) → una
  seconda migrazione sovrascrive, non aggiunge.
- La fusione delle collezioni (`mergeColl`) è per `id`.
- **Verificato** nei test: doppio import dello stesso backup DayOS → nessun
  duplicato (vedi `TEST-REPORT.md`).

## 5. Fallback e sicurezza

- Se un archivio non è leggibile, l'app riparte pulita ma **non** cancella il dato
  vecchio (resta in localStorage / nella tabella legacy).
- Nessun `DROP TABLE`, nessuna cancellazione automatica dei formati precedenti.
- Puoi sempre tornare alle vecchie app: i loro dati sono intatti.
- Sync con revisioni + rete anti-perdita (`LOSS_GUARD` lato client e `au_live_count`
  lato server): un crollo improvviso del numero di record blocca il salvataggio.
