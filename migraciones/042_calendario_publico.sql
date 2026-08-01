-- ============================================================
-- 042 · El calendario del club vuelve a ser PÚBLICO (decisión del club)
-- ------------------------------------------------------------
-- Contexto: la migración 041 cerró el acceso anónimo a las vistas de
-- agenda para tapar una fuga. Pero el club QUIERE que un visitante sin
-- cuenta vea la actividad (es gancho de captación: "aquí siempre hay
-- alguien entrenando"). La portada y /calendario/ se diseñaron así.
--
-- Se puede hacer con seguridad porque las dos vistas son CURADAS: solo
-- exponen día, hora, lugar, grupo y plazas. NO exponen `bloques` (los
-- ejercicios del entrenamiento) ni `nota_razonamiento`, que siguen
-- protegidos en la tabla base `sesiones` y solo los ve tu grupo.
--
-- Lo que NO se toca (sigue cerrado tras la 041):
--   · Las tablas base (un anónimo no lee `sesiones` ni `cubo_clases`).
--   · Bonos, reservas y movimientos de El Cubo (solo gestores reales).
--   · Los precios de los pedidos (los fija el servidor).
-- ============================================================

-- 1) Agenda de entrenos y eventos: lectura pública de la vista curada.
--    (Es SECURITY DEFINER a propósito: enseña solo las columnas de arriba.)
grant select on public.sesiones_agenda to anon;

-- 2) Clases de El Cubo con su ocupación: idem, para que la web pública
--    pueda mostrar el horario y si quedan plazas.
--    Vuelve a DEFINER porque con `security_invoker` un visitante no lee
--    la tabla base y la vista salía vacía.
alter view public.cubo_clases_ocupacion set (security_invoker = false);
grant select on public.cubo_clases_ocupacion to anon;

-- Nota: las funciones de recuento (sesion_num_apuntados, cubo_clase_ocupadas,
-- cubo_clase_en_espera) creadas en la 041 siguen siendo las que calculan la
-- ocupación, para que los números salgan bien sea quien sea quien mire.
