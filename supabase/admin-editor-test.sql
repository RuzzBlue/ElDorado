-- Ejecutar después de admin-editor.sql. Todo se revierte al terminar.
begin;
do $$
declare a jsonb; f jsonb; d jsonb; rows_value jsonb; original jsonb; changed jsonb; revision text; failed boolean;
begin
  insert into camp_private.credentials(role,password_hash) values
    ('admin',extensions.crypt('editor-test-admin',extensions.gen_salt('bf',4))),
    ('referee',extensions.crypt('editor-test-referee',extensions.gen_salt('bf',4)))
  on conflict(role) do update set password_hash=excluded.password_hash;
  a=public.camp_login('Prueba editor admin','editor-test-admin');f=public.camp_login('Prueba editor dirigente','editor-test-referee');
  d=public.camp_admin_catalog(a->>'token');
  if not exists(select 1 from jsonb_array_elements(d) x where x->>'schema'='camp_private' and x->>'name'='event') then raise exception 'Falta la tabla event en catálogo';end if;
  failed=false;begin perform public.camp_admin_catalog(f->>'token');exception when others then failed=true;end;
  if not failed then raise exception 'Un dirigente pudo consultar el catálogo';end if;
  rows_value=public.camp_admin_rows(a->>'token','camp_private','event',0);
  original=rows_value->'rows'->0->'value';revision=rows_value->'rows'->0->>'revision';
  changed=jsonb_set(original,'{data,editor_test}','"Cambio de prueba"');
  perform public.camp_admin_write(a->>'token','camp_private','event','update','{"id":1}',changed,revision,'Prueba de actualización del editor');
  rows_value=public.camp_admin_rows(a->>'token','camp_private','event',0);
  if rows_value->'rows'->0->'value'->'data'->>'editor_test'<>'Cambio de prueba' then raise exception 'El cambio no se guardó';end if;
  failed=false;begin perform public.camp_admin_write(a->>'token','camp_private','event','update','{"id":1}',original,revision,'Prueba de versión antigua');exception when others then failed=true;end;
  if not failed then raise exception 'Se sobrescribió una versión antigua';end if;
  failed=false;begin perform public.camp_admin_rows(f->>'token','camp_private','credentials',0);exception when others then failed=true;end;
  if not failed then raise exception 'Un dirigente pudo leer credenciales';end if;
  failed=false;begin perform public.camp_admin_write(a->>'token','auth','users','delete','{}',null,'','Prueba de acceso gestionado');exception when others then failed=true;end;
  if not failed then raise exception 'Se permitió escribir en auth';end if;
  failed=false;begin perform public.camp_admin_write(a->>'token','camp_private','event','delete','{"id":1}',null,rows_value->'rows'->0->>'revision','Prueba de eliminación de evento');exception when others then failed=true;end;
  if not failed then raise exception 'Se pudo eliminar el evento único';end if;
  rows_value=public.camp_admin_rows(a->>'token','camp_private','admin_changes',0);
  if (rows_value->>'total')::int<1 then raise exception 'No se guardó el historial';end if;
  raise notice 'OK: catálogo, lectura, autorización, edición, conflictos, protección de servicios e historial.';
end $$;
rollback;
