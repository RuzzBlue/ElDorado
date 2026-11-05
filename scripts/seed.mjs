import {writeFile} from 'node:fs/promises';
import {GAMES} from '../domain.js';
const json=JSON.stringify(GAMES).replaceAll("'","''");
await writeFile(new URL('../supabase/seed.sql',import.meta.url),`-- Ejecutar después de schema.sql. No cambia patrullas ni resultados.\n-- Ejecutar únicamente antes de iniciar el evento.\nupdate camp_private.event set data=jsonb_set(data,'{games}','${json}'::jsonb) where id=1 and jsonb_array_length(data->'games')=0;\n`);
console.log(`Seed preparado con ${GAMES.length} actividades.`);
