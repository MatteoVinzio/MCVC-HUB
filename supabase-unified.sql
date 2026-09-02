-- ============================================================================
--  AGENDA UNIFICATA — schema Supabase (UN SOLO BACKEND)
-- ----------------------------------------------------------------------------
--  Questo script e':
--    * COMPLETO      — tabella, storico, revisioni, RPC, RLS, realtime, migrazione
--    * IDEMPOTENTE   — si puo' rieseguire senza errori ne' duplicati
--    * NON DISTRUTTIVO — non contiene MAI "drop table" su dati reali
--
--  Come si usa:
--    1. Apri il progetto Supabase su cui vuoi tenere i dati (consigliato: quello
--       gia' usato dall'Agenda Operativa).
--    2. SQL Editor -> incolla tutto questo file -> Run.
--    3. Nell'app (index.html) controlla che SB_URL / SB_KEY / SB_TABLE puntino a
--       questo progetto e alla tabella "agenda_unificata".
--
--  Modello dati: una riga per utente. Il documento completo dell'app (agenda,
--  lavoro, studio, sport, impostazioni) sta nella colonna JSONB "data". La
--  concorrenza fra dispositivi e' gestita dalla colonna "rev" (revisione) con
--  controllo ottimistico dentro la funzione au_push().
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1) TABELLA PRINCIPALE (una riga per utente)
-- ---------------------------------------------------------------------------
create table if not exists public.agenda_unificata (
  user_id    uuid        primary key references auth.users(id) on delete cascade,
  data       jsonb       not null default '{}'::jsonb,
  rev        bigint      not null default 0,
  device     text        default '',
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2) STORICO (versioni precedenti — recupero e sicurezza)
-- ---------------------------------------------------------------------------
create table if not exists public.agenda_unificata_storico (
  id         bigserial   primary key,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  rev        bigint      not null,
  data       jsonb       not null,
  device     text        default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_au_storico_user_rev
  on public.agenda_unificata_storico (user_id, rev desc);

-- ---------------------------------------------------------------------------
-- 3) ROW LEVEL SECURITY — ogni utente vede SOLO i propri dati
-- ---------------------------------------------------------------------------
alter table public.agenda_unificata          enable row level security;
alter table public.agenda_unificata_storico  enable row level security;

drop policy if exists au_select on public.agenda_unificata;
drop policy if exists au_insert on public.agenda_unificata;
drop policy if exists au_update on public.agenda_unificata;
create policy au_select on public.agenda_unificata for select using (auth.uid() = user_id);
create policy au_insert on public.agenda_unificata for insert with check (auth.uid() = user_id);
create policy au_update on public.agenda_unificata for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists au_storico_select on public.agenda_unificata_storico;
drop policy if exists au_storico_insert on public.agenda_unificata_storico;
create policy au_storico_select on public.agenda_unificata_storico for select using (auth.uid() = user_id);
create policy au_storico_insert on public.agenda_unificata_storico for insert with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 4) RETE DI SICUREZZA ANTI-PERDITA
--    Conta i record "vivi" (deleted=false) nelle collezioni note del documento.
--    Serve a bloccare un salvataggio che farebbe sparire troppi elementi.
-- ---------------------------------------------------------------------------
create or replace function public.au_live_count(doc jsonb)
returns integer language plpgsql immutable as $$
declare
  k text; tot int := 0; el jsonb;
  colls text[] := array['categories','tasks','events','people','notes','exams','workouts','football'];
begin
  if doc is null then return 0; end if;
  foreach k in array colls loop
    if jsonb_typeof(doc->k) = 'array' then
      for el in select * from jsonb_array_elements(doc->k) loop
        if coalesce((el->>'deleted')::boolean, false) = false then tot := tot + 1; end if;
      end loop;
    end if;
  end loop;
  return tot;
end; $$;

-- ---------------------------------------------------------------------------
-- 5) au_pull() — lettura della riga dell'utente corrente
--    Ritorna un oggetto JSON { data, rev } oppure NULL se non esiste.
-- ---------------------------------------------------------------------------
create or replace function public.au_pull()
returns json language plpgsql security definer set search_path = public as $$
declare r public.agenda_unificata%rowtype;
begin
  select * into r from public.agenda_unificata where user_id = auth.uid();
  if not found then return null; end if;
  return json_build_object('data', r.data, 'rev', r.rev);
end; $$;

-- ---------------------------------------------------------------------------
-- 6) au_push(p_data, p_base_rev, p_device) — scrittura con controllo revisione
--    Ritorna:
--      { status:'ok',       rev }          salvato
--      { status:'conflict', rev, data }    qualcun altro ha scritto: fondi e riprova
--      { status:'blocked' }                fermato dalla rete anti-perdita
-- ---------------------------------------------------------------------------
create or replace function public.au_push(p_data jsonb, p_base_rev bigint, p_device text default '')
returns json language plpgsql security definer set search_path = public as $$
declare
  cur     public.agenda_unificata%rowtype;
  newrev  bigint;
  oldlive int;
  newlive int;
begin
  select * into cur from public.agenda_unificata where user_id = auth.uid() for update;

  -- Prima scrittura in assoluto (p_base_rev = -1 o riga assente)
  if not found then
    insert into public.agenda_unificata(user_id, data, rev, device, updated_at)
    values (auth.uid(), p_data, 1, p_device, now());
    insert into public.agenda_unificata_storico(user_id, rev, data, device)
    values (auth.uid(), 1, p_data, p_device);
    return json_build_object('status','ok','rev',1);
  end if;

  -- Conflitto: la revisione di partenza non e' piu' quella attuale
  if p_base_rev is distinct from cur.rev then
    return json_build_object('status','conflict','rev',cur.rev,'data',cur.data);
  end if;

  -- Rete anti-perdita: non lasciar crollare i record vivi in un colpo solo
  oldlive := public.au_live_count(cur.data);
  newlive := public.au_live_count(p_data);
  if oldlive > 20 and newlive < (oldlive * 0.5) then
    return json_build_object('status','blocked','rev',cur.rev);
  end if;

  newrev := cur.rev + 1;
  update public.agenda_unificata
     set data = p_data, rev = newrev, device = p_device, updated_at = now()
   where user_id = auth.uid();
  insert into public.agenda_unificata_storico(user_id, rev, data, device)
  values (auth.uid(), newrev, p_data, p_device);

  -- Sfoltisce lo storico: tiene le ultime 40 versioni per utente
  delete from public.agenda_unificata_storico s
   where s.user_id = auth.uid()
     and s.id not in (
       select id from public.agenda_unificata_storico
        where user_id = auth.uid() order by rev desc limit 40);

  return json_build_object('status','ok','rev',newrev);
end; $$;

grant execute on function public.au_pull()  to authenticated;
grant execute on function public.au_push(jsonb, bigint, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) REALTIME — l'app riceve le modifiche degli altri dispositivi
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'agenda_unificata')
  then
    execute 'alter publication supabase_realtime add table public.agenda_unificata';
  end if;
exception when others then
  raise notice 'Realtime non configurato automaticamente: %', sqlerrm;
end $$;

-- ============================================================================
-- 8) MIGRAZIONE (OPZIONALE) dai dati cloud dell'Agenda Operativa
-- ----------------------------------------------------------------------------
--  Se sullo STESSO progetto esiste gia' la tabella legacy "agenda_operativa",
--  l'app la importa automaticamente al primo accesso (vedi importLegacyCloud()).
--  In alternativa puoi pre-copiare qui la riga grezza: NON e' distruttivo, la
--  tabella legacy resta intatta. Decommenta ed esegui solo se serve.
--
--  insert into public.agenda_unificata (user_id, data, rev, device, updated_at)
--  select user_id, data, 0, 'migrazione-sql', now()
--    from public.agenda_operativa
--   on conflict (user_id) do nothing;   -- non sovrascrive dati unificati esistenti
--
--  NB: la fusione fine (attivita', appuntamenti, categorie) la fa comunque l'app
--  lato client con id stabili; questa copia serve solo come rete di sicurezza.
-- ============================================================================

-- Fine. Rieseguibile in sicurezza.
