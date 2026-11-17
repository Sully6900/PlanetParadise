-- ============================================================
--  CORNER69 — INSTALLATION COMPLETE D'UNE BOUTIQUE
--  Un seul fichier, a coller une fois dans l'editeur SQL
--  d'un nouveau projet Supabase, puis Run.
--
--  Ordre d'installation (il compte) :
--    1. les tables
--    2. les fonctions utilitaires
--    3. le declencheur de variante
--    4. les fonctions de gestion et les fonctions publiques
--    5. le compte administrateur
--    6. les regles de securite
--
--  Le fichier est rejouable : on peut le relancer sans casser
--  une base deja installee.
-- ============================================================


-- ============================================================
--  1. LES TABLES
-- ============================================================

-- --- Le catalogue ---------------------------------------------
create table if not exists public.produits (
  id          text primary key,
  nom         text,
  rayon       text default 'Divers',
  emoji       text not null default '',
  format      text not null default '',
  prix        numeric not null default 0,
  stock       text not null default 'disponible',
  badge       text not null default '',
  description text not null default '',
  medias      jsonb not null default '[]'::jsonb,
  position    integer not null default 0,
  actif       boolean not null default true,
  masque      boolean not null default false,
  variantes   jsonb not null default '[]'::jsonb,
  unite       text not null default '',
  photos      jsonb not null default '[]'::jsonb,
  options     jsonb default '[]'::jsonb,
  cree_le     timestamp with time zone not null default now(),
  maj_le      timestamp with time zone not null default now()
);

-- --- Les rayons -----------------------------------------------
create table if not exists public.categories (
  id       text primary key,
  nom      text not null,
  emoji    text not null default '',
  position integer not null default 0,
  cree_le  timestamp with time zone not null default now(),
  maj_le   timestamp with time zone not null default now()
);

-- --- Les commandes --------------------------------------------
create table if not exists public.commandes (
  id              uuid primary key default gen_random_uuid(),
  ref             text not null,
  suivi_id        text default '',
  suivi_jeton     text not null default '',
  etape           smallint not null default 0,
  statut          text default 'en_cours',
  client_nom      text,
  client_tel      text,
  nom             text,
  telephone       text,
  telegram_client text,
  adresse         text not null,
  code_postal     text,
  ville           text,
  articles        jsonb not null default '[]'::jsonb,
  sous_total      numeric not null default 0,
  frais           numeric not null default 0,
  total           numeric not null default 0,
  telegram        text not null default '',
  paiement        text not null default 'a_regler',
  note            text not null default '',
  complement      boolean not null default false,
  ref_parent      text,
  ajouts          integer default 0,
  vehicule        text default '',
  message_livreur text default '',
  dernier_ajout   timestamp with time zone,
  supprime_le     timestamp with time zone,
  cree_le         timestamp with time zone not null default now(),
  maj_le          timestamp with time zone not null default now()
);

create unique index if not exists commandes_ref_idx on public.commandes (ref);

-- --- Les reglages de la boutique ------------------------------
create table if not exists public.reglages (
  id         text primary key default 'boutique',
  nom        text not null default 'Ma boutique',
  slogan     text not null default '',
  baseline   text not null default '',
  accroche   text default '',
  theme      text not null default 'nuit-acide',
  palettes   jsonb not null default '{}'::jsonb,
  zone       jsonb not null default '{}'::jsonb,
  livraison  jsonb not null default '{}'::jsonb,
  etapes     jsonb not null default '[]'::jsonb,
  infos      jsonb not null default '{}'::jsonb,
  sections   jsonb not null default '{}'::jsonb,
  reseaux    jsonb not null default '[]'::jsonb,
  mini_app   text not null default '',
  contact    text not null default '',
  logo       text not null default '',
  fond       text not null default '',
  fond_flou  integer not null default 72,
  maj_le     timestamp with time zone not null default now()
);

-- --- Les avis --------------------------------------------------
create table if not exists public.avis (
  id      uuid primary key default gen_random_uuid(),
  note    smallint not null,
  auteur  text not null default 'Anonyme',
  texte   text not null default '',
  publie  boolean not null default false,
  cree_le timestamp with time zone not null default now()
);

-- --- Les envois rates (journal d'erreurs) ----------------------
create table if not exists public.envois_rates (
  id      uuid primary key default gen_random_uuid(),
  ref     text,
  champ   text,
  message text,
  code    integer,
  cree_le timestamp with time zone not null default now()
);

-- --- Le recap mensuel -----------------------------------------
create table if not exists public.recap_mois (
  id         uuid primary key default gen_random_uuid(),
  debut_mois date not null,
  commandes  integer not null default 0,
  chiffre    numeric not null default 0,
  cree_le    timestamp with time zone not null default now()
);

-- --- Le compte administrateur ---------------------------------
create table if not exists public.admin (
  id        text primary key default 'admin',
  empreinte text not null,
  maj_le    timestamp with time zone not null default now()
);


-- ============================================================
--  2. LES FONCTIONS UTILITAIRES
-- ============================================================

-- Met maj_le a jour tout seul a chaque modification.
create or replace function public.toucher_maj_le()
returns trigger
language plpgsql
as $$
begin
  new.maj_le := now();
  return new;
end;
$$;

-- Pose une variante a tout produit qui n'en a pas, et met le
-- prix du produit a zero : un produit a soit un prix simple,
-- soit des variantes, jamais les deux.
create or replace function public.poser_variante_par_defaut()
returns trigger
language plpgsql
as $$
begin
  if new.variantes is null
     or jsonb_array_length(new.variantes) = 0 then
    new.variantes := jsonb_build_array(
      jsonb_build_object(
        'id',    new.id || '-std',
        'nom',   coalesce(nullif(new.format, ''), 'Standard'),
        'prix',  coalesce(new.prix, 0),
        'stock', case when new.stock = 'rupture' then 'rupture'
                      else 'disponible' end
      )
    );
    new.prix   := 0;
    new.format := '';
  end if;
  return new;
end;
$$;


-- ============================================================
--  3. LES DECLENCHEURS  (apres les fonctions : c'est ce qui
--     manquait quand le declencheur n'a pas pu se creer)
-- ============================================================

drop trigger if exists tr_produits_maj on public.produits;
create trigger tr_produits_maj
before update on public.produits
for each row execute function public.toucher_maj_le();

drop trigger if exists tr_variante_defaut on public.produits;
create trigger tr_variante_defaut
before insert on public.produits
for each row execute function public.poser_variante_par_defaut();

drop trigger if exists tr_commandes_maj on public.commandes;
create trigger tr_commandes_maj
before update on public.commandes
for each row execute function public.toucher_maj_le();

drop trigger if exists tr_categories_maj on public.categories;
create trigger tr_categories_maj
before update on public.categories
for each row execute function public.toucher_maj_le();


-- ============================================================
--  4. LES REGLES DE SECURITE
--     Le catalogue et les reglages sont lisibles par tout le
--     monde ; le reste passe par les fonctions.
-- ============================================================

alter table public.produits     enable row level security;
alter table public.reglages     enable row level security;
alter table public.categories   enable row level security;
alter table public.commandes    enable row level security;
alter table public.avis         enable row level security;
alter table public.envois_rates enable row level security;
alter table public.recap_mois   enable row level security;
alter table public.admin        enable row level security;

-- Le catalogue : lecture publique des produits visibles.
drop policy if exists produits_lecture on public.produits;
create policy produits_lecture on public.produits
for select using (actif = true and masque = false);

-- Les rayons : lecture publique.
drop policy if exists categories_lecture on public.categories;
create policy categories_lecture on public.categories
for select using (true);

-- Les reglages : lecture publique.
drop policy if exists reglages_lecture on public.reglages;
create policy reglages_lecture on public.reglages
for select using (true);

-- Les avis : seuls les avis publies sont visibles.
drop policy if exists avis_lecture on public.avis;
create policy avis_lecture on public.avis
for select using (publie = true);

-- Les commandes, l'admin et le journal ne sont pas lisibles
-- directement : tout passe par les fonctions ci-dessous.

-- (La ligne de reglages et le compte admin de depart)
insert into public.reglages (id) values ('boutique')
  on conflict (id) do nothing;


-- ============================================================
--  5. LE COMPTE ADMINISTRATEUR
--     Remplacez la valeur par le mot de passe de votre choix.
--     L'empreinte se calcule tout seule : voir la note en bas.
-- ============================================================

-- Pour definir le mot de passe 'change-moi' :
insert into public.admin (id, empreinte)
values ('admin', encode(sha256('change-moi'::bytea), 'hex'))
on conflict (id) do update set
  empreinte = excluded.empreinte,
  maj_le    = now();


-- ============================================================
--  6. LES FONCTIONS  (a coller APRES le fichier de base)
-- ============================================================

-- --- 6.1 Les fonctions de verification du mot de passe ---------

CREATE OR REPLACE FUNCTION public.admin_verifier(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  return jsonb_build_object('ok', coalesce(v_ok, false));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_verifier(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  return jsonb_build_object('ok', coalesce(v_ok, false));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_changer_mot_de_passe(p_ancien text, p_nouveau text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_ancien::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe actuel incorrect.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(length(trim(p_nouveau)), 0) < 8 then
    raise exception 'Le nouveau mot de passe doit faire au moins 8 caracteres.' using errcode = 'check_violation';
  end if;
  if trim(p_nouveau) = trim(p_ancien) then
    raise exception 'Le nouveau mot de passe est identique a l''ancien.' using errcode = 'check_violation';
  end if;
  update public.admin
     set empreinte = encode(sha256(trim(p_nouveau)::bytea), 'hex'), maj_le = now()
   where id = 'admin';
  return jsonb_build_object('ok', true);
end;
$function$;

-- --- 6.2 Les produits ----------------------------------------

CREATE OR REPLACE FUNCTION public.gestion_produit(
  p_mot_de_passe text, p_id text, p_nom text,
  p_rayon text DEFAULT 'Divers', p_prix numeric DEFAULT 0,
  p_format text DEFAULT '', p_emoji text DEFAULT '',
  p_description text DEFAULT '', p_stock text DEFAULT 'disponible',
  p_badge text DEFAULT '', p_unite text DEFAULT '',
  p_masque boolean DEFAULT false, p_position integer DEFAULT 0,
  p_variantes jsonb DEFAULT '[]'::jsonb, p_options jsonb DEFAULT '[]'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;

  insert into public.produits (
    id, nom, rayon, prix, format, emoji, description, stock, badge,
    unite, masque, position, variantes, options, actif, maj_le
  ) values (
    p_id, p_nom, p_rayon, p_prix, p_format, p_emoji, p_description,
    p_stock, p_badge, p_unite, p_masque, p_position,
    coalesce(p_variantes, '[]'::jsonb), coalesce(p_options, '[]'::jsonb), true, now()
  )
  on conflict (id) do update set
    nom = excluded.nom, rayon = excluded.rayon, prix = excluded.prix,
    format = excluded.format, emoji = excluded.emoji,
    description = excluded.description, stock = excluded.stock,
    badge = excluded.badge, unite = excluded.unite, masque = excluded.masque,
    position = excluded.position, variantes = excluded.variantes,
    options = excluded.options, maj_le = now();

  return jsonb_build_object('ok', true, 'id', p_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_produits(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object('ok', true, 'produits', (
    select coalesce(jsonb_agg(p order by p.position, p.nom), '[]'::jsonb)
    from (
      select id, nom, rayon, emoji, format, prix, stock, badge,
             description, unite, masque, position, actif, cree_le, maj_le,
             variantes, options, photos
      from public.produits order by position, nom limit 500
    ) p
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_produit_lire(p_mot_de_passe text, p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v public.produits;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  select * into v from public.produits where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'erreur', 'Produit introuvable.');
  end if;
  return jsonb_build_object('ok', true, 'produit', to_jsonb(v));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_produit_masquer(p_mot_de_passe text, p_id text, p_masque boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  update public.produits set masque = coalesce(p_masque, true), maj_le = now() where id = p_id;
  if not found then
    raise exception 'Produit % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_id, 'masque', coalesce(p_masque, true));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_produit_photos(p_mot_de_passe text, p_id text, p_photos jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  update public.produits
     set photos = coalesce(p_photos, '[]'::jsonb),
         medias = coalesce(p_photos, '[]'::jsonb), maj_le = now()
   where id = p_id;
  if not found then
    raise exception 'Produit % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_id, 'photos', coalesce(p_photos, '[]'::jsonb));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_supprimer_produit(p_mot_de_passe text, p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v_vendu integer;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  select count(*) into v_vendu from public.commandes
   where articles::text like '%' || p_id || '%';
  if v_vendu > 0 then
    raise exception 'Ce produit apparait dans % commande(s) : masquez-le plutot que de le supprimer.', v_vendu
      using errcode = 'check_violation';
  end if;
  delete from public.produits where id = p_id;
  if not found then
    raise exception 'Produit % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'id', p_id);
end;
$function$;

-- --- 6.3 Les rayons ------------------------------------------

CREATE OR REPLACE FUNCTION public.gestion_categorie(
  p_mot_de_passe text, p_id text, p_nom text,
  p_emoji text DEFAULT '', p_position integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v_ancien text;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(trim(p_nom), '') = '' then
    raise exception 'Le nom du rayon est obligatoire.' using errcode = 'check_violation';
  end if;
  if coalesce(trim(p_id), '') = '' then
    raise exception 'Identifiant du rayon obligatoire.' using errcode = 'check_violation';
  end if;
  select nom into v_ancien from public.categories where id = p_id;
  insert into public.categories (id, nom, emoji, position)
  values (trim(p_id), trim(p_nom), coalesce(p_emoji, ''), coalesce(p_position, 0))
  on conflict (id) do update set
    nom = excluded.nom, emoji = excluded.emoji,
    position = excluded.position, maj_le = now();
  if v_ancien is not null and v_ancien <> trim(p_nom) then
    update public.produits set rayon = trim(p_nom) where rayon = v_ancien;
  end if;
  return jsonb_build_object('ok', true, 'id', trim(p_id), 'nom', trim(p_nom));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_categories(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object('ok', true, 'categories', (
    select coalesce(jsonb_agg(c order by c.position, c.nom), '[]'::jsonb)
    from (
      select c.id, c.nom, c.emoji, c.position,
             (select count(*) from public.produits p
               where p.rayon = c.nom and coalesce(p.masque, false) = false) as nb
      from public.categories c order by c.position, c.nom
    ) c
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_categorie_supprimer(p_mot_de_passe text, p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v_nom text; v_bouges integer;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  select nom into v_nom from public.categories where id = p_id;
  if not found then
    raise exception 'Rayon % introuvable.', p_id using errcode = 'no_data_found';
  end if;
  update public.produits set rayon = 'Divers' where rayon = v_nom;
  get diagnostics v_bouges = row_count;
  delete from public.categories where id = p_id;
  return jsonb_build_object('ok', true, 'id', p_id, 'produits_deplaces', v_bouges);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_categories_importer(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v_ajouts integer := 0; r record;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  for r in select distinct rayon from public.produits
           where coalesce(trim(rayon), '') <> '' loop
    if not exists (select 1 from public.categories where nom = r.rayon) then
      insert into public.categories (id, nom, position)
      values ('c' || lower(regexp_replace(r.rayon, '[^a-zA-Z0-9]', '', 'g'))
              || substr(md5(random()::text), 1, 4), r.rayon, v_ajouts + 1);
      v_ajouts := v_ajouts + 1;
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'ajoutees', v_ajouts);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_rayons(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object('ok', true, 'rayons', (
    select coalesce(jsonb_agg(distinct rayon order by rayon), '[]'::jsonb)
    from public.produits where coalesce(rayon, '') <> ''
  ));
end;
$function$;

-- --- 6.4 Les commandes (cote boutique) -----------------------

CREATE OR REPLACE FUNCTION public.gestion_commandes(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object('ok', true, 'commandes', (
    select coalesce(jsonb_agg(c order by c.cree_le desc), '[]'::jsonb)
    from (
      select id, ref, etape, statut, nom, telephone, adresse,
             code_postal, ville, articles, total, telegram_client,
             ajouts, dernier_ajout, vehicule, message_livreur,
             complement, cree_le, maj_le
      from public.commandes order by cree_le desc limit 300
    ) c
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_avancer(p_mot_de_passe text, p_ref text, p_sens integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v_etape smallint; v_nouvelle smallint;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  select etape into v_etape from public.commandes where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  if p_sens < 0 then v_nouvelle := greatest(0, v_etape - 1);
  else v_nouvelle := least(4, v_etape + 1); end if;
  update public.commandes set etape = v_nouvelle where ref = p_ref;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'etape', v_nouvelle);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_etape(p_mot_de_passe text, p_ref text, p_etape integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v_nouvelle smallint;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  v_nouvelle := greatest(0, least(4, coalesce(p_etape, 0)))::smallint;
  update public.commandes set etape = v_nouvelle where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'etape', v_nouvelle);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_statut(p_mot_de_passe text, p_ref text, p_statut text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  if p_statut not in ('en_cours', 'annulee', 'remboursee') then
    raise exception 'Statut inconnu : %', p_statut using errcode = 'check_violation';
  end if;
  update public.commandes set statut = p_statut where ref = p_ref;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'statut', p_statut);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_archiver_commande(
  p_mot_de_passe text, p_ref text, p_archiver boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  update public.commandes
     set statut = case when coalesce(p_archiver, true) then 'archivee' else 'en_cours' end,
         maj_le = now()
   where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'archivee', coalesce(p_archiver, true));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_champ(p_mot_de_passe text, p_ref text, p_champ text, p_valeur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  if p_champ not in ('vehicule', 'message_livreur', 'note') then
    raise exception 'Champ non modifiable : %', p_champ using errcode = 'check_violation';
  end if;
  execute format('update public.commandes set %I = $1 where ref = $2', p_champ)
    using p_valeur, p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'champ', p_champ);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_supprimer_commande(p_mot_de_passe text, p_ref text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  delete from public.commandes where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_purger_commandes(p_mot_de_passe text, p_confirmation text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v_avant integer; v_apres integer;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(trim(upper(p_confirmation)), '') <> 'SUPPRIMER' then
    raise exception 'Confirmation incorrecte : tapez SUPPRIMER.' using errcode = 'check_violation';
  end if;
  select count(*) into v_avant from public.commandes;
  delete from public.commandes where ref is not null;
  select count(*) into v_apres from public.commandes;
  return jsonb_build_object('ok', true, 'supprimees', v_avant - v_apres);
end;
$function$;

-- --- 6.5 Les chiffres et l'apercu ----------------------------

CREATE OR REPLACE FUNCTION public.gestion_apercu_purge(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object(
    'ok', true,
    'total',    (select count(*) from public.commandes),
    'livrees',  (select count(*) from public.commandes where etape = 4),
    'en_cours', (select count(*) from public.commandes where statut = 'en_cours'),
    'annulees', (select count(*) from public.commandes where statut in ('annulee','remboursee')),
    'chiffre',  (select coalesce(sum(total), 0) from public.commandes)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_recap(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object('ok', true, 'mois', (
    select coalesce(jsonb_agg(m order by m.mois desc), '[]'::jsonb)
    from (
      select to_char(date_trunc('month', c.cree_le), 'YYYY-MM') as mois,
             count(*) as total_commandes,
             round(sum(case when coalesce(c.statut, '') in ('annulee','remboursee') then 0
                            else coalesce(c.sous_total, 0) + coalesce(c.frais, 0) end), 2) as chiffre,
             count(*) filter (where coalesce(c.statut, '') = 'annulee') as annulees,
             count(*) filter (where coalesce(c.statut, '') = 'remboursee') as remboursees,
             count(*) filter (where coalesce(c.statut, '') not in ('annulee','remboursee')) as en_cours
      from public.commandes c
      where c.cree_le is not null and c.supprime_le is null
      group by date_trunc('month', c.cree_le)
      order by date_trunc('month', c.cree_le) desc limit 60
    ) m
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_envois_rates(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object('ok', true, 'envois', (
    select coalesce(jsonb_agg(e order by e.cree_le desc), '[]'::jsonb)
    from (select ref, champ, message, code, cree_le
          from public.envois_rates order by cree_le desc limit 100) e
  ));
end;
$function$;

-- --- 6.6 Les reglages ----------------------------------------

CREATE OR REPLACE FUNCTION public.gestion_reglages(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v public.reglages;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  select * into v from public.reglages where id = 'boutique';
  return jsonb_build_object('ok', true, 'reglages', to_jsonb(v));
end;
$function$;

-- Une seule version de gestion_reglages_ecrire : la plus complete.
CREATE OR REPLACE FUNCTION public.gestion_reglages_ecrire(
  p_mot_de_passe text, p_nom text DEFAULT NULL, p_slogan text DEFAULT NULL,
  p_baseline text DEFAULT NULL, p_theme text DEFAULT NULL,
  p_livraison jsonb DEFAULT NULL, p_zone jsonb DEFAULT NULL,
  p_infos jsonb DEFAULT NULL, p_sections jsonb DEFAULT NULL,
  p_contact text DEFAULT NULL, p_logo text DEFAULT NULL,
  p_fond text DEFAULT NULL, p_fond_flou integer DEFAULT NULL,
  p_accroche text DEFAULT NULL, p_reseaux jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  update public.reglages set
    nom       = coalesce(p_nom, nom),
    slogan    = coalesce(p_slogan, slogan),
    baseline  = coalesce(p_baseline, baseline),
    accroche  = coalesce(p_accroche, accroche),
    theme     = coalesce(p_theme, theme),
    livraison = coalesce(p_livraison, livraison),
    zone      = coalesce(p_zone, zone),
    infos     = coalesce(p_infos, infos),
    sections  = coalesce(p_sections, sections),
    reseaux   = coalesce(p_reseaux, reseaux),
    contact   = coalesce(p_contact, contact),
    logo      = coalesce(p_logo, logo),
    fond      = coalesce(p_fond, fond),
    fond_flou = coalesce(p_fond_flou, fond_flou),
    maj_le    = now()
  where id = 'boutique';
  return jsonb_build_object('ok', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_reseaux(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v jsonb;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  select reseaux into v from public.reglages where id = 'boutique';
  return jsonb_build_object('ok', true, 'reseaux', coalesce(v, '[]'::jsonb));
end;
$function$;

CREATE OR REPLACE FUNCTION public.gestion_reseaux_ecrire(p_mot_de_passe text, p_reseaux jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  update public.reglages
     set reseaux = coalesce(p_reseaux, '[]'::jsonb), maj_le = now()
   where id = 'boutique';
  return jsonb_build_object('ok', true);
end;
$function$;

-- --- 6.7 Les commandes (cote client) -------------------------

CREATE OR REPLACE FUNCTION public.creer_commande(
  p_suivi_id text, p_client_nom text, p_client_tel text,
  p_adresse text, p_code_postal text, p_ville text,
  p_articles jsonb, p_sous_total numeric, p_frais numeric,
  p_telegram text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ref text; v_total numeric; v_id uuid; v_essai integer := 0;
begin
  if coalesce(trim(p_suivi_id), '') = '' or coalesce(trim(p_client_nom), '') = ''
     or coalesce(trim(p_adresse), '') = '' or coalesce(trim(p_ville), '') = '' then
    raise exception 'Commande incomplete : nom, adresse et ville sont obligatoires.'
      using errcode = 'check_violation';
  end if;
  if p_articles is null or jsonb_array_length(p_articles) = 0 then
    raise exception 'Le panier est vide.' using errcode = 'check_violation';
  end if;
  loop
    v_essai := v_essai + 1;
    v_ref := '#C69-' || lpad((floor(random() * 9000) + 1000)::text, 4, '0');
    exit when not exists (select 1 from public.commandes where ref = v_ref);
    if v_essai > 50 then raise exception 'Impossible de generer une reference unique.'; end if;
  end loop;
  v_total := coalesce(p_sous_total, 0) + coalesce(p_frais, 0);
  insert into public.commandes (
    ref, suivi_id, etape, client_nom, client_tel, adresse, code_postal, ville,
    articles, sous_total, frais, total, telegram
  ) values (
    v_ref, p_suivi_id, 0, trim(p_client_nom), trim(p_client_tel), trim(p_adresse),
    trim(p_code_postal), trim(p_ville), p_articles,
    coalesce(p_sous_total, 0), coalesce(p_frais, 0), v_total, coalesce(p_telegram, '')
  ) returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'ref', v_ref, 'etape', 0, 'total', v_total);
end;
$function$;

CREATE OR REPLACE FUNCTION public.suivre_commande(p_suivi_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v public.commandes;
begin
  select * into v from public.commandes
   where suivi_id = p_suivi_id order by cree_le desc limit 1;
  if not found then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'ref', v.ref, 'etape', v.etape,
    'total', v.total, 'cree_le', v.cree_le, 'maj_le', v.maj_le);
end;
$function$;

CREATE OR REPLACE FUNCTION public.lire_commande(p_ref text, p_suivi_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v public.commandes;
begin
  select * into v from public.commandes where ref = p_ref and suivi_id = p_suivi_id;
  if not found then
    return jsonb_build_object('ok', false, 'erreur', 'Commande introuvable.');
  end if;
  return jsonb_build_object('ok', true, 'ref', v.ref, 'etape', v.etape,
    'articles', v.articles, 'sous_total', v.sous_total, 'frais', v.frais,
    'total', v.total,
    'adresse', jsonb_build_object('nom', v.client_nom, 'tel', v.client_tel,
      'adresse', v.adresse, 'cp', v.code_postal, 'ville', v.ville),
    'cree_le', v.cree_le, 'maj_le', v.maj_le);
end;
$function$;

CREATE OR REPLACE FUNCTION public.chercher_commande(p_ref text, p_jeton text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v public.commandes;
begin
  if coalesce(trim(p_jeton), '') = '' then return jsonb_build_object('ok', false); end if;
  select * into v from public.commandes
   where ref ilike '%' || replace(trim(upper(p_ref)), '#', '') || '%'
     and suivi_jeton = p_jeton
   order by cree_le desc limit 1;
  if not found then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'commande', to_jsonb(v));
end;
$function$;

CREATE OR REPLACE FUNCTION public.lire_commande_ajout(p_ref text, p_jeton text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v public.commandes;
begin
  select * into v from public.commandes where ref = p_ref and suivi_jeton = p_jeton;
  if not found then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'commande', to_jsonb(v));
end;
$function$;

CREATE OR REPLACE FUNCTION public.completer_commande(
  p_ref text, p_jeton text, p_articles jsonb, p_total numeric,
  p_ajouts integer DEFAULT 1, p_telegram text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
begin
  update public.commandes
     set articles = coalesce(p_articles, articles),
         total = coalesce(p_total, total),
         ajouts = coalesce(p_ajouts, ajouts),
         telegram_client = coalesce(nullif(p_telegram, ''), telegram_client),
         complement = true, dernier_ajout = now()
   where ref = p_ref and suivi_jeton = p_jeton;
  if not found then
    return jsonb_build_object('ok', false, 'erreur', 'Commande introuvable.');
  end if;
  return jsonb_build_object('ok', true, 'ref', p_ref);
end;
$function$;

CREATE OR REPLACE FUNCTION public.laisser_avis(p_note smallint, p_auteur text, p_texte text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if p_note is null or p_note < 1 or p_note > 5 then
    raise exception 'La note doit etre comprise entre 1 et 5.' using errcode = 'check_violation';
  end if;
  insert into public.avis (note, auteur, texte, publie)
  values (p_note, coalesce(nullif(trim(p_auteur), ''), 'Anonyme'),
          left(coalesce(trim(p_texte), ''), 1000), false)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'publie', false);
end;
$function$;

CREATE OR REPLACE FUNCTION public.etat_boutique()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_par_etape jsonb;
begin
  v_par_etape := (
    select coalesce(jsonb_object_agg(etape, n), '{}'::jsonb)
    from (select etape, count(*)::int as n from public.commandes group by etape) t
  );
  return jsonb_build_object('ok', true,
    'produits', (select count(*) from public.produits where actif),
    'commandes', (select count(*) from public.commandes),
    'avis_a_moderer', (select count(*) from public.avis where not publie),
    'par_etape', v_par_etape);
end;
$function$;

CREATE OR REPLACE FUNCTION public.reglages_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v public.reglages;
begin
  select * into v from public.reglages where id = 'boutique';
  if not found then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'reglages', to_jsonb(v));
end;
$function$;

-- --- 6.8 Les anciennes fonctions admin (compatibilite) -------
-- Elles gardent les anciennes signatures : un site deja
-- installe continue de fonctionner apres la mise a jour.

CREATE OR REPLACE FUNCTION public.admin_avancer(p_mot_de_passe text, p_ref text, p_sens integer DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean; v_etape smallint; v_nouvelle smallint;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  select etape into v_etape from public.commandes where ref = p_ref;
  if not found then
    raise exception 'Commande % introuvable.', p_ref using errcode = 'no_data_found';
  end if;
  if p_sens < 0 then v_nouvelle := greatest(0, v_etape - 1);
  else v_nouvelle := least(4, v_etape + 1); end if;
  update public.commandes set etape = v_nouvelle where ref = p_ref;
  return jsonb_build_object('ok', true, 'ref', p_ref, 'etape', v_nouvelle);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_commandes(p_mot_de_passe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  return jsonb_build_object('ok', true, 'commandes', (
    select coalesce(jsonb_agg(c order by c.cree_le desc), '[]'::jsonb)
    from (select ref, etape, client_nom, client_tel, adresse, code_postal,
                 ville, articles, total, paiement, complement, cree_le, maj_le
          from public.commandes order by cree_le desc limit 200) c
  ));
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_produit(
  p_mot_de_passe text, p_id text, p_nom text, p_rayon text,
  p_prix numeric, p_stock text, p_format text DEFAULT '',
  p_emoji text DEFAULT '', p_description text DEFAULT '',
  p_variantes jsonb DEFAULT '[]'::jsonb, p_options jsonb DEFAULT '[]'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare v_ok boolean;
begin
  select (empreinte = encode(sha256(p_mot_de_passe::bytea), 'hex'))
  into v_ok from public.admin where id = 'admin';
  if not coalesce(v_ok, false) then
    raise exception 'Mot de passe refuse.' using errcode = 'insufficient_privilege';
  end if;
  insert into public.produits
    (id, nom, rayon, prix, stock, format, emoji, description, variantes, options)
  values
    (p_id, p_nom, p_rayon, p_prix, p_stock, p_format, p_emoji, p_description,
     coalesce(p_variantes, '[]'::jsonb), coalesce(p_options, '[]'::jsonb))
  on conflict (id) do update set
    nom = excluded.nom, rayon = excluded.rayon, prix = excluded.prix,
    stock = excluded.stock, format = excluded.format, emoji = excluded.emoji,
    description = excluded.description, variantes = excluded.variantes,
    options = excluded.options;
  return jsonb_build_object('ok', true, 'id', p_id);
end;
$function$;




-- ============================================================
--  7. LE STOCKAGE : IMAGES ET VIDEOS
--
--  Un bucket Supabase n'accepte par defaut qu'une liste
--  restreinte de types de fichiers. Sans les types video,
--  tout envoi de video depuis la page de gestion est refuse
--  par la base avec ce message :
--
--    {"statusCode":"415","error":"invalid_mime_type",
--     "message":"mime type video/mp4 is not supported"}
--
--  Ce n'est ni le poids, ni le nom, ni les droits : c'est la
--  liste des types autorises.
-- ============================================================

-- --- Les buckets ---------------------------------------------
insert into storage.buckets (id, name, public)
values ('produits', 'produits', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('boutique', 'boutique', true)
on conflict (id) do update set public = true;

-- --- Les types autorises -------------------------------------
update storage.buckets
set allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp', 'image/gif',
      'video/mp4', 'video/webm', 'video/quicktime'
    ]
where id in ('produits', 'boutique');

-- --- Les droits ----------------------------------------------
drop policy if exists images_lecture on storage.objects;
create policy images_lecture on storage.objects
for select to anon, authenticated
using (bucket_id in ('produits', 'boutique'));

drop policy if exists images_depot on storage.objects;
create policy images_depot on storage.objects
for insert to anon, authenticated
with check (bucket_id in ('produits', 'boutique'));

drop policy if exists images_remplacement on storage.objects;
create policy images_remplacement on storage.objects
for update to anon, authenticated
using (bucket_id in ('produits', 'boutique'));

drop policy if exists images_suppression on storage.objects;
create policy images_suppression on storage.objects
for delete to anon, authenticated
using (bucket_id in ('produits', 'boutique'));

-- --- Controle ------------------------------------------------
--   select id, allowed_mime_types from storage.buckets;


-- ============================================================
--  CONTROLE FINAL — lancez ces requetes apres l'installation
-- ============================================================

-- Les 8 tables doivent apparaitre :
--   select table_name from information_schema.tables
--   where table_schema = 'public' order by table_name;

-- Le declencheur doit etre actif (tgenabled = O) :
--   select tgname, tgenabled from pg_trigger
--   where tgname = 'tr_variante_defaut';

-- Le compte admin doit exister :
--   select id, length(empreinte) from public.admin;

-- Les fonctions doivent etre la (environ 40 lignes) :
--   select proname from pg_proc
--   where pronamespace = 'public'::regnamespace order by proname;
