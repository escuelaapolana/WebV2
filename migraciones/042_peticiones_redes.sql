-- ============================================================
-- 042 · PETICIONES DE REDES · pedir un post de Instagram al club
-- ------------------------------------------------------------
-- QUÉ RESUELVE (encargo del dueño):
--   Los socios, atletas y familias quieren proponer que el club
--   publique en Instagram un post de un atleta, una sección, un
--   evento o un resultado. Hoy esas ideas llegan sueltas por
--   WhatsApp y se pierden. Con esta tabla la propuesta se guarda
--   con su descripción y sus fotos, y el club decide después si la
--   publica o no.
--
-- IMPORTANTE · ESTO NO PUBLICA EN INSTAGRAM:
--   La web es estática y no puede publicar sola en Instagram. Aquí
--   solo se GUARDA la petición. En /admin/redes/ el club revisa
--   cada una, prepara el texto y descarga las fotos, y luego una
--   persona sube el post a mano desde la cuenta del club. Por eso el
--   estado nunca pasa a «publicado» solo: lo marca una persona, y
--   guarda a mano el enlace al post ya publicado.
--
-- QUIÉN PROPONE / QUIÉN DECIDE:
--   · Proponer  → cualquier usuario con sesión, para SÍ MISMO
--     (solicitante_id = mi_perfil_id()). Solo ve sus peticiones.
--   · Decidir   → el club: administración (es_admin()) o el equipo
--     técnico (es_staff()). Leen todas y cambian estado y notas.
--   Un usuario NO ve las peticiones de otros ni cambia estados.
--
-- LAS FOTOS:
--   Van al bucket público «imagenes», carpeta «redes/». En «fotos»
--   se guardan las RUTAS (p. ej. 'redes/1785-foto.jpg'); la URL
--   pública se compone en el navegador con getPublicUrl(ruta).
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/042_peticiones_redes.sql
-- ============================================================

begin;

create table if not exists public.peticiones_redes (
  id            uuid primary key default gen_random_uuid(),
  -- Quién hace la petición (id de public.perfiles vía mi_perfil_id()).
  solicitante_id uuid references public.perfiles(id) on delete set null,
  -- De qué es el post: un atleta, una sección, un evento, un resultado u otro.
  tipo          text not null check (tipo in ('atleta','seccion','evento','resultado','otro')),
  -- Si es de un atleta concreto, su ficha (opcional).
  atleta_id     uuid references public.atletas(id) on delete set null,
  -- Si es de una sección, su clave ('competicion', 'montana'…). (opcional)
  seccion       text,
  -- Título corto de la propuesta.
  titulo        text,
  -- Lo que quieren que ponga el post. Obligatorio.
  descripcion   text not null,
  -- Rutas de las fotos dentro del bucket «imagenes» (carpeta «redes/»).
  fotos         text[] not null default '{}',
  -- En qué punto está: pendiente → en proceso → publicado / descartado.
  estado        text not null default 'pendiente'
                check (estado in ('pendiente','en_proceso','publicado','descartado')),
  -- Nota interna del club (por qué se descarta, cuándo se sube…). No la ve el socio.
  nota_club     text,
  -- Enlace al post de Instagram una vez publicado a mano.
  publicado_url text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.peticiones_redes is
  'Propuestas de socios/atletas/familias para un post del club en Instagram. La web no publica sola: el club decide y sube el post a mano.';
comment on column public.peticiones_redes.tipo   is 'De qué es el post: atleta / seccion / evento / resultado / otro.';
comment on column public.peticiones_redes.fotos  is 'Rutas en el bucket «imagenes» (carpeta «redes/»). No son URLs: la pública se compone con getPublicUrl.';
comment on column public.peticiones_redes.estado is 'pendiente / en_proceso / publicado / descartado. Solo el club lo cambia.';

-- Índices para la pantalla de gestión (por estado y por fecha) y para
-- que cada socio recupere rápido las suyas.
create index if not exists peticiones_redes_estado_idx      on public.peticiones_redes (estado);
create index if not exists peticiones_redes_creada_idx      on public.peticiones_redes (created_at desc);
create index if not exists peticiones_redes_solicitante_idx on public.peticiones_redes (solicitante_id);

-- updated_at al día (la función ya existe en la base).
drop trigger if exists peticiones_redes_updated on public.peticiones_redes;
create trigger peticiones_redes_updated
  before update on public.peticiones_redes
  for each row execute function public.handle_updated_at();

-- ------------------------------------------------------------
-- Candado (RLS)
-- ------------------------------------------------------------
alter table public.peticiones_redes enable row level security;

-- CREAR: cualquier usuario con sesión, pero solo para sí mismo.
drop policy if exists "propongo una peticion mia" on public.peticiones_redes;
create policy "propongo una peticion mia"
  on public.peticiones_redes
  for insert
  to authenticated
  with check (solicitante_id = mi_perfil_id());

-- LEER las mías.
drop policy if exists "veo mis peticiones" on public.peticiones_redes;
create policy "veo mis peticiones"
  on public.peticiones_redes
  for select
  to authenticated
  using (solicitante_id = mi_perfil_id());

-- LEER todas: el club (administración o equipo técnico).
drop policy if exists "el club ve todas las peticiones" on public.peticiones_redes;
create policy "el club ve todas las peticiones"
  on public.peticiones_redes
  for select
  to authenticated
  using (es_admin() or es_staff());

-- CAMBIAR estado y notas: solo el club.
drop policy if exists "el club gestiona las peticiones" on public.peticiones_redes;
create policy "el club gestiona las peticiones"
  on public.peticiones_redes
  for update
  to authenticated
  using (es_admin() or es_staff())
  with check (es_admin() or es_staff());

-- (A propósito no hay política de DELETE: las peticiones no se borran
--  desde la web; se descartan cambiando el estado a 'descartado'.)

commit;

-- --- Comprobación rápida ---------------------------------------------
select 'peticiones_redes creada' as que, count(*) as filas from public.peticiones_redes;
