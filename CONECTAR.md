# Conectar tu proyecto ElDorado

La URL y la clave pública de tu proyecto Supabase ya están en `config.js`. No hace falta poner tu contraseña de PostgreSQL en ningún archivo.

## 1 Crear la base de la aplicación

Abre [SQL Editor de ElDorado](https://supabase.com/dashboard/project/ztwsaakpsdmdtszenrwz/sql/new).

En consultas nuevas, ejecuta estos archivos en este orden:

1. `supabase/schema.sql`: tablas privadas, sesiones, auditoría y funciones. Solo una vez, en el proyecto nuevo.
2. `supabase/seed.sql`: catálogo de las 36 actividades.
3. `supabase/optimize-sync.sql`: reduce las descargas cuando no hay cambios, para cuidar el consumo del plan gratuito. Si ya ejecutaste los dos anteriores, ejecuta solo este y la prueba siguiente.
4. `supabase/smoke-test.sql`: prueba automática de la integración. Revierte los datos de prueba; el SQL Editor debe indicar que terminó correctamente. Si aparece un error, copia su mensaje para corregirlo antes de usar la aplicación.
5. Si actualizas una instalación existente y quieres habilitar **Borrar puntajes** en Control, ejecuta `supabase/clear-results.sql`. No borra datos por sí mismo; solo crea la función que usa el botón.
6. Para habilitar **Reabrir** resultados validados o anulados en una instalación existente, ejecuta `supabase/reopen-results.sql`. Tampoco modifica datos por sí mismo.

## 2 Elegir las dos contraseñas de entrada

En una consulta nueva del SQL Editor, cambia las dos cadenas entre comillas por tus propias claves, diferentes entre sí, y ejecuta:

```sql
insert into camp_private.credentials (role, password_hash) values
  ('referee', extensions.crypt('CAMBIA_POR_CLAVE_DE_DIRIGENTES', extensions.gen_salt('bf', 10))),
  ('admin', extensions.crypt('CAMBIA_POR_OTRA_CLAVE_DE_ADMIN', extensions.gen_salt('bf', 10)))
on conflict (role) do update set password_hash=excluded.password_hash;
```

Estas son las contraseñas de **Dios** y **Super dios** de la aplicación; no son la contraseña de PostgreSQL. No subas tu consulta con las claves reales al repositorio.

## 3 Subir los archivos a GitHub

Abre [RuzzBlue ElDorado](https://github.com/RuzzBlue/ElDorado).

Puedes usar **Add file → Upload files**. Sube el **contenido** de esta carpeta, no la carpeta contenedora. `index.html` debe quedar directamente en la raíz del repositorio. Comprueba que también esté `.github/workflows/pages.yml`.

Confirma la subida con **Commit changes** en `main`.

Después abre **Settings → Pages → Source → GitHub Actions**. En **Actions**, ejecuta **Publicar El Dorado**. Al terminar, GitHub mostrará la URL publicada.

Si la subida desde navegador omite `.github`, puedes publicar de forma más sencilla: **Settings → Pages → Deploy from a branch → main → / (root) → Save**. Para este método bastan los nueve archivos de la aplicación: `index.html`, `styles.css`, `app.js`, `api.js`, `admin-db.js`, `domain.js`, `config.js`, `icon.svg` y `.nojekyll`. No hay instalación ni compilación.

La dirección esperada es [ruzzblue.github.io/ElDorado](https://ruzzblue.github.io/ElDorado/), pero solo estará disponible después del despliegue; todavía no se ha verificado esa publicación.

## 4 Comprobar antes del evento

1. Entra con tu nombre y la contraseña de Super dios.
2. Crea las patrullas reales desde **Control**.
3. Desde otro celular, entra con la contraseña de Dios y anota un resultado de prueba.
4. Valídalo desde el primer celular y confirma que ambos muestran los mismos puntos.
5. Anula el resultado de prueba antes del evento, indicando el motivo; quedará en la bitácora.

Si el ingreso muestra que no encuentra la función `camp_login`, falta ejecutar `schema.sql`. Si no hay juegos, falta `seed.sql`. Si dice contraseña incorrecta, revisa la consulta del paso 2. No necesitas instalar Agent Skills para usar la aplicación.
