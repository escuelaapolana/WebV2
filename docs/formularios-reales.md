# Formularios reales del club (referencia para construirlos integrados)

Estos son los formularios que el club usa hoy en Google Forms. El plan es rehacerlos
como formularios propios que guarden en Supabase. **Ojo: piden datos sensibles (DNI,
tarjeta sanitaria de menores, IBAN/SEPA), así que se construyen con cuidado y con Andrés
presente**, no de forma automática. Van ligados a la parte de pagos (Stripe), que es fase
posterior.

## 1. Nueva alta escuela (2026/2027)
Campos: Correo · Nombre alumno/a · Primer apellido · Segundo apellido · Sexo ·
DNI alumno/a · SIP (tarjeta sanitaria) · Fecha de nacimiento · Turno de inscripción ·
¿Hermano/a también apuntado?

## 2. Renovaciones escuela
(No se pudo leer: el enlace era de edición, requiere login. Pedir a Andrés el enlace
público "viewform" o los campos.)

## 3. Alta de socio/a (formulario completo)
**MUY sensible: IBAN, DNI/NIE, fotos del DNI, datos de menores.**

Página 1 — DATOS PRINCIPALES (todo obligatorio salvo indicado):
- Correo · Nombre · Primer apellido · Segundo apellido (si no tiene, "-")
- Sexo (Hombre/Mujer)
- D.N.I. / NIE / NIF · Nacionalidad
- Ciudad de nacimiento · Provincia de nacimiento · País de nacimiento
- Fecha de nacimiento
- Domicilio · Localidad · C.P. · Provincia
- Teléfono móvil (se añade al grupo de WhatsApp del club) · Correo electrónico
- Señala lo procedente / alta en (casillas): Atletismo/Ruta · Montaña/trail · Triatlón · Natación

Página 1 — DATOS EQUIPACIÓN:
- Tallas de ropa (tabla: Camiseta / Pantalón / Calcetín × 16, S, M, L, XL, 2XL, 3XL)
- Peso (kg) · Estatura
- **Subidas de archivo:** Foto tipo carnet · DNI-NIE anverso · DNI-NIE reverso (máx 10 MB c/u)
- **IBAN - cuenta bancaria** (ES + 22 dígitos)

Página 2 — CONSENTIMIENTOS (obligatorios):
- Tratamiento de datos personales (texto RGPD completo) → "Autorizo"
- Autorización de imagen/fotos y cesión a patrocinadores → "Quedo enterado/a"
- En caso de menores de 18: acepta condiciones el padre/madre/tutor
- Compromiso de asistir a las Asambleas de socios → "Quedo enterado/a"

**Consideraciones para construirlo:**
- Los documentos (DNI, foto) van a un bucket **PRIVADO** de Supabase (no público como
  `imagenes`), con acceso solo de administración.
- El IBAN y el DNI son datos especialmente protegidos: RLS estricto (solo admin lee),
  y textos de consentimiento RGPD tal cual (el club los tiene redactados).
- Va ligado al **SEPA + pasarela de pago** (fase Stripe). Construir CON Andrés.

## 4. Orden de domiciliación SEPA

## 4. Orden de domiciliación SEPA (adeudo directo)
Campos: Correo · Nombre del deudor/titular · Dirección del deudor · Tipo de pago ·
Aceptación SEPA (casilla) · (falta el IBAN, que el resumen no capturó).
**Muy sensible (datos bancarios).** Requiere tratar el IBAN con cuidado (solo lectura de
administración) y encaja con la pasarela de pago.

## Enfoque recomendado
- Tablas nuevas en Supabase para cada alta, con RLS: cualquiera puede ENVIAR (insert),
  solo administración puede LEER.
- Construir primero las de la escuela (menos sensibles que el SEPA), revisando textos y
  consentimientos con el club.
- El SEPA + cobro: junto con Stripe, en fase de pagos.
