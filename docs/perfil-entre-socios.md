# El perfil entre socios

Está hecho y está apagado. Este papel cuenta qué es, por qué está apagado, qué
hay que hacer el día que se quiera encender y qué se vería exactamente.

No hace falta saber de informática para leerlo. Donde hay algo que teclear, va
escrito tal cual, para copiar y pegar.

---

## 1 · Qué es

Un socio del club entra en el portal, busca a otro socio y ve su **ficha**:

- el nombre con el que esa persona quiere que la llamen
- su foto, si ha puesto una
- su rango (bronce, plata, oro…) y sus puntos
- cuántas medallas y cuántos retos lleva conseguidos

**Y nada más.** Ni el correo, ni el teléfono, ni la edad, ni el grupo, ni los
pagos, ni **una sola marca ni un solo tiempo**.

Lo de las marcas no es un olvido: si la ficha enseñara tiempos, dejaría de ser
una ficha y sería una clasificación encubierta, que es justo lo que se decidió
no hacer. La competición del club es la **Liga Apolana**, y punto.

---

## 2 · Por qué está apagado

Lo decidió el diseñador, junto con el resto de decisiones cerradas:

> «Retos y Liga: separados. Los retos son personales, para ver tu propia mejora.
> Nada público.»

Los retos sirven para que cada uno vea si está mejorando. En el momento en que
la ficha de cada socio se puede consultar, aunque no haya tabla, aquello se
convierte en una comparación entre socios: quién tiene más medallas, quién va
por delante. Y eso ya lo hace la Liga.

Así que el perfil entre socios **se ha construido entero** —está probado y
funciona— pero se queda detrás de un interruptor apagado, igual que la
clasificación de los retos. El día que Liga y Retos se aclaren entre ellos, se
enciende y ya está.

### Qué ve un socio hoy en «Mi perfil»

El interruptor **sigue a la vista, pero no se puede tocar**, con la razón
escrita debajo: *«el perfil entre socios llegará más adelante»*.

Es a propósito. Si se quitara de la pantalla, nadie sabría que existe y el día
que apareciera sería una sorpresa. Estando a la vista y bloqueado, el socio sabe
que eso llegará, y **nadie lo enciende por error**.

También hay un botón, **«Ver qué se enseñaría»**, que pinta la ficha tal como se
vería. Es una vista previa: hoy no la tiene delante nadie más, y la propia
pantalla lo dice.

---

## 3 · El lío que se ha deshecho

Antes había **dos interruptores para lo mismo**, en dos pantallas distintas:

| Dónde | Qué decía |
|---|---|
| «Mis retos» | *Perfil visible para otros socios* |
| «Mi perfil» | *Otros socios del club pueden ver mi perfil* |

Y para salir hacía falta tener **los dos encendidos**. Es decir: un socio podía
encender uno, quedarse tan tranquilo, y seguir sin salir en ninguna parte sin
entender por qué.

Ahora **hay uno solo** y vive en **«Mi perfil»**, que es donde la gente ya va a
cambiar su foto y su nombre. En «Mis retos» queda una línea que lo cuenta y
lleva a Mi perfil, sin interruptor.

De paso se ha aclarado otra confusión: el interruptor de «Mi perfil» era en
realidad el que decidía si tu nombre salía en las **clasificaciones de la web**
(récords, palmarés, ranking). Decía una cosa y hacía otra. Ahora ese interruptor
está donde toca, en la tarjeta **«Tu nombre en las clasificaciones»**, y sí
funciona hoy.

O sea, en «Mi perfil» hay dos cosas distintas y bien separadas:

1. **Perfil entre socios** — la ficha que otro socio abre. Apagado, no se toca.
2. **Tu nombre en las clasificaciones** — si tu nombre sale junto a tus marcas
   en la web del club. Funciona desde hoy.

---

## 4 · Los menores

Hoy la regla es la dura: **un menor de edad no tiene ficha visible para otros
socios, ni con permiso de su familia**. Sus medallas y sus retos los ven su
familia y su entrenador. Mientras el perfil entre socios esté apagado, esto **no
se toca**.

El día que se encienda, la regla que se decidió es otra, algo más abierta:

- **13 años cumplidos**, y
- **permiso familiar expreso**, que la familia puede retirar cuando quiera.
  Se retira y esa persona **desaparece al momento** de todas partes.
- Por debajo de 13 años, ni con permiso: el interruptor no existe.

Esa regla **ya está escrita en la base de datos**, preparada, pero **sin usar**.
No relaja nada hoy: hoy siguen fuera todos los menores de 18.

Y hay una cosa que **no cambia nunca**, se encienda lo que se encienda:

> **En una cuenta de menor no se enseña la foto jamás, y el nombre sale siempre
> abreviado** («Marina E.»), aunque esa persona se haya puesto otro apodo.

Eso no depende de que nadie se acuerde de marcarlo: lo hace la base de datos
sola.

---

## 5 · Qué se vería, y qué no

**Sí se vería**

- Nombre elegido (o el abreviado si no ha elegido ninguno)
- Foto, solo si esa persona ha puesto una **y es mayor de edad**
- Rango y puntos
- Número de medallas y de retos conseguidos
- La sección y el rango en la cabecera de la ficha

**No se vería, en ningún caso**

- Marcas, tiempos, récords personales
- Pagos, recibos, cuotas
- Correo, teléfono, dirección, fecha de nacimiento
- Grupo de entrenamiento, asistencias, sensaciones de los entrenos
- La foto de un menor
- Nada de nadie que no lo haya encendido a mano
- Nada de nadie que esté de baja

Y quien no haya entrado con su cuenta —cualquiera que llegue a la web desde
fuera— **no ve absolutamente nada de esto**. Ni la lista, ni una ficha, ni el
interruptor.

---

## 6 · El día que se quiera encender

Son tres pasos y hay que dárselos a quien lleve la base de datos. **El orden
importa.**

### Paso 1 · Poner la regla de los 13 años

En el archivo `migraciones/068_perfil_socios.sql`, dentro de la vista
`miembros_juego`, hay una línea marcada con el comentario *«EL DÍA QUE SE
ENCIENDA»*. Hay que cambiar esta línea:

```sql
    and public.juego_es_menor(a.fecha_nacimiento) = false;
```

por esta otra, que ya está escrita ahí al lado:

```sql
    and (public.juego_es_menor(a.fecha_nacimiento) = false
         or public.perfil_socios_menor_apto(a.fecha_nacimiento, pj.autoriza_parental_en));
```

y volver a lanzar el archivo:

```
bash .secrets/psql.sh -f migraciones/068_perfil_socios.sql
```

Si no se hiciera este paso no pasaría nada malo: seguiría sin salir ningún
menor. Simplemente no estaría la regla nueva.

### Paso 2 · Pedir el permiso a las familias

De los socios de 13 a 17 años, el que quiera ficha visible necesita que su
familia lo autorice. Ese permiso se apunta en la ficha de retos de esa persona,
con **quién lo dio y cuándo**. Sin las dos cosas no vale y esa persona no sale.

Para retirarlo se borra la fecha, y esa persona desaparece al momento.

Este paso es de gestión, no de informática: hay que decidir cómo se pide el
permiso (un formulario en el portal de la familia, un papel firmado…). Sin
permiso no hace falta hacer nada: esos socios no salen y ya está.

### Paso 3 · Encender el interruptor

Es una sola línea:

```sql
update public.juego_ajustes set perfil_socios = true, actualizado = now() where id = 1;
```

En cuanto se lanza, en «Mi perfil» **el interruptor se desbloquea solo**. No hay
que tocar ni una página.

### Qué pasa el minuto después

**No aparece nadie de golpe.** El interruptor de cada socio nace apagado, así
que solo saldrá quien entre en «Mi perfil», lo encienda y le dé a guardar. El
club queda invisible por defecto y cada uno decide.

Conviene avisar antes por el buzón o por WhatsApp, para que la gente entienda
qué es lo que ha aparecido de repente en su perfil.

### Para volver a apagarlo

```sql
update public.juego_ajustes set perfil_socios = false, actualizado = now() where id = 1;
```

Es instantáneo y **no borra nada**: las fichas dejan de verse y las preferencias
de cada uno se quedan guardadas por si se vuelve a encender.

---

## 7 · Dónde está cada cosa

| Qué | Dónde |
|---|---|
| El interruptor del club | Base de datos, `juego_ajustes.perfil_socios` |
| El interruptor de cada socio | Base de datos, `perfil_juego.participa` |
| La pantalla donde se toca | `portal/perfil/` |
| La regla de quién sale | Base de datos, vista `miembros_juego` |
| La regla de los 13 años, preparada | Función `perfil_socios_menor_apto()` |
| La migración | `migraciones/068_perfil_socios.sql` |
| La decisión del diseñador | `maquetas/v3/DECISIONES-Y-RETOS.md`, parte 1 |

Los interruptores viven en la base de datos y **no en las páginas** a propósito:
así se enciende y se apaga sin tocar ni publicar nada, y el efecto es inmediato
para todo el mundo a la vez.
