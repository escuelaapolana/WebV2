-- ============================================================
-- 012 · COMPETICIONES + CIRCULARES + INSCRIPCIONES + BONO
-- ------------------------------------------------------------
-- Qué resuelve:
--   1) El club publica una competición con su CIRCULAR (PDF de la
--      federación, subida a mano al bucket "imagenes/circulares/").
--   2) Los atletas se apuntan ELIGIENDO SUS PRUEBAS hasta una fecha
--      límite INTERNA (antes del cierre real de la federación).
--   3) El entrenador/admin revisa la lista y CONFIRMA. Al confirmar
--      se descuenta el coste del BONO anual del atleta.
--
-- Reutiliza tablas que ya existían (no duplica):
--   · competiciones      -> se le añaden columnas (circular, coste, plazo…)
--   · competicion_atleta -> pasa a ser la tabla de INSCRIPCIONES:
--                           una fila por (competición, atleta, PRUEBA).
-- Crea de nuevo:
--   · bono_movimientos (recargas y gastos del bono)
--   · bono_saldo       (vista con el saldo de cada atleta)
-- ============================================================

-- ------------------------------------------------------------
-- 1) COMPETICIONES: datos que faltaban
-- ------------------------------------------------------------
alter table public.competiciones add column if not exists ambito text default 'atletismo';
alter table public.competiciones add column if not exists circular_url text;
alter table public.competiciones add column if not exists coste numeric(8,2) default 0;
alter table public.competiciones add column if not exists fecha_limite_interna timestamptz;
alter table public.competiciones add column if not exists inscripcion_abierta boolean default false;
alter table public.competiciones add column if not exists notas text;
alter table public.competiciones add column if not exists creado_por uuid references public.perfiles(id);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'competiciones_ambito_check') then
    alter table public.competiciones
      add constraint competiciones_ambito_check
      check (ambito in ('atletismo','natacion'));
  end if;
end $$;

update public.competiciones set ambito = 'atletismo' where ambito is null;

comment on column public.competiciones.sede is 'Lugar donde se celebra (pista, ciudad…)';
comment on column public.competiciones.circular_url is 'URL pública del PDF de la circular (bucket imagenes, carpeta circulares/)';
comment on column public.competiciones.coste is 'Lo que cuesta por atleta; se descuenta del bono al confirmar';
comment on column public.competiciones.fecha_limite_interna is 'Hasta cuándo pueden apuntarse los atletas (plazo interno del club)';

-- ------------------------------------------------------------
-- 2) INSCRIPCIONES: una fila por competición + atleta + PRUEBA
--    (se reutiliza la tabla competicion_atleta, que estaba vacía)
-- ------------------------------------------------------------
alter table public.competicion_atleta add column if not exists prueba text;
alter table public.competicion_atleta add column if not exists estado text default 'apuntado';
alter table public.competicion_atleta add column if not exists marca_acreditada text;
alter table public.competicion_atleta add column if not exists created_at timestamptz default now();
alter table public.competicion_atleta add column if not exists confirmada_en timestamptz;
alter table public.competicion_atleta add column if not exists confirmada_por uuid references public.perfiles(id);

update public.competicion_atleta set estado = 'apuntado' where estado is null;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'competicion_atleta_estado_check') then
    alter table public.competicion_atleta
      add constraint competicion_atleta_estado_check
      check (estado in ('apuntado','confirmada','cancelada'));
  end if;
end $$;

create unique index if not exists competicion_atleta_unico
  on public.competicion_atleta (competicion_id, atleta_id, prueba);

create index if not exists idx_competicion_atleta_comp on public.competicion_atleta (competicion_id);
create index if not exists idx_competicion_atleta_atleta on public.competicion_atleta (atleta_id);

comment on table public.competicion_atleta is 'Inscripciones: una fila por competición + atleta + prueba. estado: apuntado / confirmada / cancelada.';
comment on column public.competicion_atleta.prueba is 'Nombre de la prueba, del catálogo public.pruebas';
comment on column public.competicion_atleta.marca_acreditada is 'Marca que se manda a la federación (opcional)';

-- ------------------------------------------------------------
-- 3) BONO: movimientos y saldo
-- ------------------------------------------------------------
create table if not exists public.bono_movimientos (
  id uuid primary key default gen_random_uuid(),
  atleta_id uuid not null references public.atletas(id) on delete cascade,
  concepto text not null,
  importe numeric(8,2) not null,          -- positivo = recarga, negativo = gasto
  competicion_id uuid references public.competiciones(id) on delete set null,
  fecha date not null default current_date,
  creado_por uuid references public.perfiles(id),
  created_at timestamptz default now()
);

create index if not exists idx_bono_mov_atleta on public.bono_movimientos (atleta_id);
create index if not exists idx_bono_mov_comp on public.bono_movimientos (competicion_id);

comment on table public.bono_movimientos is 'Bono anual del atleta: importe positivo = recarga/ingreso, negativo = gasto (inscripción).';

create or replace view public.bono_saldo as
  select a.id as atleta_id,
         coalesce(sum(m.importe), 0)::numeric(10,2) as saldo
  from public.atletas a
  left join public.bono_movimientos m on m.atleta_id = a.id
  group by a.id;

-- security_invoker: la vista respeta las reglas RLS de quien consulta
alter view public.bono_saldo set (security_invoker = on);
grant select on public.bono_saldo to authenticated;

-- ------------------------------------------------------------
-- 4) AYUDANTES para las reglas de seguridad
-- ------------------------------------------------------------

-- ¿Soy admin o el entrenador de este atleta? (los padres/el propio
-- atleta NO cuentan: ellos no confirman ni tocan el bono)
create or replace function public.soy_staff_de_atleta(p_atleta uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select public.es_admin() or exists (
    select 1 from public.atletas a
    where a.id = p_atleta and a.entrenador_id = public.mi_perfil_id()
  );
$function$;

-- ¿Está abierta la inscripción y dentro del plazo interno?
create or replace function public.competicion_abierta(p_comp uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select exists (
    select 1 from public.competiciones c
    where c.id = p_comp
      and coalesce(c.inscripcion_abierta, false)
      and (c.fecha_limite_interna is null or c.fecha_limite_interna > now())
  );
$function$;

grant execute on function public.soy_staff_de_atleta(uuid) to authenticated;
grant execute on function public.competicion_abierta(uuid) to authenticated;

-- ------------------------------------------------------------
-- 5) REGLAS DE SEGURIDAD (RLS)
-- ------------------------------------------------------------

-- 5.1 Competiciones: leerlas puede cualquiera (ya existía "lectura publica");
--     gestionarlas, solo admin (ya existía). No se toca.
alter table public.competiciones enable row level security;

-- 5.2 Inscripciones
alter table public.competicion_atleta enable row level security;

-- El atleta (o su familia) se apunta solo si la inscripción está abierta
drop policy if exists "atleta se apunta" on public.competicion_atleta;
create policy "atleta se apunta" on public.competicion_atleta
  for insert to authenticated
  with check (
    atleta_id in (select mis_atletas())
    and estado = 'apuntado'
    and public.competicion_abierta(competicion_id)
  );

-- …y puede quitarse mientras siga abierto y no esté ya confirmada
drop policy if exists "atleta se quita" on public.competicion_atleta;
create policy "atleta se quita" on public.competicion_atleta
  for delete to authenticated
  using (
    atleta_id in (select mis_atletas())
    and estado = 'apuntado'
    and public.competicion_abierta(competicion_id)
  );

-- El entrenador del atleta gestiona todo (confirmar, cancelar, marcas)
drop policy if exists "entrenador gestiona inscripciones" on public.competicion_atleta;
create policy "entrenador gestiona inscripciones" on public.competicion_atleta
  for all to authenticated
  using (public.soy_staff_de_atleta(atleta_id))
  with check (public.soy_staff_de_atleta(atleta_id));

-- 5.3 Bono
alter table public.bono_movimientos enable row level security;

-- El atleta y su familia VEN sus movimientos (leer, nunca escribir)
drop policy if exists "ver mis movimientos de bono" on public.bono_movimientos;
create policy "ver mis movimientos de bono" on public.bono_movimientos
  for select to authenticated
  using (atleta_id in (select mis_atletas()) or public.es_admin());

-- Solo admin o el entrenador del atleta mueven el bono
drop policy if exists "staff mueve el bono" on public.bono_movimientos;
create policy "staff mueve el bono" on public.bono_movimientos
  for all to authenticated
  using (public.soy_staff_de_atleta(atleta_id))
  with check (public.soy_staff_de_atleta(atleta_id));
