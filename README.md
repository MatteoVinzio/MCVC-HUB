# Agenda Unificata

Un'unica applicazione, un'unica agenda, un solo sistema dati — con due modalità
d'uso: **Generale** (tutta la tua vita) e **Lavoro** (la tua postazione operativa).

Nasce dalla fusione completa di due app reali:

- **Agenda Operativa** — attività, categorie, appuntamenti, persone, "da dire", scadenze (lavoro);
- **DayOS** — agenda personale, studio ed esami, palestra, calcio, statistiche, impostazioni.

Tutto vive in **una sola agenda** e in **un solo backend Supabase**. La Modalità
Lavoro cambia solo *come* vedi i dati (priorità, filtri, strumenti, dashboard),
**mai** i dati stessi: gli impegni personali restano visibili anche al lavoro,
così non pianifichi mai su una fascia che in realtà è occupata.

È un'unica pagina `index.html` (HTML + CSS + JavaScript, nessun framework):
apri il file e funziona anche offline; con un account Supabase hai gli stessi
dati su telefono, tablet e computer.

---

## 1. Quale Supabase usare

**Un solo progetto.** Consigliato: quello che già usavi per l'**Agenda
Operativa** (contiene i dati di lavoro reali). L'app è preconfigurata su quel
progetto e, al primo accesso, **importa automaticamente** la vecchia tabella
`agenda_operativa` dello stesso progetto.

Se preferisci un altro progetto, cambia i tre valori in cima allo `<script>` di
`index.html`:

```js
const SB_URL   = "https://XXXX.supabase.co";
const SB_KEY   = "sb_publishable_...";   // publishable / anon key (PUBBLICA)
const SB_TABLE = "agenda_unificata";
```

> Usa **solo** la chiave *publishable* (anon). La `service_role` non va mai messa
> in una pagina web. La protezione dei dati è nelle policy RLS dello script SQL.

## 2. Quale SQL eseguire

Esegui **una volta** `supabase-unified.sql` sul progetto scelto:

1. Supabase → **SQL Editor** → **New query**
2. Incolla tutto il contenuto di `supabase-unified.sql`
3. **Run**

Crea tabella, storico, revisioni, funzioni `au_pull`/`au_push`, RLS e realtime.
È **idempotente**: puoi rieseguirlo senza rischi. Non contiene alcun `DROP TABLE`.

## 3. Dove mettere URL e Publishable Key

Nel file `index.html`, nelle costanti `SB_URL` e `SB_KEY` (vedi punto 1). Le trovi
su Supabase in **Project Settings → API**.

## 4. Come pubblicare

L'app è un sito statico: qualunque hosting va bene.

- **GitHub Pages**: metti `index.html` (con `manifest.webmanifest` e le icone) nel
  branch pubblicato → Settings → Pages.
- **Netlify / Vercel / Cloudflare Pages**: trascina la cartella, nessuna build.
- **In locale**: apri direttamente `index.html`, oppure `python3 -m http.server`.

File da tenere insieme: `index.html`, `manifest.webmanifest`, `icon-192.png`,
`icon-512.png`, `apple-touch-icon.png`.

## 5. Come verificare la sincronizzazione

1. Apri l'app, **Accedi** (o registrati).
2. In alto/in basso a sinistra la pillola cloud deve diventare **✓ Sincronizzato**.
3. Crea un evento su un dispositivo; su un secondo dispositivo con lo stesso
   account l'evento compare da solo (realtime) o al rientro nell'app.
4. Modifica quasi in contemporanea da due dispositivi: non si perde nulla — chi
   parte da una revisione vecchia riceve un **conflitto**, fonde e riscrive.

Stato sincronizzazione (pillola discreta): `✓ Sincronizzato` · `↑ Salvataggio…`
· `☁ Offline` · `! Da inviare`.

---

## Workspace: Generale e Lavoro

Un solo database, una sola agenda, **due workspace** (interruttore in alto a
sinistra, 1 tocco — istantaneo, senza ricaricare):

- **Generale** = tutta la vita: lavoro + studio + palestra + corsa + calcio +
  personale. Il lavoro **non sparisce mai** qui. Risponde a *"Com'è organizzata
  la mia giornata e quando sono libero?"*.
- **Lavoro** = ambiente focalizzato: la Home diventa *"Oggi al lavoro"* (agenda
  di lavoro, da fare, scadenze, da dire), la navigazione mette in primo piano le
  funzioni professionali, Studio/Sport/Settimana escono dal primo piano ma
  restano in *Altro*. In agenda gli impegni personali diventano **blocchi
  "occupato"** discreti (vedi che la fascia non è libera, senza dettagli).

Il workspace è una **preferenza del singolo dispositivo** (non si sincronizza):
il PC dell'ufficio può restare in Lavoro e il telefono in Generale.

## Pianifica settimana

Da usare il sabato/domenica: apri **Settimana**, vedi gli impegni già fissi
(lavoro, appuntamenti, calcio) e distribuisci **palestra (4)**, **corsa (1)** e
**studio (4 sessioni)** con pochi tocchi. I pulsanti «+ Palestra / + Studio /
+ Corsa» creano subito la sessione con orario e durata predefiniti (palestra in
rotazione scheda, studio collegato all'esame più urgente). **Genera proposta**
propone automaticamente gli slot liberi in modo deterministico; **Applica
settimana** li conferma. Il calcio ricorrente (Mar/Gio allenamento, Dom partita)
è preimpostato e modificabile in Sport.

Tutto ciò che crei è un **evento normale**: appare in Agenda, Studio e Sport —
un'unica *source of truth*, nessun duplicato.

## Logo e icone

L'identità dell'app è il monogramma **MCVC** (sidebar, login, splash) e le icone
PWA `icon-192.png` / `icon-512.png` / `apple-touch-icon.png` (versione quadrata
full-bleed). Per cambiarlo in futuro basta sostituire quei file e il data-URI
`LOGO` in cima allo `<script>`.

## Dati e privacy

- Tutto è locale (localStorage) **e**, se accedi, su Supabase con RLS: ogni utente
  vede solo i propri dati.
- **Backup**: *Altro → Esporta/Importa backup (JSON)* e *Esporta calendario (.ics)*.
- Reimportare un backup è sicuro: la fusione avviene per **id stabile**, non duplica.
- Fuso orario: **Europe/Rome** (date e orari locali, `.ics` con `TZID=Europe/Rome`).

Vedi `MIGRATION.md` per i dettagli sulla migrazione e `TEST-REPORT.md` per i test.
