-- ============================================================
-- 143 · Los recursos de un grupo
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Un entrenador quiere colgarle a SU grupo una rutina de movilidad para
-- hacer en casa, y no hay dónde.
--
-- LO QUE HAY HOY
-- `documentos` es el tablón del club entero, con dos alcances: «público»
-- —lo ve cualquiera que entre en la web— y «socios» —lo ve cualquiera con
-- cuenta—. No hay nada entre medias. Para dejarle una rutina a dos personas
-- había que enseñársela a los cuatrocientos.
--
-- LO QUE SE HACE AQUÍ
-- Un tercer alcance, «grupo», con su `grupo_id`. Lo ven los atletas de ese
-- grupo, sus familias y su entrenador. Nadie más.
--
-- POR QUÉ NO SE CREA UNA TABLA NUEVA
-- Porque un recurso de grupo es un documento: tiene título, descripción,
-- categoría, archivo y orden, exactamente igual. Una tabla aparte obligaría
-- a duplicar la pantalla del panel, la del portal, la subida al almacén y
-- los enlaces temporales, y a partir de ahí a arreglar cada fallo dos veces.
--
-- EL ARCHIVO VA AL CUBO CERRADO, el mismo de «solo socios»
-- (`documentos-socios`), que no tiene enlace público y se abre con enlaces
-- que caducan al minuto. Un recurso de grupo es MÁS privado que uno de
-- socios, así que el cubo público no vale.
--
-- ⚠️ NINGÚN DATO PERSONAL SE ESCRIBE EN ESTE ARCHIVO. Este repositorio es
--    PÚBLICO. Aquí va el molde; qué se cuelga y para quién se decide desde
--    el panel.
--
-- Idempotente: se puede relanzar sin romper nada.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/143_los_recursos_de_un_grupo.sql
-- ============================================================

begin;

alter table public.documentos
  add column if not exists grupo_id uuid references public.grupos(id) on delete cascade;

comment on column public.documentos.grupo_id is
  'De qué grupo es este recurso. Solo tiene sentido con visibilidad = ''grupo''; '
  'en los públicos y los de socios va vacío. Si el grupo desaparece, el recurso '
  'se va con él: un documento colgado de un grupo que ya no existe no lo puede '
  'ver nadie y solo estorba.';

-- El tercer alcance
alter table public.documentos drop constraint if exists documentos_visibilidad_check;
alter table public.documentos add constraint documentos_visibilidad_check
  check (visibilidad in ('publico', 'socios', 'grupo'));

-- Y la regla que los mantiene coherentes: un documento de grupo SIN grupo no
-- lo vería nadie, y uno público CON grupo miente sobre para quién es.
alter table public.documentos drop constraint if exists documentos_grupo_coherente;
alter table public.documentos add constraint documentos_grupo_coherente
  check ((visibilidad = 'grupo' and grupo_id is not null)
      or (visibilidad <> 'grupo' and grupo_id is null));

create index if not exists ix_documentos_grupo on public.documentos (grupo_id)
  where grupo_id is not null;

-- ------------------------------------------------------------
-- QUIÉN LO VE
-- ------------------------------------------------------------
-- Las dos reglas de antes se dejan como estaban: lo público sigue siendo
-- público y lo de socios sigue siendo de socios. Esta se SUMA, y solo abre
-- lo que lleva `visibilidad = 'grupo'`.
--
-- Tres caminos hasta un grupo, y los tres cuentan:
--   · el atleta que entrena en él      -> mis_grupos_de_entreno()
--   · la familia que mira lo de su hijo -> mis_grupos_de_familia()
--   · el entrenador que lo lleva        -> grupos.entrenador_id
-- ------------------------------------------------------------
drop policy if exists "el grupo lee sus recursos" on public.documentos;
create policy "el grupo lee sus recursos" on public.documentos
  for select using (
    visibilidad = 'grupo'
    and activo
    and (
      grupo_id in (select public.mis_grupos_de_entreno())
      or grupo_id in (select public.mis_grupos_de_familia())
      or exists (
        select 1 from public.grupos g
         where g.id = public.documentos.grupo_id
           and g.entrenador_id = public.mi_perfil_id()
      )
    )
  );

commit;

-- ============================================================
-- LO QUE ESTE ALCANCE NO HACE
-- ------------------------------------------------------------
--   · No deja a un entrenador colgar recursos por su cuenta: repartir
--     documentos sigue siendo de administración, igual que antes. Si algún
--     día se quiere que cada entrenador cuelgue los suyos, hace falta otra
--     regla de escritura y decidir si puede borrar los de otro.
--   · No hay recursos «de una sección» ni «de varios grupos a la vez». Si
--     hiciera falta, el camino natural es un `grupos_id uuid[]`, no repetir
--     el documento.
-- ============================================================
