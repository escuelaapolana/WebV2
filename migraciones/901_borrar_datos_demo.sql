-- =====================================================================
-- 901_borrar_datos_demo.sql  ·  BORRAR LOS DATOS DE DEMOSTRACIÓN
-- =====================================================================
-- Borra EXACTAMENTE lo que crea 900_datos_demo.sql y nada más.
--
-- Cómo lo sabe: todo lo de demostración tiene un identificador que
-- empieza por «dddddddd-». Lo que no empiece por ahí no se toca.
-- Los datos reales del club (el grupo Velocidad · Sub-20, los atletas de
-- prueba, las cuentas de verdad, el catálogo de pruebas y ejercicios,
-- los textos de la web, los documentos, las noticias y los productos)
-- quedan intactos.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/901_borrar_datos_demo.sql
--
-- Para probarlo sin borrar de verdad, se puede pegar su contenido entre
-- «begin;» y «rollback;».
-- =====================================================================

begin;

-- --- El Cubo -------------------------------------------------------
-- Primero las reservas, luego los movimientos (incluidos los que apunta
-- el propio sistema al reservar), luego los bonos y por último las clases.
delete from cubo_reservas
 where id::text like 'dddddddd-%'
    or clase_id in (select id from cubo_clases where id::text like 'dddddddd-%')
    or atleta_id in (select id from atletas where id::text like 'dddddddd-%');

delete from cubo_movimientos
 where id::text like 'dddddddd-%'
    or bono_id in (select id from cubo_bonos where id::text like 'dddddddd-%')
    or atleta_id in (select id from atletas where id::text like 'dddddddd-%');

delete from cubo_bonos
 where id::text like 'dddddddd-%'
    or atleta_id in (select id from atletas where id::text like 'dddddddd-%');

delete from cubo_clases where id::text like 'dddddddd-%';

-- --- Buzón, avisos y calendario ------------------------------------
delete from solicitudes_inscripcion where id::text like 'dddddddd-%';
delete from mensajes                where id::text like 'dddddddd-%';
delete from eventos                 where id::text like 'dddddddd-%';
delete from avisos                  where id::text like 'dddddddd-%';

-- --- Competiciones y bono de competición ----------------------------
delete from bono_movimientos
 where id::text like 'dddddddd-%'
    or atleta_id in (select id from atletas where id::text like 'dddddddd-%')
    or competicion_id in (select id from competiciones where id::text like 'dddddddd-%');

delete from competicion_atleta
 where id::text like 'dddddddd-%'
    or competicion_id in (select id from competiciones where id::text like 'dddddddd-%')
    or atleta_id in (select id from atletas where id::text like 'dddddddd-%');

delete from competiciones where id::text like 'dddddddd-%';

-- --- Dinero y marcas ------------------------------------------------
delete from pagos
 where id::text like 'dddddddd-%'
    or atleta_id in (select id from atletas where id::text like 'dddddddd-%');

delete from marcas_atleta
 where id::text like 'dddddddd-%'
    or atleta_id in (select id from atletas where id::text like 'dddddddd-%');

-- --- Entrenamientos --------------------------------------------------
-- Lo que cuelga de una sesión de demostración, antes que la sesión.
delete from registros_sesion where sesion_id in (select id from sesiones where id::text like 'dddddddd-%');
delete from asistencia       where sesion_id in (select id from sesiones where id::text like 'dddddddd-%')
                                 or grupo_id  in (select id from grupos   where id::text like 'dddddddd-%');
delete from ausencias        where sesion_id in (select id from sesiones where id::text like 'dddddddd-%')
                                 or atleta_id in (select id from atletas where id::text like 'dddddddd-%');
delete from sesiones where id::text like 'dddddddd-%'
                        or grupo_id in (select id from grupos where id::text like 'dddddddd-%');
delete from microciclos where id::text like 'dddddddd-%'
                           or grupo_id in (select id from grupos where id::text like 'dddddddd-%');

-- --- Fichas que cuelgan del atleta ----------------------------------
delete from notas_atleta       where atleta_id in (select id from atletas where id::text like 'dddddddd-%');
delete from notas_familia      where atleta_id in (select id from atletas where id::text like 'dddddddd-%');
delete from lesiones_atleta    where atleta_id in (select id from atletas where id::text like 'dddddddd-%');
delete from rm_atleta          where atleta_id in (select id from atletas where id::text like 'dddddddd-%');
delete from entrevista_inicial where atleta_id in (select id from atletas where id::text like 'dddddddd-%');

-- --- Atletas y grupos ------------------------------------------------
delete from atletas where id::text like 'dddddddd-%';
delete from grupos  where id::text like 'dddddddd-%';

-- --- Entrenadores ficticios y sus cuentas ----------------------------
-- Antes de borrarlos hay que soltar cualquier referencia que quede.
update grupos        set entrenador_id = null where entrenador_id::text like 'dddddddd-%';
update atletas       set entrenador_id = null where entrenador_id::text like 'dddddddd-%';
update sesiones      set creado_por    = null where creado_por::text    like 'dddddddd-%';
update competiciones set creado_por    = null where creado_por::text    like 'dddddddd-%';

delete from perfiles   where id::text like 'dddddddd-%';
delete from auth.users where id::text like 'dddddddd-%';

commit;

-- =====================================================================
-- Comprobación: todo esto tiene que dar 0
-- =====================================================================
select 'perfiles' as tabla, count(*) from perfiles where id::text like 'dddddddd%'
union all select 'auth.users', count(*) from auth.users where id::text like 'dddddddd%'
union all select 'grupos', count(*) from grupos where id::text like 'dddddddd%'
union all select 'atletas', count(*) from atletas where id::text like 'dddddddd%'
union all select 'sesiones', count(*) from sesiones where id::text like 'dddddddd%'
union all select 'marcas_atleta', count(*) from marcas_atleta where id::text like 'dddddddd%'
union all select 'pagos', count(*) from pagos where id::text like 'dddddddd%'
union all select 'competiciones', count(*) from competiciones where id::text like 'dddddddd%'
union all select 'competicion_atleta', count(*) from competicion_atleta where id::text like 'dddddddd%'
union all select 'bono_movimientos', count(*) from bono_movimientos where id::text like 'dddddddd%'
union all select 'avisos', count(*) from avisos where id::text like 'dddddddd%'
union all select 'eventos', count(*) from eventos where id::text like 'dddddddd%'
union all select 'mensajes', count(*) from mensajes where id::text like 'dddddddd%'
union all select 'solicitudes_inscripcion', count(*) from solicitudes_inscripcion where id::text like 'dddddddd%'
union all select 'cubo_clases', count(*) from cubo_clases where id::text like 'dddddddd%'
union all select 'cubo_bonos', count(*) from cubo_bonos where id::text like 'dddddddd%'
union all select 'cubo_reservas', count(*) from cubo_reservas where id::text like 'dddddddd%'
union all select 'cubo_movimientos', count(*) from cubo_movimientos where id::text like 'dddddddd%'
order by 1;
