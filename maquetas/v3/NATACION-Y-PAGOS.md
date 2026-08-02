# Natación, descansos y pagos — notas para Claude Code

Repo: `escuelaapolana/WebV2` (+ app y admin)
Diseños: `Natacion Apolana.dc.html` · `Pagos Apolana.dc.html` · `App Apolana navegacion.dc.html`

Documentos anteriores vigentes: `ARREGLOS.md`, `PAGINAS-NUEVAS.md`,
`ENTREGA-HOY.md`, `ESPECIFICACION.md`.

---

# 1 · Natación va por calles
**Diseño:** `Natacion Apolana.dc.html` — 25a modelo, 25b entrenador, 25c nadador, 25d descansos

Natación no funciona como atletismo. Un entrenador lleva cuatro calles a la vez:
la misma sesión, pero cada calle con sus metros, sus repeticiones y su salida.

## Modelo de datos

**Una sesión, N versiones.** El entrenador escribe la sesión una vez con su
estructura de bloques (calentamiento, técnica, principal, vuelta a la calma).
Cada calle hereda la estructura y sobrescribe solo: metros, repeticiones,
salida o descanso, y notas.

**La calle es un nivel, no un grupo.** Un nadador se mueve de calle sin cambiar
de grupo ni de cuota. Al moverlo, su entreno de hoy cambia solo. La cuota va
con el grupo; la calle va con la forma del día. Guardar histórico de en qué
calle nadó cada día.

**Unidades propias:**
- Volumen en **metros**, nunca kilómetros
- Ritmo como **salida cada X** (`1'40"`), nunca min/km
- Estilos abreviados: LI, ES, BR, MA, EST

## Pantallas

### Entrenador (móvil, no tablet)
1. **Las cuatro calles** — una tarjeta por calle con su nivel, sus metros
   totales, la serie del bloque en curso y quién nada en ella (avatares).
   Borde izquierdo de color por nivel. Botones: asistencia, siguiente bloque.
2. **Una calle abierta** — fila C1-C4 arriba para saltar sin volver atrás.
   Bloques con estado (hecho / en curso / pendiente), separadores de descanso,
   y botón para ajustar solo esa calle. Acción secundaria: mover nadador.

**No** hacer una tabla de cuatro columnas comparables en 402 px. El entrenador
mira una calle, corrige, pasa a la siguiente.

### Nadador
1. **Su calle y nada más.** Nunca ve las otras calles ni quién nada en ellas.
   Bloques listados con metros por bloque y total de sesión.
2. **Feedback** — en metros y por bloque, no en ritmos: cuántos metros completó,
   cómo se le hizo el principal (fácil / justo / duro), mejor 100 opcional,
   y una nota para el entrenador.

---

# 2 · Descansos — faltaban en todas las disciplinas
**Diseño:** `Natacion Apolana.dc.html` 25d · `App Apolana navegacion.dc.html` 22a

Sin recuperación una serie no dice nada: 6×800 con 90" no tiene nada que ver
con 6×800 con 3'. Hoy no aparece en ninguna disciplina.

| Deporte | Cómo se expresa | Ejemplo |
|---|---|---|
| Natación | Dos modos por bloque, a elegir. **Salida cada X**: nadar y descansar caben dentro. **Descanso fijo**: X segundos al tocar pared. | `8 × 50 salida 1'00"` · `10 × 100 descanso 20"` |
| Atletismo pista | Recuperación en tiempo o en metros, indicando trote o parado. Obligatoria. | `6 × 800 rec 2' trote` · `10 × 400 rec 200 m` |
| Running | Igual que pista. En rodajes y tiradas el campo se oculta. | `5 × 1.000 rec 90"` |
| El Cubo · fuerza | Descanso entre series y descanso entre ejercicios, **separados**. | `4 × 6 sentadilla desc. 2'` + `3' entre ejercicios` |
| Montaña | Por desnivel, no por series. La recuperación es la bajada. | `5 × subida 400 m D+ · rec: bajada suave` |

## Reglas comunes
- **Separador de descanso entre bloques** en las cinco disciplinas. No existe hoy.
- **Volumen y tiempo estimado, separados.** Con la recuperación puesta se puede
  calcular la duración: mostrar `2.000 m` y `~55'`. Las familias planifican con
  el tiempo, no con los metros.
- **Nunca un campo vacío.** Si un bloque no lleva recuperación, el campo
  desaparece. Un `—` hace dudar de si falta el dato o no hay descanso.
- En natación, distinguir visualmente salida de descanso con etiqueta de color.
  Se confunden y son cosas distintas.

---

# 3 · Pagos
**Diseño:** `Pagos Apolana.dc.html` — 26a-26d estados, 27a-27e tarjeta

Solo con sesión iniciada. **Los números de cuenta van en base de datos, nunca
en el HTML** — el código de la web es público. No diseñar nada de esto para la
web pública.

## Cómo cobra el club

| Concepto | Forma | Detalle |
|---|---|---|
| Escuela de atletismo | Domiciliación, **dos pagos** | Octubre y diciembre. **Cuenta propia** |
| Socios y adultos | Domiciliación, **un pago** | Día 3 de cada mes. **Cuenta distinta** |
| Licencia, ropa, bonos de El Cubo | Transferencia o tarjeta | Puntual |

Titular de las dos cuentas: **Club Atletismo Apolana**.
Concepto según el pago: `Licencia · nombre`, `Bono Cubo · nombre`, `Ropa · nombre`.

## Los cuatro estados

1. **Al día** — una línea verde y a otra cosa. Lo que ocupa la pantalla es lo
   puntual (bonos, licencia, ropa), no la cuota.
2. **Recibo pendiente domiciliado** — importe, concepto, fecha de cargo y
   últimos cuatro dígitos de la cuenta. El mensaje central es **"no tienes que
   hacer nada"**. Incluye el bloque de las tres formas de cobro del club.
3. **Transferencia** — IBAN y concepto en **dos botones de copiar separados**.
   Es el estado donde más se equivoca la gente y el concepto merece su propio
   gesto. Se muestra siempre la cuenta que le toca a ese socio, nunca las dos.
   Explicar por qué importa el concepto.
4. **Recibo devuelto** — **ámbar, nunca rojo, y nunca la palabra impago.** Dos
   salidas explícitas: volver a domiciliarlo o pagar por transferencia. Una
   línea diciendo que puede seguir entrenando mientras se resuelve.

## Contacto
Isabel Fuentes (contable) a un toque desde las cuatro pantallas.
Pendiente de decidir: atajo a Adrián (escuelas) siempre, o solo cuando el pago
es de la escuela.

## Pago con tarjeta (Stripe)
Solo bonos, licencias y ropa. **Las cuotas no**, siguen domiciliadas.

1. **Elegir** — precio por uso junto al precio total, para que nadie eche
   cuentas. Marcar el más usado. Avisar de usos restantes y caducidad.
2. **Confirmar** — concepto, a nombre de quién, y **la comisión desglosada**
   (62,00 + 0,95 = 62,95). Nunca como sorpresa. Nota de que Stripe cobra y el
   club no guarda la tarjeta.
3. **Volviendo** — pantalla propia con el importe visible y aviso de no cerrar.
   Nunca un spinner mudo. La pantalla de tarjeta la pone Stripe.
4. **Pagado** — lo que ha ganado arriba y grande ("Ya tienes 10 usos"), con el
   total sumado a lo que ya tenía y su caducidad. Acción principal: **reservar
   una clase**. Justificante en PDF y referencia de pago.
5. **Fallo** — ámbar, "no se te ha cobrado nada", qué ha dicho el banco en
   lenguaje llano, reintentar, y la alternativa de transferencia.

Los usos se añaden **al confirmarse el pago**, sin esperar al banco. Ese es el
motivo de existir del pago con tarjeta.

## Decisiones abiertas
- ¿El club repercute la comisión o la absorbe? Si la absorbe, se quita la línea.
- Atajo a Adrián: ¿siempre o solo en pagos de escuela?

---

## Sigue pendiente de antes
- Horarios y precios de deporte adaptado y triatlón municipal (septiembre)
- Precios reales de tienda, por la UI de admin
- Fotos de Miguel Á. Pellín y José Fernández
- Copy placeholder: citas de entrenadores y descripciones de grupo
- `ARREGLOS.md` sigue **sin aplicar** en producción, incluidos los dos
  cargadores colgados: "Hoy en el club" y "Cargando tu panel…" en `/socio/`
