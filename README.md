# El Dorado CADIPAS

Aplicación para evaluar el campamento desde celulares. HTML, CSS y JavaScript sin compilación ni dependencias de producción. GitHub Pages sirve los archivos; Supabase guarda el evento compartido y verifica los permisos.

## Lo que incluye

- Acceso mediante nombre declarado y una de dos contraseñas compartidas: **Dios** (dirigente) y **Super dios** (administrador).
- 36 actividades precargadas a partir del programa. Talleres, cocina y programas paralelos no suman a los premios.
- Captura de resultados de dos o más patrullas, tiempos, cantidades o nota de jurado.
- Torneos de eliminación directa de 2 a 32 patrullas con sorteo, pases libres y avance de ganador.
- Clasificación de patrulla, cuatro tropas del sábado y dos alianzas del domingo.
- Validación, correcciones justificadas, anulación de resultados y torneos, desempates documentados y cierre del evento.
- Bitácora del servidor con ingresos, intentos fallidos de ingreso, salidas y todas las operaciones de modificación exitosas, incluyendo datos anteriores y posteriores del registro afectado.
- Exportación CSV de posiciones y respaldo JSON de los datos y bitácora para el administrador.
- Demostración local separada de los datos reales. Veinte patrullas ficticias solo en demo; la base real comienza sin patrullas.

## Preparar Supabase

1. Crea un proyecto en [Supabase](https://supabase.com/dashboard). Esta aplicación no necesita servicios de pago; verifica los límites y condiciones del plan disponible en tu cuenta antes del evento.
2. Abre **SQL Editor**. En un proyecto nuevo, pega y ejecuta todo `supabase/schema.sql` **una sola vez**. No es un script de reinicio: si ya existen las tablas, no vuelvas a ejecutarlo.
3. Pega y ejecuta `supabase/seed.sql`. Esto carga las actividades si el catálogo está vacío. Después ejecuta `supabase/optimize-sync.sql` para que las consultas sin cambios devuelvan solo una confirmación breve y reduzcan el consumo de datos del plan gratuito.
4. En una consulta nueva del SQL Editor, define las contraseñas. Sustituye las dos cadenas antes de ejecutar; deben ser distintas. No guardes la consulta con claves reales en GitHub:

```sql
insert into camp_private.credentials (role, password_hash) values
  ('referee', extensions.crypt('CAMBIA_POR_CLAVE_DE_DIRIGENTES', extensions.gen_salt('bf', 10))),
  ('admin', extensions.crypt('CAMBIA_POR_OTRA_CLAVE_DE_ADMIN', extensions.gen_salt('bf', 10)))
on conflict (role) do update set password_hash=excluded.password_hash;
```

5. Busca la URL del proyecto y su **publishable key** o clave **anon** en la configuración del proyecto. Colócalas en `config.js`:

```js
window.CADIPAS_CONFIG = {
  supabaseUrl: 'https://TU_PROYECTO.supabase.co',
  supabaseKey: 'sb_publishable_TU_CLAVE_PUBLICA',
  refreshSeconds: 15,
};
```

Esos dos datos son públicos por diseño. **Nunca uses `service_role`, `sb_secret_...` ni la contraseña de la base** en esta aplicación. Las contraseñas compartidas solo se comprueban dentro de Supabase y se guardan con hash bcrypt. No hay que configurar usuarios, correos ni URLs de redirección en Supabase Auth.

La aplicación llama a cuatro funciones del esquema público: `camp_login`, `camp_logout`, `camp_snapshot` y `camp_mutate`. Las tablas están en `camp_private`, sin permisos de acceso directo para clientes. No expongas ese esquema en la Data API.

Las funciones necesitan `pgcrypto` instalado en el esquema `extensions`, que es la disposición habitual de un proyecto Supabase nuevo. Si ya tienes esa extensión en otro esquema, revisa su ubicación antes de ejecutar el script.

## Publicar en GitHub Pages

**Sube el contenido de esta carpeta a la raíz del repositorio**, incluyendo `.github/workflows/pages.yml`. No subas la carpeta contenedora `eldorado` como un nivel adicional si vas a usar el flujo incluido.

1. Crea o usa un repositorio de GitHub y sube los archivos a su rama `main`.
2. En **Settings → Pages → Build and deployment → Source**, elige **GitHub Actions**.
3. En **Actions**, ejecuta **Publicar El Dorado**, o realiza un cambio en `main`.
4. El flujo ejecutará las pruebas y publicará únicamente los archivos estáticos necesarios. SQL, documentación y pruebas no se copian al sitio publicado por ese flujo.
5. Abre la URL que devuelve GitHub Pages, normalmente `https://TU_USUARIO.github.io/TU_REPOSITORIO/`.
6. Entra desde dos celulares y verifica que el segundo vea un resultado nuevo al actualizar o tras unos 15 segundos.

Todas las rutas son relativas, por lo que funciona en un subdirectorio de GitHub Pages. No necesitas dominio, servidor propio ni un proceso de compilación. Las fuentes de Google son opcionales: si no cargan, se usan las fuentes del celular.

También puedes publicar con **Deploy from a branch**, `main / (root)`. En ese caso todos los archivos del repositorio serán accesibles como estáticos; no añadas archivos con contraseñas. El flujo de Actions suministrado limita los archivos publicados.

Referencias: [GitHub Pages y fuentes de publicación](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site), [funciones de Supabase](https://supabase.com/docs/guides/database/functions), [claves públicas y protección de datos](https://supabase.com/docs/guides/database/secure-data).

## Probar en tu computadora

Con Node.js 22 o posterior:

```sh
npm start
```

Abre `http://127.0.0.1:4173`. El botón **Ver programa** abre el programa del campamento (páginas como imágenes) dentro de la aplicación; para registrar resultados, entra con tus credenciales de Supabase. No es necesario instalar paquetes. Las imágenes están en `programa/` y `programa.pdf` queda como archivo fuente, sin publicarse.

Si Supabase no está configurado, el acceso real queda deshabilitado. Después de modificar `config.js`, recarga la página. No abras el HTML haciendo doble clic: los módulos JavaScript necesitan un servidor HTTP.

```sh
npm test
```

Las pruebas cubren puntuación, empates, independencia de premios y avance de torneos de 2 a 32 participantes. Para regenerar el catálogo SQL después de modificar `domain.js`:

```sh
npm run seed
```

## Preparar el evento real

1. Entra como **Super dios** con tu nombre y tu clave de administrador.
2. En **Control**, agrega las patrullas inscritas y asígnalas a las cuatro tropas. No se precargan nombres ficticios en Supabase.
3. Revisa **Reglamento** para ajustar criterios, alcance y unidades de cada juego. Hazlo antes de registrar resultados o crear torneos.
4. Publica las reglas de puntaje para los dirigentes. La aplicación implementa la propuesta descrita abajo, no una puntuación previamente aprobada por la organización.
5. Decide las series, rotaciones y cantidad de oportunidades: Jet Lag y Fiebre del oro son simultáneos; los grupos nocturnos de seis y cuatro deben equilibrarse; confirma la capacidad del módulo 6.
6. Asigna a cada dirigente sus juegos. La aplicación permite que cualquier dirigente registre cualquier juego; no necesita una cuenta por estación.
7. Prueba acceso, registro, validación, torneo y exportación en un proyecto de ensayo antes de usar la base del evento.

### Reglas implementadas

- Solo resultados **validados** afectan las posiciones.
- **Resultado directo de una actividad:** ganador 3 puntos y una victoria oficial; cada otro participante válido 1 punto. Una serie puede contener dos o más patrullas. Igual marcador en primer lugar requiere ganador de desempate y explicación.
- **Torneo:** campeón 3 puntos y una victoria; subcampeón 2 puntos; demás participantes 1 punto. Los partidos intermedios y pases libres no dan victorias adicionales. No hay empates de eliminación directa: deben resolverse antes de avanzar.
- **Batalla de las bandas:** ganador 1 punto, demás 0; nadie recibe victoria oficial. No usa eliminación directa.
- **Mejor patrulla:** más victorias; después más puntos. Una igualdad restante se resuelve en **Control → Resolver desempates**, registrando la prueba y el ganador.
- **Sábado:** suma de los puntos de viernes y sábado por tropa; se elige líder entre Quezada y Federmann y entre Zaque y Zipa.
- **Domingo:** M5 y M6 comienzan en cero para la batalla de alianzas; se suman puntos de las patrullas europeas y de las Muiscas.
- **Mejor tropa:** líder del sábado perteneciente a la alianza ganadora del domingo. Este criterio sigue la interpretación propuesta del epílogo y debe confirmarse antes del evento.
- Una patrulla no puede tener dos resultados activos de la misma actividad. Las partidas internas pertenecen al torneo. Borrachos mojados y Alunizaje son dos actividades con dos rotaciones de participantes, no cuatro oportunidades para una misma patrulla.
- Una modificación posterior de datos competitivos invalida las decisiones manuales de desempate, para que vuelvan a comprobarse.
- Las penalizaciones se incluyen en el marcador conforme al reglamento; su motivo se documenta en observaciones. No existe una resta arbitraria de puntos globales.

Las escalas globales están fijadas para evitar que distintos evaluadores otorguen pesos distintos. Para cambiar las escalas habrá que actualizar tanto la lógica del servidor en `schema.sql` como `api.js` (demo), `domain.js` y los textos de la interfaz. No edites solo los valores del navegador.

### Jornada de evaluación

**Dios:** entra con nombre y contraseña de dirigentes, abre **Juegos**, selecciona una actividad y anota el marcador. El resultado queda **Por validar**. Un torneo avanza al confirmar cada encuentro. La pestaña **Resultados** no está disponible para este acceso: solo Super dios revisa, corrige, valida o anula.

**Super dios:** revisa resultados, valida o anula con motivo y controla la bitácora. Puede **validar varios pendientes a la vez** y **reabrir** un resultado validado o anulado, corregir el ganador y validarlo de nuevo. Una corrección de torneo se hace **anulando el torneo completo** y creando otro; los cruces antiguos permanecen registrados. No se modifica a un ganador después de que sus cruces posteriores ya se jugaron.

Después de la última actividad: valida los pendientes, termina o anula los torneos incompletos, revisa igualdad de oportunidades, resuelve empates, exporta el respaldo y cierra la clasificación. Se puede reabrir con motivo. La aplicación no sabe si se jugó una actividad no registrada: comprobar cobertura y oportunidades sigue siendo tarea de organización.

## Conectividad y límites prácticos

### Editor de base de datos de Super dios

Para añadirlo a una instalación existente, ejecuta `supabase/admin-editor.sql` en SQL Editor. Es una actualización no destructiva y puede ejecutarse nuevamente. Opcionalmente ejecuta `supabase/admin-editor-test.sql`, que prueba permisos, lectura, edición y conflictos y revierte sus datos al terminar.

En **Control → Base de datos · editar todo**, puedes editar patrullas, juegos, resultados, torneos, configuración y las tablas físicas propias de la aplicación (`camp_private` y `public`, con clave primaria). Cada fila tiene vista por campos y JSON completo, con soporte de NULL, números, booleanos y objetos anidados. Puedes crear, editar y eliminar registros, con motivo, revisión previa y control de cambios simultáneos.

Las tablas del servicio Supabase, como `auth` o `storage`, aparecen en el catálogo con sus columnas, pero se administran desde Supabase. Los campos generados por PostgreSQL y el historial `admin_changes` son de solo lectura. El registro único de `event` se edita, pero no se elimina ni duplica. Su estructura mínima se valida para que la web pueda seguir abriendo.

Las modificaciones manuales conservan todos los campos que no cambies y registran antes y después en un historial protegido. Cambiar manualmente un marcador, un cruce o una asignación no recalcula automáticamente los otros registros relacionados: puedes editarlos también cuando corresponda. Los cambios en credenciales o sesiones pueden alterar el acceso de esas sesiones. No se incluye una clave `service_role` ni un ejecutor libre de SQL en el navegador.

- La sincronización consulta Supabase cada 15 segundos y mediante **Actualizar**. Con `optimize-sync.sql`, solo descarga el evento si hubo operaciones nuevas. No se usa Realtime ni hace falta activar publicaciones de base de datos.
- Se requiere conexión para guardar datos reales. No hay cola offline ni service worker. Si se pierde la señal, conserva el formulario abierto y registra respaldo en papel; reintenta cuando vuelva la conexión.
- Si una solicitud vence por tiempo, primero actualiza: podría haberse guardado en el servidor. Las escrituras son transaccionales y el servidor impide resultados duplicados por actividad y patrulla.
- Los cambios simultáneos del mismo resultado o torneo usan una versión para impedir sobrescrituras silenciosas. El evento se modifica bajo bloqueo transaccional, adecuado para el volumen de un campamento.
- Una sesión dura tres días. Salir elimina su token del servidor. El token queda en `sessionStorage` de esa pestaña; no se guarda la contraseña.
- Las contraseñas son compartidas y el nombre es declarado: esto identifica el nombre usado al registrar, pero no prueba la identidad real de la persona. La bitácora cubre operaciones de la aplicación; no pretende auditar cambios directos del propietario desde el SQL Editor ni cada lectura o clic.
- No hay límite de intentos de contraseña dedicado. Usa claves que no sean obvias y comparte el enlace con el equipo. El esquema es deliberadamente sencillo para el fin de semana.
- El respaldo JSON contiene datos y registros, pero no contraseñas ni sesiones. No hay importación de respaldo desde la interfaz. Conserva además el proyecto de Supabase hasta concluir el informe.
- La aplicación muestra como provisionales las posiciones mientras el evento siga abierto. Un empate no se convierte en ganador por orden alfabético.

### Borrar puntajes para pruebas

En **Control**, el botón **Borrar puntajes** permite a Super dios reiniciar rápidamente la aplicación entre pruebas. Elimina todos los resultados, torneos y desempates; conserva patrullas, grupos, juegos, configuración y bitácora. Si el evento estaba cerrado, queda abierto.

La operación pide un motivo y exige escribir **DELETE** para confirmar. También queda registrada en la bitácora con la cantidad de resultados y torneos eliminados. El servidor comprueba nuevamente que la sesión sea de Super dios y que la confirmación sea correcta.

Para una instalación existente, ejecuta `supabase/clear-results.sql` una vez en SQL Editor. Las instalaciones nuevas ya incluyen la función en `schema.sql`.

### Reabrir resultados

Solo Super dios puede reabrir un resultado **validado** o **anulado**. El botón **Reabrir** está en **Ganadores registrados**, pide un motivo y deja el resultado en **Por validar**. Después se puede usar **Corregir** para cambiar el ganador, **Validar** para confirmarlo o **Anular** de nuevo.

La operación incrementa la versión del resultado, impide sobrescribir cambios simultáneos, limpia los desempates manuales y queda en la bitácora con el estado anterior. Si el evento está cerrado, primero hay que reabrirlo desde **Control**. Los resultados de torneo no se reabren desde aquí: el torneo completo se anula y se crea otro.

Para una instalación existente, ejecuta `supabase/reopen-results.sql` una vez en SQL Editor. Las instalaciones nuevas ya incluyen la función en `schema.sql`.

### Validación masiva

En **Ganadores registrados**, junto a los filtros, el botón **Validar todo** abre una revisión de todos los resultados **Por validar**. La lista es desplazable y cada fila muestra la actividad, el módulo, el día, el tipo, el ganador y los puntos que se asignarían a cada patrulla.

Se puede filtrar por **módulo, día, tipo, alcance de tropa, patrulla afectada, grupo afectado** o con una búsqueda personalizada. Al cambiar de filtro se limpia la selección, de modo que solo se puedan validar los resultados que están a la vista; el resumen indica cuántos resultados y puntos se van a asignar. **Seleccionar visibles** marca la lista filtrada y **Limpiar** quita toda la selección.

Antes de confirmar se escribe el **nombre de quien valida**. Ese nombre se guarda como comentario `Validado por …` en cada resultado y queda en la bitácora. La validación es conjunta: si otro dirigente modificó uno de los seleccionados, no se valida ninguno y se pide actualizar. Solo Super dios puede abrir esta pantalla y el servidor vuelve a comprobar el rol.

Para una instalación existente, ejecuta `supabase/bulk-validate.sql` una vez en SQL Editor. Las instalaciones nuevas ya incluyen la función en `schema.sql`.

## Cambiar contraseñas o revocar accesos

Para rotarlas, vuelve a ejecutar la consulta de credenciales con nuevas claves. Las sesiones abiertas siguen siendo válidas hasta su vencimiento. Para revocarlas en conjunto, ejecuta en SQL Editor:

```sql
delete from camp_private.sessions;
```

Esto cierra los accesos abiertos sin eliminar resultados ni bitácora. Hazlo cuando termine el fin de semana si ya no habrá ediciones.

## Comprobación antes de publicar

- Ejecutar `npm test`.
- Abrir la demo en un celular y comprobar que los controles no se cortan.
- Ejecutar `supabase/smoke-test.sql` en un proyecto de ensayo: verifica claves, permisos, auditoría y puntuación; todos sus cambios se revierten con `rollback`.
- Verificar con dos teléfonos que un resultado se comparte y que otro dirigente no puede validar ni consultar la bitácora de administración.
- Registrar y validar al menos una actividad de cada tipo, incluyendo un torneo con cantidad impar de patrullas.
- Descargar respaldo JSON y posiciones CSV.

La publicación real requiere tu proyecto Supabase y repositorio GitHub. La demo no constituye una conexión ni un despliegue verificado.
