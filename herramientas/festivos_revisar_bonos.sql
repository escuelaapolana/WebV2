-- Revisar bonos del máster dados por un «no voy» en un día que (luego) fue
-- festivo/cancelado para la natación. SOLO LECTURA: no cambia nada.
-- Los bonos NO se quitan solos: lo decide Mario (natacion_abono_set o a mano).
--
-- Uso:  bash .secrets/psql.sh -f herramientas/festivos_revisar_bonos.sql
-- Necesita la migración 320 (excepcion_del_dia).
--
-- «festivo_despues» = sí → el aviso se hizo ANTES de declarar el festivo
-- (el caso típico: se dio el +1 y luego se cerró la piscina).

select ac.nombre                                   as nadador,
       a.fecha                                     as dia_avisado,
       to_char(f.hora, 'HH24:MI')                  as hora,
       f.grupo                                     as franja,
       z.x->>'motivo'                              as festivo,
       a.created_at::date                          as avisado_el,
       e.created_at::date                          as festivo_creado_el,
       case when e.created_at > a.created_at then 'sí' else 'no' end as festivo_despues,
       ab.saldo                                    as saldo_actual,
       (select count(*) from public.natacion_reservas r
         where r.acceso_id = a.acceso_id and r.estado = 'reservada'
           and r.creada_en > a.created_at)       as reservas_hechas_despues
  from public.natacion_ausencias a
  join public.natacion_accesos ac on ac.id = a.acceso_id
  left join public.natacion_franjas f on f.id = a.franja_id
  left join public.natacion_abonos ab on ab.acceso_id = a.acceso_id
  cross join lateral (select public.excepcion_del_dia(a.fecha, 'natacion') as x) z
  left join public.calendario_excepciones e on e.id = (z.x->>'id')::uuid
 where a.origen = 'aviso'
   and coalesce((z.x->>'cancelado')::boolean, false)
 order by a.fecha, ac.nombre;
