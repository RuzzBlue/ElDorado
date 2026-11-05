# Comprobaciones realizadas

## Verificado localmente

- Once pruebas automatizadas de lógica y flujo de demostración aprobadas mediante Node.js.
- Sintaxis JavaScript comprobada para la interfaz y el cliente de datos.
- Torneos de 2 a 32 patrullas: avance de ganadores, pases libres y cantidad correcta de partidos.
- Navegador a 390 × 844: acceso a demo, registro de un resultado, validación y suma correcta de victorias y puntos.
- Torneo de tres patrullas probado visualmente: pase libre, semifinal, final y generación de un único resultado oficial con puntos 3, 2 y 1.
- Corregido el desbordamiento horizontal de la cabecera móvil.
- Comprobación desde el navegador con la URL y clave pública reales: `camp_snapshot` respondió con el rechazo de sesión esperado, confirmando que la API y esa función están disponibles. No se usó ni solicitó la contraseña de PostgreSQL.
- El usuario confirmó que `supabase/smoke-test.sql` terminó correctamente en SQL Editor. Esta comprobación de la base fue ejecutada por el usuario; las contraseñas definitivas aún estaban pendientes de configurar al confirmar la prueba.

## Pendiente de conectar a las cuentas reales

- No se ejecutó la prueba SQL completa desde este entorno: no se dispone de acceso administrativo al SQL Editor. La instalación de un motor de pruebas local no estuvo disponible por restricciones de red del entorno.
- `supabase/smoke-test.sql` permite verificar las funciones, permisos, puntuación, auditoría y torneos desde el SQL Editor. Revierte sus cambios al terminar.
- GitHub Pages publicado desde `main / (root)` en https://ruzzblue.github.io/ElDorado/. Despliegue 38855085965 completado correctamente, commit 191fd0e5ff948d699a51f6556c2ddc8059ece9b0.
- La web pública se abrió correctamente y su botón Comprobar conexión confirmó la disponibilidad de Supabase.
- La sincronización de dos celulares y el acceso real por contraseña deben comprobarse después de configurar Supabase y publicar.

La demostración guarda datos únicamente en el navegador y no sustituye esas comprobaciones de integración.

La URL y la clave pública del proyecto Supabase ElDorado ya están configuradas en `config.js`. La clave pública no permite instalar tablas ni funciones; ese paso se realiza en SQL Editor.

## Editor de Super dios

- Trece pruebas automatizadas aprobadas, incluidas conservación de campos, conflictos de edición e historial administrativo.
- El usuario confirmó ejecución exitosa de `admin-editor.sql` y `admin-editor-test.sql`. La prueba SQL termina con ROLLBACK automático.
- Probado en demo: abrir colección, editar nombre, revisar antes y después y guardar con motivo sin perder otros campos.
- Publicado commit `b40f1e165a341c27cd742f8006b19fa2e7dc23e4`; despliegue `38856439571` completado correctamente.
- Verificado desde la web pública y sesión real de Super dios: catálogo de tablas propias y gestionadas, lectura de los 36 juegos y apertura de todos los campos de un juego.
- Verificada pantalla de 390 px sin desbordamiento horizontal. No se modificaron datos reales durante esta comprobación visual.
- Las tablas gestionadas por Supabase, los campos generados y el historial protegido no se editan desde la aplicación. La prueba del usuario cubre las escrituras reales dentro de una transacción revertida.
