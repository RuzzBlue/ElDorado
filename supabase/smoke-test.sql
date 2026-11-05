-- Ejecutar en SQL Editor DESPUÉS de schema.sql y seed.sql.
-- Es una prueba transaccional: no conserva claves, sesiones, datos ni logs de prueba.
-- No depende de las contraseñas reales. Todas las modificaciones se revierten.
begin;
do $$
declare a jsonb; f jsonb; d jsonb; r jsonb; t jsonb; atoken text; ftoken text; failed boolean=false; g jsonb;
begin
  update camp_private.event set data=jsonb_build_object('games',data->'games','patrols','[]'::jsonb,'results','[]'::jsonb,'tournaments','[]'::jsonb,'closed',false) where id=1;
  insert into camp_private.credentials(role,password_hash) values
    ('admin',extensions.crypt('test-admin-only',extensions.gen_salt('bf',4))),
    ('referee',extensions.crypt('test-referee-only',extensions.gen_salt('bf',4)))
  on conflict(role) do update set password_hash=excluded.password_hash;
  a=public.camp_login('Admin prueba','test-admin-only');f=public.camp_login('Dirigente prueba','test-referee-only');
  atoken=a->>'token';ftoken=f->>'token';
  if a->>'role'<>'admin' or f->>'role'<>'referee' then raise exception 'Fallo de roles';end if;
  a=public.camp_login('Intruso prueba','wrong');if a->>'error' is null then raise exception 'Aceptó contraseña incorrecta';end if;
  perform public.camp_mutate(atoken,'upsert_patrol','{"id":"qa-a","name":"Patrulla QA A","group":"QA","troop":"quezada","members":6}');
  perform public.camp_mutate(atoken,'upsert_patrol','{"id":"qa-b","name":"Patrulla QA B","group":"QA","troop":"federmann","members":6}');
  perform public.camp_mutate(atoken,'upsert_patrol','{"id":"qa-c","name":"Patrulla QA C","group":"QA","troop":"quezada","members":6}');
  begin
    perform public.camp_mutate(ftoken,'upsert_patrol','{"id":"qa-x","name":"No autorizado","group":"QA","troop":"zipa","members":6}');
  exception when others then failed=true;end;
  if not failed then raise exception 'Dirigente obtuvo permisos de administrador';end if;
  perform public.camp_mutate(ftoken,'save_result','{"id":"qa-r","game":"retos","label":"QA","entries":[{"patrol":"qa-a","score":12,"points":999},{"patrol":"qa-b","score":8,"points":999}]}');
  d=public.camp_snapshot(atoken);select value into r from jsonb_array_elements(d->'results') where value->>'id'='qa-r';
  if r->>'winner'<>'qa-a' or r->'entries'->0->>'points'<>'3' or r->'entries'->1->>'points'<>'1' or r->>'status'<>'provisional' then raise exception 'Puntuación calculada incorrectamente';end if;
  failed=false;
  begin perform public.camp_mutate(ftoken,'result_status','{"id":"qa-r","version":1,"status":"validated","reason":"Prueba permisos"}');exception when others then failed=true;end;
  if not failed then raise exception 'Dirigente pudo validar';end if;
  perform public.camp_mutate(atoken,'result_status','{"id":"qa-r","version":1,"status":"validated","reason":"Marcador verificado QA"}');
  failed=false;
  begin perform public.camp_mutate(atoken,'result_status','{"id":"qa-r","version":1,"status":"void","reason":"Versión antigua QA"}');exception when others then failed=true;end;
  if not failed then raise exception 'Aceptó versión antigua';end if;
  failed=false;
  begin perform public.camp_mutate(ftoken,'save_result','{"id":"qa-dup","game":"retos","label":"Duplicado","entries":[{"patrol":"qa-a","score":9},{"patrol":"qa-b","score":5}]}');exception when others then failed=true;end;
  if not failed then raise exception 'Aceptó patrullas duplicadas por actividad';end if;
  perform public.camp_mutate(ftoken,'create_tournament','{"id":"qa-t","game":"imprenta","name":"Torneo QA","participants":["qa-a","qa-b","qa-c"]}');
  -- Tres participantes: A recibe pase libre; B contra C; luego final A contra B.
  perform public.camp_mutate(ftoken,'score_match','{"id":"qa-t","round":0,"index":1,"a":3,"b":1,"version":1}');
  perform public.camp_mutate(ftoken,'score_match','{"id":"qa-t","round":1,"index":0,"a":2,"b":4,"version":2}');
  d=public.camp_snapshot(atoken);select value into r from jsonb_array_elements(d->'results') where value->>'id'='qa-t';
  if r->>'winner'<>'qa-b' or r->>'kind'<>'tournament' or jsonb_array_length(r->'entries')<>3 then raise exception 'Fallo del torneo';end if;
  perform public.camp_mutate(atoken,'cancel_tournament','{"id":"qa-t","version":3,"reason":"Corrección completa de prueba"}');
  d=public.camp_snapshot(atoken);select value into r from jsonb_array_elements(d->'results') where value->>'id'='qa-t';if r->>'status'<>'void' then raise exception 'Anulación no aplicada';end if;
  d=public.camp_snapshot(ftoken);if jsonb_array_length(d->'logs')<>0 then raise exception 'Filtró logs al dirigente';end if;
  d=public.camp_snapshot(atoken);if jsonb_array_length(d->'logs')<8 then raise exception 'Faltan operaciones en bitácora';end if;
  perform public.camp_logout(ftoken);
  failed=false;begin perform public.camp_snapshot(ftoken);exception when others then failed=true;end;
  if not failed then raise exception 'Sesión no revocada';end if;
  raise notice 'OK: claves, roles, puntuación del servidor, duplicados, versiones, torneo, anulación, logs y cierre de sesión.';
end $$;
rollback;
