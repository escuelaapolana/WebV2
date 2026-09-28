-- 249 · Máster de natación: enlazar CORREO a cada ficha (para el correo de acceso)
-- ---------------------------------------------------------------------------
-- Los grupos y calles YA están bien en la app (de «Por franja»). De SportMember
-- se coge SOLO el correo. Por cada nadador Máster (nombre exacto de su
-- inscripción → su correo de SportMember): se busca su ficha por correo o por
-- nombre y se reusa; si no existe, se crea con nombre+correo. Se enlaza la
-- inscripción Máster a esa ficha (atleta_id) SIN tocar calle/nivel/franja.
-- Idempotente: solo rellena correo vacío y solo enlaza inscripciones sueltas.
-- ---------------------------------------------------------------------------
begin;
create extension if not exists unaccent;

do $$
declare rec record; fid uuid;
begin
  for rec in select * from (values
    ('Aglaya Salvatierra Martín','aglayasalvatierra@outlook.com'),
    ('ALBA FERRI GOSÁLBEZ','albaferrig@gmail.com'),
    ('ANA SANTOS RUIZ','anamsantosruiz@gmail.com'),
    ('ANDRÉS MACÍAS','maciasmoreno@gmail.com'),
    ('ANGELA UBACH MARTINEZ','aubachmartinez@yahoo.es'),
    ('ANTONIO FERNÁNDEZ MARÍN','afmarin74@gmail.com'),
    ('ANTONIO GONZÁLEZ RAEL','tonielx.ag@gmail.com'),
    ('BELEN GARCIA GARCIA','belengaga@gmail.com'),
    ('CARLOS JURADO CAÑIZARES','carlosjcanizares@gmail.com'),
    ('CAROLINA LÓPEZ MARTÍNEZ','carolina.lopez.martinez.78@gmail.com'),
    ('CHELO CABRERA GEA','chelychispy@gmail.com'),
    ('CRISTINA DÓLERA MORENO','cristinadolera@hotmail.com'),
    ('ELENA NOGUEROLES MORENO','elenanogueroles@gmail.com'),
    ('ESTER LILLO ADALID','ela2483@gmail.com'),
    ('FERNANDO JOSÉ RODRÍGUEZ SOLER','soy_07802@hotmail.com'),
    ('GEMA GOSÁLBEZ ABELLAN','gmga1973@gmail.com'),
    ('GLORIA ISABEL CLAVERO SERRANO','gloriescu@gmail.com'),
    ('ISAAC ESCLAPES ALVAREZ','iesclapes@hotmail.com'),
    ('Javier Vidal Marin','vidalmarin.javier@gmail.com'),
    ('JOSE LUIS PICAZO PEREZ','joseluis172@gmail.com'),
    ('Juani Caballero Encina','caballero.juani@gmail.com'),
    ('LIDIA SÁNCHEZ MANZANO','lidiasanchez026@gmail.com'),
    ('LOREN MARTOS MARTÍNEZ','alarinseriesson@gmail.com'),
    ('LUCAS GOMEZ RODRIGUEZ','llucman@gmail.com'),
    ('Manuela Escanio Brito','manuelaescaniobrito@icloud.com'),
    ('MARCIN LYP','marcin.lyp@gmail.com'),
    ('MARÍA CRISTINA MARUCHO POLICANO','policanocris@gmail.com'),
    ('MARIBEL GARCÍA SAAVEDRA','maribelgarcisaa@gmail.com'),
    ('MARIO CLAVERO SERRANO','mario.apolana@gmail.com'),
    ('MOUNIR RATNI','mounirratni2024@gmail.com'),
    ('NURIA SAHAGÚN CASANOVA','nuriasahagun@gmail.com'),
    ('NURIA TAJADURA MANJARIN','nuriatajadura@gmail.com'),
    ('PALOMA SOLERA RASERÓN','psolera4@gmail.com'),
    ('PASCAL RAZUREL','pascalrazurel@gmail.com'),
    ('Pascual Pastor','ppastor.quirant@gmail.com'),
    ('PEDRO LUIS GARCINUÑO ENRÍQUEZ','pedroluisge@gmail.com'),
    ('SILVIA CONSTANTINI','silviacostantini2.0@yahoo.com')
  ) as t(nombre, email) loop
    fid := null;
    select id into fid from public.atletas where lower(email)=rec.email order by created_at limit 1;
    if fid is null then
      select id into fid from public.atletas
       where unaccent(lower(nombre||' '||coalesce(apellidos,'')))=unaccent(lower(rec.nombre))
       order by created_at limit 1;
    end if;
    if fid is null then
      insert into public.atletas(nombre, email) values (rec.nombre, rec.email) returning id into fid;
    else
      update public.atletas set email=rec.email where id=fid and (email is null or btrim(email)='');
    end if;
    update public.natacion_inscripciones set atleta_id=fid
     where activa and tipo='Máster' and atleta_id is null
       and unaccent(lower(nombre))=unaccent(lower(rec.nombre));
  end loop;
end $$;

commit;

