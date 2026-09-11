-- 176 · «cubo» como tipo de membresía de atleta
-- ------------------------------------------------------------
-- Quien entrena en El Cubo no es socio ni de la escuela: lleva su
-- propia etiqueta «cubo». El CHECK de tipo_membresia solo admitía
-- escuela/socio/municipal; añadimos 'cubo'.
-- ============================================================

begin;

do $$
declare c text;
begin
  select conname into c
    from pg_constraint
   where conrelid = 'public.atletas'::regclass
     and contype = 'c'
     and pg_get_constraintdef(oid) ilike '%tipo_membresia%';
  if c is not null then
    execute 'alter table public.atletas drop constraint ' || quote_ident(c);
  end if;
end $$;

alter table public.atletas
  add constraint atletas_tipo_membresia_chk
  check (tipo_membresia is null or tipo_membresia in ('escuela', 'socio', 'municipal', 'cubo'));

commit;
