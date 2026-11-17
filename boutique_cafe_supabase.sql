-- =====================================================================
--  BOUTIQUE DE CAFÉ — SCHÉMA SUPABASE COMPLET (modèle réutilisable)
-- =====================================================================
--  COMMENT L'UTILISER
--  1. Crée un nouveau projet Supabase.
--  2. Remplace toutes les valeurs "A_REMPLIR_..." (cherche "A_REMPLIR"
--     avec Ctrl+F). Elles sont listées dans la section 12.
--  3. Colle tout le fichier dans  SQL Editor > New query  puis  Run.
--  4. Vérifie avec les requêtes de la section 13.
--  Le script peut être relancé sans casser les données existantes.
--
--  PRINCIPES
--  - Le site (navigateur) ne touche JAMAIS les tables sensibles
--    directement : il passe par des fonctions RPC (supabase.rpc(...)).
--  - Les tables publiques (produits, rayons, réglages, avis publiés)
--    sont lisibles par tout le monde, en lecture seule.
--  - L'espace admin est protégé par un mot de passe haché (bcrypt),
--    vérifié côté base dans chaque fonction gestion_*.
--  - Les prix sont recalculés côté base : le client ne peut pas les
--    falsifier.
--  - Les secrets (jeton du bot Telegram, mot de passe) sont dans le
--    schéma "private", non accessible depuis le site.
-- =====================================================================


-- =====================================================================
-- 1. EXTENSIONS
-- =====================================================================
-- pgcrypto : hachage bcrypt du mot de passe + jetons aléatoires.
-- pg_net   : envoi des notifications Telegram depuis la base.
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_net;


-- =====================================================================
-- 2. SCHÉMA PRIVÉ (secrets, jamais exposé au site)
-- =====================================================================
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Mot de passe admin (haché, jamais en clair)
create table if not exists private.admin (
  id         text primary key default 'admin' check (id = 'admin'),
  empreinte  text not null,
  maj_le     timestamptz not null default now()
);

-- Paramètres secrets : jeton du bot, chat du commerçant, adresse du site
create table if not exists private.parametres (
  cle     text primary key,
  valeur  text not null default ''
);


-- =====================================================================
-- 3. TABLES PUBLIQUES
-- =====================================================================

-- 3.1 RÉGLAGES : une seule ligne (id = 'boutique'), tout ce qui
--     personnalise le site. Rien de secret ici (lisible par tous).
create table if not exists public.reglages (
  id          text primary key default 'boutique' check (id = 'boutique'),
  nom         text not null default 'A_REMPLIR_NOM_BOUTIQUE',
  slogan      text not null default '',
  accroche    text not null default '',
  theme       text not null default 'cafe-creme',
  logo        text not null default '',      -- URL du logo (vide = texte)
  fond        text not null default '',      -- URL de l'image de fond
  fond_flou   integer not null default 60 check (fond_flou between 0 and 92),
  contact     text not null default '',
  prefixe_ref text not null default 'CAF',   -- numéros de commande : #CAF-1234
  -- Livraison : frais, minimum de commande, seuil de gratuité
  livraison   jsonb not null default
    '{"frais": 5, "minimum": 20, "gratuite_a_partir_de": 60}'::jsonb,
  -- Libellés des 5 étapes de suivi (étape 0 à 4)
  etapes      jsonb not null default
    '["Commande reçue","En préparation","Expédiée","Livraison imminente","Livrée"]'::jsonb
    check (jsonb_typeof(etapes) = 'array'),
  infos       jsonb not null default '{}'::jsonb,    -- horaires, zone, paiement...
  sections    jsonb not null default '{"avis": true, "rayons": true, "livraison": true}'::jsonb,
  reseaux     jsonb not null default '[]'::jsonb,    -- [{cle,nom,url,logo,actif}]
  maj_le      timestamptz not null default now()
);

-- 3.2 RAYONS (catégories : Grains, Moulu, Capsules...)
create table if not exists public.categories (
  id        text primary key,
  nom       text not null unique,
  emoji     text not null default '',
  position  integer not null default 0,
  cree_le   timestamptz not null default now(),
  maj_le    timestamptz not null default now()
);
create index if not exists categories_position_idx on public.categories (position);

-- 3.3 PRODUITS
--  PRINCIPE DES VARIANTES : le prix et le stock sont portés par les
--  variantes (ex. 250 g, 500 g, 1 kg). Tout produit a au moins une
--  variante. Format :
--    variantes = [{"id":"cafe1-250","nom":"250 g","prix":6.9,"stock":"disponible"}, ...]
--  OPTIONS : choix que le client doit faire (ex. la mouture), sans
--  impact sur le prix. Format :
--    options = [{"nom":"Mouture","valeurs":["Grains","Espresso","Filtre"]}]
create table if not exists public.produits (
  id           text primary key,
  nom          text not null,
  rayon        text not null default 'Divers',
  emoji        text not null default '',
  description  text not null default '',
  badge        text not null default '',          -- ex. "Nouveau", "Bio"
  unite        text not null default '',          -- ex. "sachet"
  variantes    jsonb not null default '[]'::jsonb,
  options      jsonb not null default '[]'::jsonb,
  photos       jsonb not null default '[]'::jsonb, -- URLs, dans l'ordre d'affichage
  position     integer not null default 0,
  actif        boolean not null default true,
  masque       boolean not null default false,    -- retiré de la vente sans suppression
  cree_le      timestamptz not null default now(),
  maj_le       timestamptz not null default now()
);
create index if not exists produits_position_idx on public.produits (position);

-- 3.4 COMMANDES (aucun accès direct : tout passe par les fonctions)
create table if not exists public.commandes (
  id               uuid primary key default gen_random_uuid(),
  ref              text not null unique,            -- ex. #CAF-4821
  suivi_jeton      text not null default encode(extensions.gen_random_bytes(16), 'hex'),
  etape            smallint not null default 0 check (etape between 0 and 4),
  statut           text not null default 'en_cours'
                     check (statut in ('en_cours','annulee','remboursee','archivee')),
  paiement         text not null default 'a_regler'
                     check (paiement in ('a_regler','regle')),
  mode             text not null default 'livraison'
                     check (mode in ('livraison','retrait')),
  client_nom       text not null,
  client_tel       text not null,
  client_email     text not null default '',
  adresse          text not null default '',
  code_postal      text not null default '',
  ville            text not null default '',
  articles         jsonb not null default '[]'::jsonb,
  sous_total       numeric(10,2) not null default 0,
  frais            numeric(10,2) not null default 0,
  total            numeric(10,2) not null default 0,
  telegram_client  text not null default '',        -- identifiant de chat du client
  note             text not null default '',        -- note interne (commerçant)
  message_suivi    text not null default '',        -- message visible par le client
  cree_le          timestamptz not null default now(),
  maj_le           timestamptz not null default now()
);
create index if not exists commandes_cree_le_idx on public.commandes (cree_le desc);
create index if not exists commandes_etape_idx   on public.commandes (etape);
create index if not exists commandes_jeton_idx   on public.commandes (suivi_jeton);

-- 3.5 AVIS (modérés : invisibles tant que "publie" = false)
create table if not exists public.avis (
  id       uuid primary key default gen_random_uuid(),
  note     smallint not null check (note between 1 and 5),
  auteur   text not null default 'Anonyme',
  texte    text not null default '',
  publie   boolean not null default false,
  cree_le  timestamptz not null default now()
);
create index if not exists avis_publie_idx on public.avis (publie, cree_le desc);

-- 3.6 JOURNAL D'ERREURS (notifications Telegram ratées, etc.)
create table if not exists public.journal_erreurs (
  id        uuid primary key default gen_random_uuid(),
  cree_le   timestamptz not null default now(),
  ref       text,
  contexte  text,
  message   text
);
create index if not exists journal_erreurs_cree_idx on public.journal_erreurs (cree_le desc);


-- =====================================================================
-- 4. SÉCURITÉ DES LIGNES (RLS)
-- =====================================================================
alter table public.reglages        enable row level security;
alter table public.categories      enable row level security;
alter table public.produits        enable row level security;
alter table public.commandes       enable row level security;
alter table public.avis            enable row level security;
alter table public.journal_erreurs enable row level security;
alter table private.admin          enable row level security;
alter table private.parametres     enable row level security;

-- Lecture publique, uniquement de ce qui doit être visible.
drop policy if exists reglages_lecture   on public.reglages;
drop policy if exists categories_lecture on public.categories;
drop policy if exists produits_lecture   on public.produits;
drop policy if exists avis_lecture       on public.avis;

create policy reglages_lecture   on public.reglages   for select to anon, authenticated using (true);
create policy categories_lecture on public.categories for select to anon, authenticated using (true);
create policy produits_lecture   on public.produits   for select to anon, authenticated
  using (actif = true and masque = false);
create policy avis_lecture       on public.avis       for select to anon, authenticated
  using (publie = true);

-- commandes, journal_erreurs, private.* : AUCUNE politique = personne
-- n'y accède directement depuis le site. Seules les fonctions
-- (SECURITY DEFINER) y touchent.


-- =====================================================================
-- 5. FONCTIONS INTERNES (schéma private)
-- =====================================================================

-- 5.1 Met à jour maj_le automatiquement
create or replace function private.toucher_maj_le()
returns trigger language plpgsql as $$
begin
  new.maj_le := now();
  return new;
end $$;

-- 5.2 Valide les variantes et les options d'un produit
create or replace function private.verifier_produit()
returns trigger language plpgsql as $$
declare
  v    jsonb;
  ids  text[] := '{}';
begin
  if new.variantes is null or jsonb_typeof(new.variantes) <> 'array'
     or jsonb_array_length(new.variantes) = 0 then
    raise exception 'Un produit doit avoir au moins une variante.'
      using errcode = 'check_violation';
  end if;

  for v in select * from jsonb_array_elements(new.variantes) loop
    if coalesce(v->>'id', '') = '' or coalesce(v->>'nom', '') = '' then
      raise exception 'Chaque variante doit avoir un id et un nom.'
        using errcode = 'check_violation';
    end if;
    if (v->>'prix') is null or (v->>'prix')::numeric < 0 then
      raise exception 'Prix invalide pour la variante %.', v->>'nom'
        using errcode = 'check_violation';
    end if;
    if coalesce(v->>'stock', 'disponible') not in ('disponible', 'rupture') then
      raise exception 'Stock invalide pour la variante % (disponible ou rupture).', v->>'nom'
        using errcode = 'check_violation';
    end if;
    if (v->>'id') = any (ids) then
      raise exception 'Identifiant de variante en double : %.', v->>'id'
        using errcode = 'check_violation';
    end if;
    ids := ids || (v->>'id');
  end loop;

  if new.options is null or jsonb_typeof(new.options) <> 'array' then
    raise exception 'options doit être une liste.' using errcode = 'check_violation';
  end if;

  return new;
end $$;

-- 5.3 Vérifie le mot de passe admin (bcrypt)
create or replace function private.verifier_mot_de_passe(p text)
returns boolean language sql stable security definer
set search_path = public, extensions as $$
  select coalesce(
    (select a.empreinte = extensions.crypt(coalesce(p, ''), a.empreinte)
       from private.admin a where a.id = 'admin'),
    false);
$$;

-- 5.4 Refuse l'accès si le mot de passe est faux
create or replace function private.exiger_admin(p text)
returns void language plpgsql security definer
set search_path = public, extensions as $$
begin
  if not private.verifier_mot_de_passe(p) then
    raise exception 'Mot de passe refusé.' using errcode = 'insufficient_privilege';
  end if;
end $$;

-- 5.5 Notifications Telegram
--   * nouvelle commande  -> message au commerçant
--   * changement d'étape -> message au client (s'il a donné son Telegram)
--   Une panne Telegram ne bloque JAMAIS une commande : l'erreur va
--   dans public.journal_erreurs.
create or replace function private.notifier_telegram()
returns trigger language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_token  text;
  v_chat   text;
  v_site   text;
  v_url    text;
  v_txt    text;
  v_panier text := '';
  v_ligne  jsonb;
  v_opts   text;
  v_quand  text;
  v_etape  text;
begin
  select valeur into v_token from private.parametres where cle = 'telegram_token';
  select valeur into v_chat  from private.parametres where cle = 'telegram_chat_id';
  select valeur into v_site  from private.parametres where cle = 'url_suivi';

  -- Bot non configuré : on ne fait rien.
  if coalesce(v_token, '') = '' or v_token like 'A_REMPLIR%' then
    return new;
  end if;

  v_url   := 'https://api.telegram.org/bot' || v_token || '/sendMessage';
  v_quand := to_char(now() at time zone 'Europe/Paris', 'DD/MM/YYYY HH24:MI');

  -- Résumé du panier
  for v_ligne in select * from jsonb_array_elements(new.articles) loop
    select string_agg(key || ' : ' || value, ', ')
      into v_opts
      from jsonb_each_text(coalesce(v_ligne->'options', '{}'::jsonb));
    v_panier := v_panier || '• ' || coalesce(v_ligne->>'qte', '1') || ' x '
             || coalesce(v_ligne->>'nom', '?')
             || ' (' || coalesce(v_ligne->>'variante', '') || ')'
             || case when v_opts is not null then ' — ' || v_opts else '' end
             || chr(10);
  end loop;

  if tg_op = 'INSERT' then
    -- ---- Message au commerçant ----
    if coalesce(v_chat, '') <> '' and v_chat not like 'A_REMPLIR%' then
      v_txt := '☕ NOUVELLE COMMANDE' || chr(10) || chr(10)
            || '🔔 ' || new.ref || chr(10)
            || '👤 ' || new.client_nom || chr(10)
            || '📞 ' || new.client_tel || chr(10)
            || case when new.mode = 'retrait'
                    then '🏪 Retrait sur place'
                    else '📍 ' || new.adresse || ', ' || new.code_postal || ' ' || new.ville end
            || chr(10) || chr(10) || v_panier || chr(10)
            || '💰 ' || new.total::text || ' EUR' || chr(10)
            || '🕐 ' || v_quand;
      perform net.http_post(
        url     := v_url,
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body    := jsonb_build_object('chat_id', v_chat, 'text', v_txt));
    end if;

  elsif tg_op = 'UPDATE' and coalesce(new.telegram_client, '') <> '' then
    -- ---- Message au client ----
    select r.etapes->>(new.etape::int) into v_etape
      from public.reglages r where r.id = 'boutique';

    v_txt := '🔔 ' || new.ref || chr(10) || chr(10)
          || '☕ ' || coalesce(v_etape, 'Étape ' || new.etape::text);
    if coalesce(new.message_suivi, '') <> '' then
      v_txt := v_txt || chr(10) || chr(10) || '💬 ' || new.message_suivi;
    end if;
    v_txt := v_txt || chr(10) || chr(10) || '🕐 ' || v_quand;
    if coalesce(v_site, '') <> '' and v_site not like 'A_REMPLIR%' then
      v_txt := v_txt || chr(10) || chr(10) || '📦 Suivre ma commande : ' || v_site;
    end if;

    perform net.http_post(
      url     := v_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := jsonb_build_object('chat_id', new.telegram_client, 'text', v_txt));
  end if;

  return new;

exception when others then
  insert into public.journal_erreurs (ref, contexte, message)
  values (new.ref, 'telegram', sqlerrm);
  return new;
end $$;


-- =====================================================================
-- 6. TRIGGERS
-- =====================================================================
drop trigger if exists reglages_maj_le   on public.reglages;
drop trigger if exists categories_maj_le on public.categories;
drop trigger if exists produits_maj_le   on public.produits;
drop trigger if exists commandes_maj_le  on public.commandes;
drop trigger if exists produits_verifier on public.produits;
drop trigger if exists commandes_notif_creation on public.commandes;
drop trigger if exists commandes_notif_etape    on public.commandes;

create trigger reglages_maj_le   before update on public.reglages   for each row execute function private.toucher_maj_le();
create trigger categories_maj_le before update on public.categories for each row execute function private.toucher_maj_le();
create trigger produits_maj_le   before update on public.produits   for each row execute function private.toucher_maj_le();
create trigger commandes_maj_le  before update on public.commandes  for each row execute function private.toucher_maj_le();

create trigger produits_verifier before insert or update on public.produits
  for each row execute function private.verifier_produit();

create trigger commandes_notif_creation after insert on public.commandes
  for each row execute function private.notifier_telegram();

create trigger commandes_notif_etape after update of etape on public.commandes
  for each row when (old.etape is distinct from new.etape)
  execute function private.notifier_telegram();


-- =====================================================================
-- 7. FONCTIONS PUBLIQUES (appelées par le site : supabase.rpc(...))
-- =====================================================================

-- 7.1 Lecture des réglages
create or replace function public.reglages_lire()
returns jsonb language plpgsql security definer
set search_path = public as $$
declare v public.reglages;
begin
  select * into v from public.reglages where id = 'boutique';
  if not found then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'reglages', to_jsonb(v));
end $$;

-- 7.2 Création d'une commande
--   p_articles = [{"produit_id":"cafe1","variante_id":"cafe1-250","qte":2,
--                  "options":{"Mouture":"Grains"}}]
--   Les prix, noms et stocks sont relus en base : le client n'envoie
--   JAMAIS de prix.
--   p_mode = 'livraison' ou 'retrait'.
--   Retourne la référence ET le jeton de suivi (à garder côté client).
create or replace function public.creer_commande(
  p_nom text, p_tel text, p_email text,
  p_adresse text, p_code_postal text, p_ville text,
  p_mode text, p_articles jsonb,
  p_telegram text default '', p_note text default ''
) returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_reg    public.reglages;
  v_item   jsonb;
  v_prod   public.produits;
  v_var    jsonb;
  v_opt    jsonb;
  v_choix  text;
  v_opts   jsonb;
  v_qte    integer;
  v_lignes jsonb := '[]'::jsonb;
  v_sous   numeric := 0;
  v_frais  numeric := 0;
  v_total  numeric;
  v_ref    text;
  v_essai  integer := 0;
  v_jeton  text;
  v_id     uuid;
begin
  select * into v_reg from public.reglages where id = 'boutique';

  if coalesce(trim(p_nom), '') = '' or coalesce(trim(p_tel), '') = '' then
    raise exception 'Le nom et le téléphone sont obligatoires.' using errcode = 'check_violation';
  end if;
  if p_mode not in ('livraison', 'retrait') then
    raise exception 'Mode invalide (livraison ou retrait).' using errcode = 'check_violation';
  end if;
  if p_mode = 'livraison' and (coalesce(trim(p_adresse), '') = ''
       or coalesce(trim(p_ville), '') = '') then
    raise exception 'Adresse et ville obligatoires pour une livraison.' using errcode = 'check_violation';
  end if;
  if p_articles is null or jsonb_typeof(p_articles) <> 'array'
     or jsonb_array_length(p_articles) = 0 then
    raise exception 'Le panier est vide.' using errcode = 'check_violation';
  end if;

  for v_item in select * from jsonb_array_elements(p_articles) loop
    v_qte := coalesce((v_item->>'qte')::integer, 1);
    if v_qte < 1 or v_qte > 99 then
      raise exception 'Quantité invalide (1 à 99).' using errcode = 'check_violation';
    end if;

    select * into v_prod from public.produits
     where id = v_item->>'produit_id' and actif and not masque;
    if not found then
      raise exception 'Produit indisponible : %', coalesce(v_item->>'produit_id', '?')
        using errcode = 'check_violation';
    end if;

    select e into v_var
      from jsonb_array_elements(v_prod.variantes) as e
     where e->>'id' = v_item->>'variante_id';
    if v_var is null then
      raise exception 'Variante inconnue pour %.', v_prod.nom using errcode = 'check_violation';
    end if;
    if coalesce(v_var->>'stock', 'disponible') = 'rupture' then
      raise exception '% (%) est en rupture de stock.', v_prod.nom, v_var->>'nom'
        using errcode = 'check_violation';
    end if;

    -- Chaque option du produit doit avoir un choix valide.
    v_opts := '{}'::jsonb;
    for v_opt in select * from jsonb_array_elements(v_prod.options) loop
      v_choix := v_item->'options'->>(v_opt->>'nom');
      if v_choix is null or not exists (
           select 1 from jsonb_array_elements_text(v_opt->'valeurs') x where x = v_choix) then
        raise exception 'Choix manquant ou invalide pour « % » (%).', v_opt->>'nom', v_prod.nom
          using errcode = 'check_violation';
      end if;
      v_opts := v_opts || jsonb_build_object(v_opt->>'nom', v_choix);
    end loop;

    v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
      'produit_id',  v_prod.id,
      'variante_id', v_var->>'id',
      'nom',         v_prod.nom,
      'variante',    v_var->>'nom',
      'options',     v_opts,
      'prix',        (v_var->>'prix')::numeric,
      'qte',         v_qte));
    v_sous := v_sous + (v_var->>'prix')::numeric * v_qte;
  end loop;

  -- Minimum de commande et frais de livraison
  if p_mode = 'livraison' then
    if v_sous < coalesce((v_reg.livraison->>'minimum')::numeric, 0) then
      raise exception 'Minimum de commande : % EUR.', v_reg.livraison->>'minimum'
        using errcode = 'check_violation';
    end if;
    if v_sous >= coalesce((v_reg.livraison->>'gratuite_a_partir_de')::numeric, 1e12) then
      v_frais := 0;
    else
      v_frais := coalesce((v_reg.livraison->>'frais')::numeric, 0);
    end if;
  end if;
  v_total := v_sous + v_frais;

  -- Référence unique : #PREFIXE-1234
  loop
    v_essai := v_essai + 1;
    v_ref := '#' || v_reg.prefixe_ref || '-' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0');
    exit when not exists (select 1 from public.commandes where ref = v_ref);
    if v_essai > 50 then
      raise exception 'Impossible de générer une référence unique.';
    end if;
  end loop;

  insert into public.commandes (
    ref, mode, client_nom, client_tel, client_email,
    adresse, code_postal, ville, articles,
    sous_total, frais, total, telegram_client, note
  ) values (
    v_ref, p_mode, trim(p_nom), trim(p_tel), trim(coalesce(p_email, '')),
    trim(coalesce(p_adresse, '')), trim(coalesce(p_code_postal, '')), trim(coalesce(p_ville, '')),
    v_lignes, v_sous, v_frais, v_total,
    regexp_replace(coalesce(p_telegram, ''), '[^0-9-]', '', 'g'),
    left(coalesce(p_note, ''), 500)
  ) returning id, suivi_jeton into v_id, v_jeton;

  return jsonb_build_object('ok', true, 'ref', v_ref, 'jeton', v_jeton,
                            'sous_total', v_sous, 'frais', v_frais, 'total', v_total);
end $$;

-- 7.3 Suivi d'une commande (référence + jeton reçus à la commande)
create or replace function public.suivre_commande(p_ref text, p_jeton text)
returns jsonb language plpgsql security definer
set search_path = public as $$
declare v public.commandes;
begin
  if coalesce(trim(p_jeton), '') = '' then
    return jsonb_build_object('ok', false);
  end if;

  select * into v from public.commandes
   where upper(replace(ref, '#', '')) = upper(replace(trim(coalesce(p_ref, '')), '#', ''))
     and suivi_jeton = p_jeton;
  if not found then return jsonb_build_object('ok', false); end if;

  return jsonb_build_object(
    'ok', true, 'ref', v.ref, 'etape', v.etape, 'statut', v.statut,
    'mode', v.mode, 'articles', v.articles,
    'sous_total', v.sous_total, 'frais', v.frais, 'total', v.total,
    'message', v.message_suivi, 'cree_le', v.cree_le, 'maj_le', v.maj_le);
end $$;

-- 7.4 Dépôt d'un avis (publié seulement après modération)
create or replace function public.laisser_avis(p_note smallint, p_auteur text, p_texte text)
returns jsonb language plpgsql security definer
set search_path = public as $$
declare v_id uuid;
begin
  if p_note is null or p_note < 1 or p_note > 5 then
    raise exception 'La note doit être comprise entre 1 et 5.' using errcode = 'check_violation';
  end if;
  insert into public.avis (note, auteur, texte, publie)
  values (p_note,
          left(coalesce(nullif(trim(p_auteur), ''), 'Anonyme'), 60),
          left(coalesce(trim(p_texte), ''), 1000),
          false)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'publie', false);
end $$;


-- =====================================================================
-- 8. FONCTIONS ADMIN (gestion_*) — chacune exige le mot de passe
-- =====================================================================

-- 8.1 Connexion (ne lève pas d'erreur : renvoie ok true/false)
create or replace function public.gestion_verifier(p_mot_de_passe text)
returns jsonb language sql security definer set search_path = public, extensions as $$
  select jsonb_build_object('ok', private.verifier_mot_de_passe(p_mot_de_passe));
$$;

-- 8.2 Changer le mot de passe
create or replace function public.gestion_changer_mot_de_passe(p_ancien text, p_nouveau text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_ancien);
  if coalesce(length(trim(p_nouveau)), 0) < 8 then
    raise exception 'Le nouveau mot de passe doit faire au moins 8 caractères.'
      using errcode = 'check_violation';
  end if;
  update private.admin
     set empreinte = extensions.crypt(trim(p_nouveau), extensions.gen_salt('bf')),
         maj_le = now()
   where id = 'admin';
  return jsonb_build_object('ok', true);
end $$;

-- 8.3 Commandes : liste, étape, statut, messages
create or replace function public.gestion_commandes(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  return jsonb_build_object('ok', true, 'commandes', (
    select coalesce(jsonb_agg(c order by c.cree_le desc), '[]'::jsonb)
    from (
      select id, ref, etape, statut, paiement, mode, client_nom, client_tel,
             client_email, adresse, code_postal, ville, articles, sous_total,
             frais, total, telegram_client, note, message_suivi, cree_le, maj_le
        from public.commandes
       order by cree_le desc
       limit 300
    ) c));
end $$;

create or replace function public.gestion_etape(p_mot_de_passe text, p_ref text, p_etape integer)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v smallint;
begin
  perform private.exiger_admin(p_mot_de_passe);
  v := greatest(0, least(4, coalesce(p_etape, 0)))::smallint;
  update public.commandes set etape = v where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'etape', v);
end $$;

create or replace function public.gestion_statut(p_mot_de_passe text, p_ref text, p_statut text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  if p_statut not in ('en_cours', 'annulee', 'remboursee', 'archivee') then
    raise exception 'Statut inconnu : %', p_statut using errcode = 'check_violation';
  end if;
  update public.commandes set statut = p_statut where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'statut', p_statut);
end $$;

create or replace function public.gestion_paiement(p_mot_de_passe text, p_ref text, p_paiement text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  if p_paiement not in ('a_regler', 'regle') then
    raise exception 'Paiement inconnu : %', p_paiement using errcode = 'check_violation';
  end if;
  update public.commandes set paiement = p_paiement where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'paiement', p_paiement);
end $$;

-- Champs texte modifiables : note interne, message vu par le client
create or replace function public.gestion_champ(p_mot_de_passe text, p_ref text, p_champ text, p_valeur text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  if p_champ not in ('note', 'message_suivi') then
    raise exception 'Champ non modifiable : %', p_champ using errcode = 'check_violation';
  end if;
  execute format('update public.commandes set %I = $1 where ref = $2', p_champ)
    using left(coalesce(p_valeur, ''), 500), p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'champ', p_champ);
end $$;

create or replace function public.gestion_supprimer_commande(p_mot_de_passe text, p_ref text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  delete from public.commandes where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref);
end $$;

-- 8.4 Produits (variantes incluses)
create or replace function public.gestion_produits(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  return jsonb_build_object('ok', true, 'produits', (
    select coalesce(jsonb_agg(to_jsonb(p) order by p.position, p.nom), '[]'::jsonb)
    from (select * from public.produits order by position, nom limit 500) p));
end $$;

-- Création / modification d'un produit.
-- p_variantes est obligatoire (au moins une) : c'est elle qui porte le prix.
create or replace function public.gestion_produit(
  p_mot_de_passe text, p_id text, p_nom text,
  p_variantes jsonb,
  p_rayon text default 'Divers', p_emoji text default '',
  p_description text default '', p_badge text default '',
  p_unite text default '', p_options jsonb default '[]'::jsonb,
  p_photos jsonb default '[]'::jsonb, p_position integer default 0,
  p_masque boolean default false
) returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  if coalesce(p_id, '') !~ '^[a-z0-9-]+$' then
    raise exception 'Identifiant invalide : minuscules, chiffres et tirets uniquement.'
      using errcode = 'check_violation';
  end if;
  if coalesce(trim(p_nom), '') = '' then
    raise exception 'Le nom du produit est obligatoire.' using errcode = 'check_violation';
  end if;

  insert into public.produits (id, nom, rayon, emoji, description, badge, unite,
                               variantes, options, photos, position, masque, actif)
  values (p_id, trim(p_nom), coalesce(nullif(trim(p_rayon), ''), 'Divers'),
          coalesce(p_emoji, ''), coalesce(p_description, ''), coalesce(p_badge, ''),
          coalesce(p_unite, ''), coalesce(p_variantes, '[]'::jsonb),
          coalesce(p_options, '[]'::jsonb), coalesce(p_photos, '[]'::jsonb),
          coalesce(p_position, 0), coalesce(p_masque, false), true)
  on conflict (id) do update set
    nom = excluded.nom, rayon = excluded.rayon, emoji = excluded.emoji,
    description = excluded.description, badge = excluded.badge, unite = excluded.unite,
    variantes = excluded.variantes, options = excluded.options, photos = excluded.photos,
    position = excluded.position, masque = excluded.masque;

  return jsonb_build_object('ok', true, 'id', p_id);
end $$;

create or replace function public.gestion_produit_lire(p_mot_de_passe text, p_id text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v public.produits;
begin
  perform private.exiger_admin(p_mot_de_passe);
  select * into v from public.produits where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'erreur', 'Produit introuvable.'); end if;
  return jsonb_build_object('ok', true, 'produit', to_jsonb(v));
end $$;

-- Photos (liste d'URLs dans l'ordre d'affichage)
create or replace function public.gestion_produit_photos(p_mot_de_passe text, p_id text, p_photos jsonb)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  update public.produits set photos = coalesce(p_photos, '[]'::jsonb) where id = p_id;
  if not found then
    raise exception 'Produit % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_id);
end $$;

-- Masquer / réafficher (retire de la vente sans supprimer)
create or replace function public.gestion_produit_masquer(p_mot_de_passe text, p_id text, p_masque boolean)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  update public.produits set masque = coalesce(p_masque, true) where id = p_id;
  if not found then
    raise exception 'Produit % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_id, 'masque', coalesce(p_masque, true));
end $$;

-- Suppression (refusée si le produit figure dans une commande)
create or replace function public.gestion_supprimer_produit(p_mot_de_passe text, p_id text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  if exists (select 1 from public.commandes
              where articles @> jsonb_build_array(jsonb_build_object('produit_id', p_id))) then
    raise exception 'Ce produit figure dans des commandes : masquez-le plutôt que de le supprimer.'
      using errcode = 'check_violation';
  end if;
  delete from public.produits where id = p_id;
  if not found then
    raise exception 'Produit % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_id);
end $$;

-- 8.5 Rayons (catégories)
create or replace function public.gestion_categories(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  return jsonb_build_object('ok', true, 'categories', (
    select coalesce(jsonb_agg(c order by c.position, c.nom), '[]'::jsonb)
    from (
      select k.id, k.nom, k.emoji, k.position,
             (select count(*) from public.produits p
               where p.rayon = k.nom and not p.masque) as nb
        from public.categories k
    ) c));
end $$;

-- Création / modification ; renommer un rayon renomme aussi ses produits
create or replace function public.gestion_categorie(
  p_mot_de_passe text, p_id text, p_nom text,
  p_emoji text default '', p_position integer default 0
) returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_ancien text;
begin
  perform private.exiger_admin(p_mot_de_passe);
  if coalesce(trim(p_nom), '') = '' or coalesce(trim(p_id), '') = '' then
    raise exception 'Identifiant et nom du rayon obligatoires.' using errcode = 'check_violation';
  end if;
  select nom into v_ancien from public.categories where id = trim(p_id);

  insert into public.categories (id, nom, emoji, position)
  values (trim(p_id), trim(p_nom), coalesce(p_emoji, ''), coalesce(p_position, 0))
  on conflict (id) do update set
    nom = excluded.nom, emoji = excluded.emoji, position = excluded.position;

  if v_ancien is not null and v_ancien <> trim(p_nom) then
    update public.produits set rayon = trim(p_nom) where rayon = v_ancien;
  end if;
  return jsonb_build_object('ok', true, 'id', trim(p_id), 'nom', trim(p_nom));
end $$;

-- Suppression : les produits du rayon passent dans « Divers »
create or replace function public.gestion_categorie_supprimer(p_mot_de_passe text, p_id text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_nom text; v_bouges integer;
begin
  perform private.exiger_admin(p_mot_de_passe);
  select nom into v_nom from public.categories where id = p_id;
  if not found then
    raise exception 'Rayon % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  update public.produits set rayon = 'Divers' where rayon = v_nom;
  get diagnostics v_bouges = row_count;
  delete from public.categories where id = p_id;
  return jsonb_build_object('ok', true, 'id', p_id, 'produits_deplaces', v_bouges);
end $$;

-- 8.6 Avis : modération
create or replace function public.gestion_avis(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  return jsonb_build_object('ok', true, 'avis', (
    select coalesce(jsonb_agg(a order by a.cree_le desc), '[]'::jsonb)
    from (select * from public.avis order by cree_le desc limit 200) a));
end $$;

create or replace function public.gestion_avis_moderer(p_mot_de_passe text, p_id uuid, p_publie boolean)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  update public.avis set publie = coalesce(p_publie, false) where id = p_id;
  if not found then
    raise exception 'Avis introuvable.' using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_id, 'publie', coalesce(p_publie, false));
end $$;

create or replace function public.gestion_avis_supprimer(p_mot_de_passe text, p_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  delete from public.avis where id = p_id;
  if not found then
    raise exception 'Avis introuvable.' using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_id);
end $$;

-- 8.7 Réglages (UNE seule fonction : pas de doublons de signature)
create or replace function public.gestion_reglages(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v public.reglages;
begin
  perform private.exiger_admin(p_mot_de_passe);
  select * into v from public.reglages where id = 'boutique';
  return jsonb_build_object('ok', true, 'reglages', to_jsonb(v));
end $$;

-- Seuls les paramètres fournis (non NULL) sont modifiés.
create or replace function public.gestion_reglages_ecrire(
  p_mot_de_passe text,
  p_nom text default null, p_slogan text default null, p_accroche text default null,
  p_theme text default null, p_logo text default null, p_fond text default null,
  p_fond_flou integer default null, p_contact text default null,
  p_prefixe_ref text default null,
  p_livraison jsonb default null, p_etapes jsonb default null,
  p_infos jsonb default null, p_sections jsonb default null, p_reseaux jsonb default null
) returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  update public.reglages set
    nom         = coalesce(p_nom, nom),
    slogan      = coalesce(p_slogan, slogan),
    accroche    = coalesce(p_accroche, accroche),
    theme       = coalesce(p_theme, theme),
    logo        = coalesce(p_logo, logo),
    fond        = coalesce(p_fond, fond),
    fond_flou   = coalesce(p_fond_flou, fond_flou),
    contact     = coalesce(p_contact, contact),
    prefixe_ref = coalesce(nullif(upper(trim(p_prefixe_ref)), ''), prefixe_ref),
    livraison   = coalesce(p_livraison, livraison),
    etapes      = coalesce(p_etapes, etapes),
    infos       = coalesce(p_infos, infos),
    sections    = coalesce(p_sections, sections),
    reseaux     = coalesce(p_reseaux, reseaux)
  where id = 'boutique';
  return jsonb_build_object('ok', true);
end $$;

-- 8.8 Paramètres secrets (bot Telegram) modifiables depuis l'admin
create or replace function public.gestion_parametre_ecrire(p_mot_de_passe text, p_cle text, p_valeur text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  if p_cle not in ('telegram_token', 'telegram_chat_id', 'url_suivi') then
    raise exception 'Paramètre inconnu : %', p_cle using errcode = 'check_violation';
  end if;
  insert into private.parametres (cle, valeur) values (p_cle, coalesce(p_valeur, ''))
  on conflict (cle) do update set valeur = excluded.valeur;
  return jsonb_build_object('ok', true, 'cle', p_cle);
end $$;

-- 8.9 Récapitulatif mensuel (le chiffre exclut annulées et remboursées)
create or replace function public.gestion_recap(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  return jsonb_build_object('ok', true, 'mois', (
    select coalesce(jsonb_agg(m order by m.mois desc), '[]'::jsonb)
    from (
      select to_char(date_trunc('month', cree_le), 'YYYY-MM') as mois,
             count(*) as total_commandes,
             round(sum(case when statut in ('annulee', 'remboursee') then 0 else total end), 2) as chiffre,
             count(*) filter (where statut = 'annulee')    as annulees,
             count(*) filter (where statut = 'remboursee') as remboursees,
             count(*) filter (where statut not in ('annulee', 'remboursee')) as valides
        from public.commandes
       group by date_trunc('month', cree_le)
       order by date_trunc('month', cree_le) desc
       limit 60
    ) m));
end $$;

-- 8.10 Journal d'erreurs (notifications ratées)
create or replace function public.gestion_journal(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  return jsonb_build_object('ok', true, 'erreurs', (
    select coalesce(jsonb_agg(e order by e.cree_le desc), '[]'::jsonb)
    from (select ref, contexte, message, cree_le
            from public.journal_erreurs order by cree_le desc limit 100) e));
end $$;


-- 8.11 PAGE DE GESTION : tout ce que le commerçant règle lui-même
--   Correspondance « section de la page de gestion » -> fonctions :
--     Tableau de bord ........ gestion_tableau_de_bord
--     Catalogue (tout) ....... gestion_catalogue, gestion_produit, gestion_produit_lire,
--                              gestion_produit_dupliquer, gestion_produit_masquer,
--                              gestion_supprimer_produit, gestion_produits_ordre,
--                              gestion_produit_photos
--     Prix et stock .......... gestion_variante (une variante), gestion_prix_masse (tout / un rayon)
--     Rayons ................. gestion_categories, gestion_categorie,
--                              gestion_categorie_supprimer, gestion_categories_ordre
--     Commandes .............. gestion_commandes, gestion_etape, gestion_statut,
--                              gestion_paiement, gestion_champ, gestion_supprimer_commande
--     Avis ................... gestion_avis, gestion_avis_moderer, gestion_avis_supprimer
--     Réglages du site ....... gestion_reglages, gestion_reglages_ecrire
--                              (nom, slogan, thème, logo, fond, livraison, étapes de suivi,
--                               infos, sections affichées, réseaux)
--     Notifications Telegram . gestion_parametre_ecrire, gestion_journal
--     Chiffres ............... gestion_recap
--     Sécurité ............... gestion_changer_mot_de_passe

-- Tableau de bord : les chiffres clés en un seul appel
create or replace function public.gestion_tableau_de_bord(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  return jsonb_build_object(
    'ok', true,
    'produits_visibles', (select count(*) from public.produits where actif and not masque),
    'produits_masques',  (select count(*) from public.produits where masque),
    'variantes_en_rupture', (select count(*)
        from public.produits p, jsonb_array_elements(p.variantes) e
       where e->>'stock' = 'rupture'),
    'commandes_en_cours', (select count(*) from public.commandes where statut = 'en_cours'),
    'commandes_par_etape', (select coalesce(jsonb_object_agg(etape::text, n), '{}'::jsonb)
        from (select etape, count(*)::int as n from public.commandes
               where statut = 'en_cours' group by etape) t),
    'chiffre_du_mois', (select coalesce(sum(total), 0) from public.commandes
        where statut not in ('annulee', 'remboursee')
          and cree_le >= date_trunc('month', now())),
    'avis_a_moderer', (select count(*) from public.avis where not publie),
    'erreurs_7_jours', (select count(*) from public.journal_erreurs
        where cree_le > now() - interval '7 days'));
end $$;

-- Catalogue complet (rayons + produits, variantes incluses) en un seul appel
create or replace function public.gestion_catalogue(p_mot_de_passe text)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  return jsonb_build_object(
    'ok', true,
    'categories', (select coalesce(jsonb_agg(c order by c.position, c.nom), '[]'::jsonb)
                     from public.categories c),
    'produits',   (select coalesce(jsonb_agg(p order by p.position, p.nom), '[]'::jsonb)
                     from public.produits p));
end $$;

-- Changer le PRIX et/ou le STOCK d'une seule variante (les champs non
-- fournis restent inchangés).
--   exemple : gestion_variante('mdp', 'cafe-exemple-1', 'cafe-exemple-1-250', 8.40, null)
create or replace function public.gestion_variante(
  p_mot_de_passe text, p_produit_id text, p_variante_id text,
  p_prix numeric default null, p_stock text default null
) returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  if p_prix is not null and p_prix < 0 then
    raise exception 'Le prix ne peut pas être négatif.' using errcode = 'check_violation';
  end if;
  if p_stock is not null and p_stock not in ('disponible', 'rupture') then
    raise exception 'Stock invalide (disponible ou rupture).' using errcode = 'check_violation';
  end if;

  update public.produits p
     set variantes = (
       select jsonb_agg(
                case when e->>'id' = p_variante_id
                     then e || jsonb_strip_nulls(jsonb_build_object('prix', p_prix, 'stock', p_stock))
                     else e end
                order by ord)
         from jsonb_array_elements(p.variantes) with ordinality as t(e, ord))
   where p.id = p_produit_id
     and exists (select 1 from jsonb_array_elements(p.variantes) x
                  where x->>'id' = p_variante_id);
  if not found then
    raise exception 'Variante % introuvable pour le produit %.', p_variante_id, p_produit_id
      using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'produit_id', p_produit_id, 'variante_id', p_variante_id);
end $$;

-- Hausse / baisse de TOUS les prix en pourcentage (ou d'un seul rayon).
--   exemple : +5 % sur tout  -> gestion_prix_masse('mdp', 5)
--             -10 % sur Grains -> gestion_prix_masse('mdp', -10, 'Grains')
create or replace function public.gestion_prix_masse(
  p_mot_de_passe text, p_pourcentage numeric, p_rayon text default null
) returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_n integer;
begin
  perform private.exiger_admin(p_mot_de_passe);
  if p_pourcentage is null or p_pourcentage < -90 or p_pourcentage > 500 then
    raise exception 'Pourcentage invalide (entre -90 et 500).' using errcode = 'check_violation';
  end if;

  update public.produits p
     set variantes = (
       select jsonb_agg(
                e || jsonb_build_object('prix',
                       round((e->>'prix')::numeric * (1 + p_pourcentage / 100), 2))
                order by ord)
         from jsonb_array_elements(p.variantes) with ordinality as t(e, ord))
   where (p_rayon is null or p.rayon = p_rayon);
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', true, 'produits_modifies', v_n);
end $$;

-- Ordre d'affichage : on envoie la liste des identifiants dans le bon ordre
--   exemple : gestion_produits_ordre('mdp', '["cafe-b","cafe-a","cafe-c"]')
create or replace function public.gestion_produits_ordre(p_mot_de_passe text, p_ordre jsonb)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_n integer;
begin
  perform private.exiger_admin(p_mot_de_passe);
  if p_ordre is null or jsonb_typeof(p_ordre) <> 'array' then
    raise exception 'p_ordre doit être une liste d''identifiants.' using errcode = 'check_violation';
  end if;
  update public.produits p set position = o.ord
    from jsonb_array_elements_text(p_ordre) with ordinality as o(id, ord)
   where p.id = o.id;
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', true, 'produits_ordonnes', v_n);
end $$;

create or replace function public.gestion_categories_ordre(p_mot_de_passe text, p_ordre jsonb)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare v_n integer;
begin
  perform private.exiger_admin(p_mot_de_passe);
  if p_ordre is null or jsonb_typeof(p_ordre) <> 'array' then
    raise exception 'p_ordre doit être une liste d''identifiants.' using errcode = 'check_violation';
  end if;
  update public.categories c set position = o.ord
    from jsonb_array_elements_text(p_ordre) with ordinality as o(id, ord)
   where c.id = o.id;
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', true, 'rayons_ordonnes', v_n);
end $$;

-- Dupliquer un produit (la copie arrive MASQUÉE : on la termine, puis on l'affiche)
create or replace function public.gestion_produit_dupliquer(
  p_mot_de_passe text, p_id text, p_nouvel_id text
) returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
begin
  perform private.exiger_admin(p_mot_de_passe);
  if coalesce(p_nouvel_id, '') !~ '^[a-z0-9-]+$' then
    raise exception 'Identifiant invalide : minuscules, chiffres et tirets uniquement.'
      using errcode = 'check_violation';
  end if;
  if exists (select 1 from public.produits where id = p_nouvel_id) then
    raise exception 'Le produit % existe déjà.', p_nouvel_id using errcode = 'check_violation';
  end if;
  insert into public.produits (id, nom, rayon, emoji, description, badge, unite,
                               variantes, options, photos, position, masque, actif)
  select p_nouvel_id, nom || ' (copie)', rayon, emoji, description, badge, unite,
         variantes, options, photos, position + 1, true, true
    from public.produits where id = p_id;
  if not found then
    raise exception 'Produit % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_nouvel_id);
end $$;


-- =====================================================================
-- 9. DROITS D'ACCÈS (on ferme tout, puis on ouvre le strict nécessaire)
-- =====================================================================
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

-- Lecture seule des tables publiques (les politiques RLS filtrent les lignes)
grant usage on schema public to anon, authenticated;
grant select on public.reglages, public.categories, public.produits, public.avis
  to anon, authenticated;

-- Fonctions appelables par le site
grant execute on function
  public.reglages_lire(),
  public.creer_commande(text, text, text, text, text, text, text, jsonb, text, text),
  public.suivre_commande(text, text),
  public.laisser_avis(smallint, text, text),
  public.gestion_verifier(text),
  public.gestion_changer_mot_de_passe(text, text),
  public.gestion_commandes(text),
  public.gestion_etape(text, text, integer),
  public.gestion_statut(text, text, text),
  public.gestion_paiement(text, text, text),
  public.gestion_champ(text, text, text, text),
  public.gestion_supprimer_commande(text, text),
  public.gestion_produits(text),
  public.gestion_produit(text, text, text, jsonb, text, text, text, text, text, jsonb, jsonb, integer, boolean),
  public.gestion_produit_lire(text, text),
  public.gestion_produit_photos(text, text, jsonb),
  public.gestion_produit_masquer(text, text, boolean),
  public.gestion_supprimer_produit(text, text),
  public.gestion_categories(text),
  public.gestion_categorie(text, text, text, text, integer),
  public.gestion_categorie_supprimer(text, text),
  public.gestion_avis(text),
  public.gestion_avis_moderer(text, uuid, boolean),
  public.gestion_avis_supprimer(text, uuid),
  public.gestion_reglages(text),
  public.gestion_reglages_ecrire(text, text, text, text, text, text, text, integer, text, text, jsonb, jsonb, jsonb, jsonb, jsonb),
  public.gestion_parametre_ecrire(text, text, text),
  public.gestion_recap(text),
  public.gestion_journal(text),
  public.gestion_tableau_de_bord(text),
  public.gestion_catalogue(text),
  public.gestion_variante(text, text, text, numeric, text),
  public.gestion_prix_masse(text, numeric, text),
  public.gestion_produits_ordre(text, jsonb),
  public.gestion_categories_ordre(text, jsonb),
  public.gestion_produit_dupliquer(text, text, text)
  to anon, authenticated;

-- Les futures fonctions créées dans public ne seront plus ouvertes par défaut
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;


-- =====================================================================
-- 10. STOCKAGE DES IMAGES (photos produits, logo, fond)
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('produits', 'produits', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('boutique', 'boutique', true, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists images_lecture on storage.objects;
drop policy if exists images_depot   on storage.objects;
create policy images_lecture on storage.objects for select to anon, authenticated
  using (bucket_id in ('produits', 'boutique'));
-- ATTENTION : l'envoi d'images est ouvert au site (le mot de passe admin
-- n'est pas vérifiable par le stockage). Limites de taille et de type
-- déjà posées ci-dessus. Pas de modification ni de suppression publique.
create policy images_depot on storage.objects for insert to anon, authenticated
  with check (bucket_id in ('produits', 'boutique'));


-- =====================================================================
-- 11. DONNÉES DE DÉPART (exemples à remplacer)
-- =====================================================================

-- 11.1 Réglages de la boutique
insert into public.reglages (id) values ('boutique') on conflict (id) do nothing;
update public.reglages set
  nom         = 'A_REMPLIR_NOM_BOUTIQUE',
  slogan      = 'A_REMPLIR_SLOGAN',
  accroche    = 'A_REMPLIR_PHRASE_ACCROCHE',
  contact     = 'A_REMPLIR_EMAIL_OU_TELEPHONE',
  prefixe_ref = 'A_REMPLIR_PREFIXE_3_LETTRES',   -- ex. CAF, ex. KAWA
  livraison   = '{"frais": 5, "minimum": 20, "gratuite_a_partir_de": 60}'::jsonb,
  infos       = '{"zone": "A_REMPLIR_ZONE_DE_LIVRAISON",
                  "horaires": "A_REMPLIR_HORAIRES",
                  "paiement": "A_REMPLIR_MODES_DE_PAIEMENT"}'::jsonb,
  reseaux     = '[{"cle":"instagram","nom":"Instagram","url":"A_REMPLIR_URL_INSTAGRAM","logo":"","actif":true}]'::jsonb
where id = 'boutique';

-- 11.2 Mot de passe admin (haché automatiquement, jamais stocké en clair)
insert into private.admin (id, empreinte)
values ('admin', extensions.crypt('A_REMPLIR_MOT_DE_PASSE_ADMIN', extensions.gen_salt('bf')))
on conflict (id) do nothing;   -- pour le changer ensuite : gestion_changer_mot_de_passe

-- 11.3 Bot Telegram (laisser A_REMPLIR... = notifications désactivées)
insert into private.parametres (cle, valeur) values
  ('telegram_token',   'A_REMPLIR_TOKEN_DU_BOT'),     -- fourni par @BotFather
  ('telegram_chat_id', 'A_REMPLIR_CHAT_ID_COMMERCANT'), -- ton identifiant de chat
  ('url_suivi',        'A_REMPLIR_URL_DU_SITE')       -- ex. https://monsite.netlify.app
on conflict (cle) do nothing;

-- 11.4 Rayons d'exemple
insert into public.categories (id, nom, emoji, position) values
  ('grains',     'Grains',      '☕', 1),
  ('moulu',      'Moulu',       '🫘', 2),
  ('accessoires','Accessoires', '🫖', 3)
on conflict (id) do nothing;

-- 11.5 Produits d'exemple (avec variantes et option de mouture)
insert into public.produits (id, nom, rayon, emoji, description, badge, unite, variantes, options, position) values
  ('cafe-exemple-1', 'A_REMPLIR_NOM_CAFE_1', 'Grains', '☕',
   'A_REMPLIR_DESCRIPTION (origine, notes, torréfaction)', 'Nouveau', 'sachet',
   '[{"id":"cafe-exemple-1-250","nom":"250 g","prix":7.90,"stock":"disponible"},
     {"id":"cafe-exemple-1-500","nom":"500 g","prix":14.50,"stock":"disponible"},
     {"id":"cafe-exemple-1-1kg","nom":"1 kg","prix":27.00,"stock":"disponible"}]'::jsonb,
   '[{"nom":"Mouture","valeurs":["Grains","Espresso","Filtre","Cafetière italienne"]}]'::jsonb,
   1),
  ('cafe-exemple-2', 'A_REMPLIR_NOM_CAFE_2', 'Moulu', '🫘',
   'A_REMPLIR_DESCRIPTION', '', 'sachet',
   '[{"id":"cafe-exemple-2-250","nom":"250 g","prix":6.90,"stock":"disponible"},
     {"id":"cafe-exemple-2-1kg","nom":"1 kg","prix":24.00,"stock":"rupture"}]'::jsonb,
   '[]'::jsonb,
   2)
on conflict (id) do nothing;


-- =====================================================================
-- 12. CHECK-LIST DES VALEURS A_REMPLIR
-- =====================================================================
--  A_REMPLIR_NOM_BOUTIQUE          nom affiché sur le site
--  A_REMPLIR_SLOGAN                slogan court
--  A_REMPLIR_PHRASE_ACCROCHE       phrase d'accueil
--  A_REMPLIR_EMAIL_OU_TELEPHONE    contact public
--  A_REMPLIR_PREFIXE_3_LETTRES     préfixe des numéros de commande
--  A_REMPLIR_ZONE_DE_LIVRAISON     zone desservie
--  A_REMPLIR_HORAIRES              horaires
--  A_REMPLIR_MODES_DE_PAIEMENT     modes de paiement acceptés
--  A_REMPLIR_URL_INSTAGRAM         lien réseau social (ou supprimer la ligne)
--  A_REMPLIR_MOT_DE_PASSE_ADMIN    mot de passe admin (8+ caractères, long)
--  A_REMPLIR_TOKEN_DU_BOT          jeton @BotFather (ou laisser tel quel)
--  A_REMPLIR_CHAT_ID_COMMERCANT    chat Telegram qui reçoit les commandes
--  A_REMPLIR_URL_DU_SITE           adresse publique du site (lien de suivi)
--  A_REMPLIR_NOM_CAFE_1 / _2, A_REMPLIR_DESCRIPTION...  produits d'exemple
--  (prix des variantes d'exemple : à adapter)
--
--  CÔTÉ SITE (JavaScript, client Supabase) :
--    supabase.rpc('reglages_lire')
--    supabase.from('produits').select('*').order('position')
--    supabase.from('categories').select('*').order('position')
--    supabase.rpc('creer_commande', { p_nom, p_tel, p_email, p_adresse,
--       p_code_postal, p_ville, p_mode: 'livraison', p_telegram: '',
--       p_articles: [{ produit_id, variante_id, qte, options: {Mouture:'Grains'} }] })
--    supabase.rpc('suivre_commande', { p_ref, p_jeton })
--    supabase.rpc('laisser_avis', { p_note, p_auteur, p_texte })
--    supabase.rpc('gestion_verifier', { p_mot_de_passe })   -- connexion admin


-- =====================================================================
-- 13. VÉRIFICATIONS (à lancer après l'installation)
-- =====================================================================
--  select count(*) from public.produits;                    -- 2
--  select public.reglages_lire();                           -- ok: true
--  select public.gestion_verifier('ton_mot_de_passe');      -- ok: true
--  select public.gestion_commandes('ton_mot_de_passe');
--  select public.creer_commande('Test','0600000000','','1 rue Test','75001','Paris',
--     'livraison',
--     '[{"produit_id":"cafe-exemple-1","variante_id":"cafe-exemple-1-1kg","qte":1,"options":{"Mouture":"Grains"}}]');
--  Puis : Dashboard > Advisors > Security  (aucune alerte attendue).
