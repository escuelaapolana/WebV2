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

## 3. Alta socio online
(No se pudo leer automáticamente: devolvió 401. Pedir a Andrés los campos.)

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
