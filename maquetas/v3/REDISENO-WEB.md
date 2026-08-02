# Rediseño web · las cuatro que faltaban

Maqueta: `Web Apolana rediseno.dc.html` (36a-36d)
Antes: `FUNDAMENTOS.md`, `KIT.md`, `CARACTER-Y-PANEL.md`, `PORTADA.md`, `CONTRASTE-Y-TIPOS.md`

Con la portada, horarios y los seis tipos, el sitio queda cubierto.

---

## 1 · Encontramos tu grupo · 36a
`/encuentra-tu-grupo/` — **hoy no existe y es el gancho principal**

Cabecera navy con dato duro (9 grupos, 5 deportes). Los cuatro pasos visibles a
la vez en la columna izquierda; el resultado en columna derecha, en crema fuerte.

### Los cuatro pasos
1. **¿Para quién?** — mi hijo/a · para mí
2. **¿Qué deporte?** — correr · pista · natación · triatlón · montaña · fuerza ·
   **«aún no lo sé»**
3. **¿Qué buscas?** — coger el hábito · bajar mi marca · preparar una carrera ·
   mantenerme. ⚠️ **Las opciones cambian según el deporte elegido** (era el punto
   flojo: no valen las mismas para natación que para montaña)
4. **¿Cuántos días?** — 2 · 3 · 4 o más

### Decisiones
- **El resultado se actualiza mientras eliges**, no al final. Es lo que hace que
  la gente termine el test: ve que responde
- **«Aún no lo sé» es opción legítima.** La mitad de quien entra no sabe si
  quiere correr o nadar; forzarle a elegir es perderlo. Con esa respuesta se
  proponen los dos grupos de iniciación
- El resultado da **nombre en ámbar, precio desglosado** (entrenamiento + cuota
  de socio) y dos acciones: probar 4 días y ver la página del grupo
- **Frase de escape**: cuál es el otro grupo parecido, para quien no se vea
  reflejado
- Cierre navy con WhatsApp para quien siga dudando

---

## 2 · Área de socio · 36b
`/socio/` — con sesión. Deja de ser una gestoría.

### Cabecera navy
Nombre a 38 px, número de socio, antigüedad y grupo. **Y el rango en ámbar a la
derecha** (`III · Plata · 168 puntos · 132 para Oro`): entrar a tu zona y ver tu
galón es lo que hace volver.

### Banda ámbar a sangre, debajo
El aviso de cobro, con el mensaje central: **«se pasará el día 3 · 102,50 € · no
tienes que hacer nada»**. Si está al día, desaparece.

### Columna principal
- **Este mes** — lista con la competición inscrita arriba (dorsal, cajón, cuántos
  van del club, y «puntúa para la Liga» en ámbar) y los próximos entrenos
- **Tus marcas este año** — cuatro tarjetas con cifra en mono y diferencia en
  verde. Solo el número: la progresión y los tests están en la app

### Columna lateral
- **Familia Apolana** con desglose por miembro, descuento aplicado y el total de
  un solo recibo
- Filas de acceso: recibos y pagos, bonos de El Cubo (5/8), datos y licencia

### Cierre navy
**«El entreno, el feedback y los tests están en la app; esto es para lo que se
hace sentado»** + botón de abrir la app. Sin esa frase la gente busca el entreno
aquí y no lo encuentra.

---

## 3 · Calendario · 36c
`/calendario/`

Cabecera navy con «14 competiciones» y el botón de suscripción. Banda de filtros
en crema fuerte: Mes · Semana (se elimina Día) y **los filtros aplicados como
chips con su «×»** más «Quitar filtros» — nunca «Filtrar · 0».

### La decisión clave
**Los entrenos se colapsan a «3 entrenos» en gris y solo se pintan
competiciones, controles y cierres de inscripción.** En un mes con 64 sesiones,
si se pintan todas, las carreras desaparecen. Hay un «Mostrar los entrenos» para
invertirlo.

Colores: carrera `#B0563A` · travesía `#6B5B8A` · control `#2F6FA8` · cierre de
inscripción `#B96F09`. Con leyenda debajo. La carrera del club destacada con
**borde de 2 px**.

Lateral con las próximas del club (inscripción directa) y el recordatorio de
suscripción por iCal — que es lo que la gente quiere de verdad: entrar una vez y
no volver.

---

## Decisiones tomadas que conviene validar · 36d

| Decisión | Marcha atrás |
|---|---|
| El test responde mientras eliges | — |
| «Aún no lo sé» en el paso del deporte | — |
| El rango del socio en su cabecera | — |
| El socio dice qué vive en la app | — |
| **Entrenos colapsados por defecto** | Si veis que la gente entra a mirar entrenos, se invierte el valor por defecto |
| **Desglose de Familia Apolana visible** | Si preocupa el ordenador compartido, se pliega con un «Ver el desglose» |

Las dos últimas eran las que quedaban abiertas de documentos anteriores.

---

---

## ⚠️ Corrección urgente · el pie está montado al revés

Ahora mismo el navy es **una tarjeta redondeada flotando dentro del crema**, con
el logotipo y los enlaces fuera de ella y media zona vacía a la derecha. Es
exactamente el problema de «todo flota», y en el pie se nota el doble.

**El pie ES la banda.** Todo va dentro del navy, a sangre, sin radio.

```
┌──────────────────────────────────────────────────────────┐
│ #2E4256 · a sangre, de borde a borde, sin esquinas       │
│                                                          │
│ CLUB APOLANA        Club          Contacto      Síguenos │
│ Atletismo, running… Inicio        625 47 38 30  Instagram│
│                     Hazte socio   636 06 17 00  TikTok   │
│                     Calendario    administra…   Facebook │
│                     Noticias                    WhatsApp │
│                     Tienda                               │
│ ────────────────────────────────────────────────────────  │
│ Con la colaboración de   [logo][logo][logo][logo]        │
└──────────────────────────────────────────────────────────┘
```

### Reglas
- **Fondo `#2E4256` a sangre**, `border-radius: 0`. Nada de tarjeta interior
- **Cuatro columnas** en una sola rejilla: identidad · Club · Contacto · Síguenos.
  Ahora hay dos bloques desalineados y una columna vacía
- **La identidad ocupa la primera columna**, dentro del navy: escudo, nombre en
  Barlow Condensed y la frase de una línea
- **Colaboradores en una fila final**, separada por
  `border-top: 1px solid rgba(255,255,255,0.14)`, con los logos a 26 px y
  monocromo. No en columna dentro de una tarjeta
- **Nada de fondo `rgba(255,255,255,0.12)` en los iconos** de redes: sobre navy
  ya contrastan. Solo icono + cuenta, alineados
- Texto: `rgba(255,255,255,0.85)` en enlaces, `rgba(255,255,255,0.55)` en
  rótulos de columna
- **Se pega al CTA navy** que va justo encima, sin crema entre medias

Ver el pie correcto montado en `Contraste Apolana.dc.html`, bloque 34b.

---

## Sigue pendiente

- Veinte fotos nuevas con cara y con dorsal; quitar las repetidas
- Un párrafo real por grupo, escrito por su entrenador
- Los dos cargadores colgados y los guiones de `/liga/`
- Horarios y precios de deporte adaptado y triatlón municipal (septiembre)
- Precios reales de tienda
