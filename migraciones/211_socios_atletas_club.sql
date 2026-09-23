-- 211 · Registro de socios y atletas del club (import)
-- Se importa el registro del club: SOCIOS (cuota anual, la lleva Isa) y ATLETAS
-- (compiten por el club con licencia del club, pero NO son socios: ni cuota de
-- socio ni voto). La ficha (atletas) gana dos datos del registro:
--   · numero_socio  · las SECCIONES (atletismo, montaña, triatlón, familiar,
--     simpatizante) a las que pertenece cada uno.
-- Y se admite un tipo nuevo de membresía: 'atleta'.
alter table public.atletas add column if not exists numero_socio text;
alter table public.atletas add column if not exists secciones text[];

alter table public.atletas drop constraint if exists atletas_tipo_membresia_chk;
alter table public.atletas add constraint atletas_tipo_membresia_chk
  check (tipo_membresia is null or tipo_membresia = any (array['escuela','socio','municipal','cubo','atleta']));
