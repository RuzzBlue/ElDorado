-- Actualización no destructiva. Ejecutar una vez en SQL Editor.
-- No modifica resultados, claves ni sesiones existentes.
begin;
create table if not exists camp_private.admin_changes (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor text not null,
  action text not null,
  table_name text not null,
  reason text not null,
  before jsonb,
  after jsonb
);
alter table camp_private.admin_changes enable row level security;
revoke all on camp_private.admin_changes from public,anon,authenticated;

create or replace function public.camp_admin_catalog(p_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; items jsonb;
begin
  s=camp_private.session_for(p_token);
  if s.role<>'admin' then raise exception 'Solo Super dios puede abrir el editor de base de datos.';end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'schema',n.nspname,'name',c.relname,
    'editable',n.nspname in ('public','camp_private') and c.relname<>'admin_changes' and exists(select 1 from pg_catalog.pg_index i where i.indrelid=c.oid and i.indisprimary),
    'managed',n.nspname not in ('public','camp_private'),
    'columns',(select jsonb_agg(jsonb_build_object('name',a.attname,'type',pg_catalog.format_type(a.atttypid,a.atttypmod),'nullable',not a.attnotnull,'generated',a.attgenerated<>'' or a.attidentity<>'','default',pg_catalog.pg_get_expr(ad.adbin,ad.adrelid),'primary',exists(select 1 from pg_catalog.pg_index i where i.indrelid=c.oid and i.indisprimary and a.attnum=any(i.indkey))) order by a.attnum)
      from pg_catalog.pg_attribute a left join pg_catalog.pg_attrdef ad on ad.adrelid=a.attrelid and ad.adnum=a.attnum where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped)
  ) order by case when n.nspname='camp_private' then 0 when n.nspname='public' then 1 else 2 end,n.nspname,c.relname),'[]') into items
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where c.relkind in ('r','p') and n.nspname not like 'pg_%' and n.nspname<>'information_schema';
  return items;
end $$;

create or replace function public.camp_admin_rows(p_token text,p_schema text,p_table text,p_offset integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; oid_value oid; rows_value jsonb; count_value bigint; pk text[]; ordering text;
begin
  s=camp_private.session_for(p_token);
  if s.role<>'admin' then raise exception 'Solo Super dios puede consultar tablas internas.';end if;
  if p_schema not in ('public','camp_private') then raise exception 'Tabla gestionada por Supabase. Su contenido se consulta desde el panel de Supabase.';end if;
  select c.oid into oid_value from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname=p_schema and c.relname=p_table and c.relkind in ('r','p');
  if oid_value is null then raise exception 'Tabla no disponible.';end if;
  select array_agg(a.attname order by a.attnum) into pk from pg_catalog.pg_index i join pg_catalog.pg_attribute a on a.attrelid=i.indrelid and a.attnum=any(i.indkey) where i.indrelid=oid_value and i.indisprimary;
  select string_agg(format('%I',x),',') into ordering from unnest(pk) x;
  execute format('select count(*) from %I.%I',p_schema,p_table) into count_value;
  execute format('select coalesce(jsonb_agg(jsonb_build_object(''value'',q.v,''revision'',md5(q.v::text))),''[]'') from (select to_jsonb(t) v from %I.%I t %s limit 50 offset $1) q',p_schema,p_table,case when ordering is null then '' else 'order by '||ordering end) into rows_value using greatest(0,coalesce(p_offset,0));
  return jsonb_build_object('rows',rows_value,'total',count_value,'primary',coalesce(to_jsonb(pk),'[]'));
end $$;

create or replace function camp_private.check_event_shape(p_data jsonb) returns void
language plpgsql set search_path='' as $$
declare collection text; item jsonb; nested jsonb; match_value jsonb;
begin
  if jsonb_typeof(p_data) is distinct from 'object' then raise exception 'Los datos del evento deben ser un objeto JSON.';end if;
  foreach collection in array array['patrols','games','results','tournaments'] loop
    if jsonb_typeof(p_data->collection) is distinct from 'array' then raise exception 'El campo % debe ser una lista.',collection;end if;
    for item in select value from jsonb_array_elements(p_data->collection) loop
      if jsonb_typeof(item) is distinct from 'object' or coalesce(item->>'id','')='' then raise exception 'Cada registro de % necesita un id.',collection;end if;
    end loop;
    if exists(select 1 from jsonb_array_elements(p_data->collection) x group by x->>'id' having count(*)>1) then raise exception 'Hay ids repetidos en %.',collection;end if;
  end loop;
  if jsonb_typeof(p_data->'closed') is distinct from 'boolean' then raise exception 'closed debe ser true o false.';end if;
  for item in select value from jsonb_array_elements(p_data->'patrols') loop
    if jsonb_typeof(item->'name') is distinct from 'string' or coalesce(item->>'troop','') not in ('quezada','federmann','zaque','zipa') then raise exception 'Cada patrulla necesita nombre y tropa válidos.';end if;
  end loop;
  for item in select value from jsonb_array_elements(p_data->'games') loop
    if jsonb_typeof(item->'name') is distinct from 'string' or coalesce(item->>'phase','') not in ('viernes','sabado','domingo') or coalesce(item->>'metric','') not in ('higher','lower','jury') or jsonb_typeof(item->'enabled') is distinct from 'boolean' or jsonb_typeof(item->'bonus') is distinct from 'boolean' then raise exception 'Revisa nombre, phase, metric, enabled y bonus del juego.';end if;
  end loop;
  for item in select value from jsonb_array_elements(p_data->'results') loop
    if jsonb_typeof(item->'entries') is distinct from 'array' or coalesce(item->>'status','') not in ('validated','provisional','void') or coalesce(item->>'phase','') not in ('viernes','sabado','domingo') or jsonb_typeof(item->'updated_at') is distinct from 'string' then raise exception 'Resultado sin entries, status, phase o updated_at válidos.';end if;
    for nested in select value from jsonb_array_elements(item->'entries') loop
      if jsonb_typeof(nested->'patrol') is distinct from 'string' or jsonb_typeof(nested->'points') is distinct from 'number' or jsonb_typeof(nested->'score') is distinct from 'number' then raise exception 'Cada entrada de resultado necesita patrol, points y score válidos.';end if;
    end loop;
  end loop;
  for item in select value from jsonb_array_elements(p_data->'tournaments') loop
    if jsonb_typeof(item->'participants') is distinct from 'array' or jsonb_typeof(item->'rounds') is distinct from 'array' or jsonb_array_length(item->'rounds')=0 then raise exception 'Torneo sin participantes o rondas válidos.';end if;
    for nested in select value from jsonb_array_elements(item->'rounds') loop
      if jsonb_typeof(nested) is distinct from 'array' or jsonb_array_length(nested)=0 then raise exception 'Cada ronda del torneo debe ser una lista de encuentros.';end if;
      for match_value in select value from jsonb_array_elements(nested) loop
        if jsonb_typeof(match_value) is distinct from 'object' then raise exception 'Cada encuentro debe ser un objeto JSON.';end if;
      end loop;
    end loop;
  end loop;
end $$;
revoke all on function camp_private.check_event_shape(jsonb) from public,anon,authenticated;

create or replace function public.camp_admin_write(p_token text,p_schema text,p_table text,p_action text,p_key jsonb,p_row jsonb,p_revision text,p_reason text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; oid_value oid; old_row jsonb; new_row jsonb; pk text[]; col text; filter_sql text; set_sql text; col_sql text; select_sql text; changed_id bigint;
begin
  s=camp_private.session_for(p_token);
  if s.role<>'admin' then raise exception 'Solo Super dios puede editar la base de datos.';end if;
  if p_schema not in ('public','camp_private') or p_table='admin_changes' then raise exception 'Tabla gestionada o historial protegido.';end if;
  if p_action not in ('insert','update','delete') or coalesce(length(trim(p_reason)),0)<5 then raise exception 'Indica la operación y un motivo de al menos 5 caracteres.';end if;
  if octet_length(coalesce(p_row,'{}')::text)>2000000 then raise exception 'Registro demasiado grande.';end if;
  select c.oid into oid_value from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname=p_schema and c.relname=p_table and c.relkind in ('r','p');
  if oid_value is null then raise exception 'Tabla no disponible.';end if;
  select array_agg(a.attname order by a.attnum) into pk from pg_catalog.pg_index i join pg_catalog.pg_attribute a on a.attrelid=i.indrelid and a.attnum=any(i.indkey) where i.indrelid=oid_value and i.indisprimary;
  if pk is null then raise exception 'Esta tabla no tiene clave primaria. No se modifica para evitar afectar otras filas.';end if;
  -- Todas las operaciones de administración del evento se serializan con las del programa.
  perform 1 from camp_private.event where id=1 for update;
  if p_action<>'insert' then
    foreach col in array pk loop if not coalesce(p_key ? col,false) or p_key->col='null'::jsonb then raise exception 'Falta clave primaria %.',col;end if;end loop;
    select string_agg(format('to_jsonb(t)->%L = $1->%L',x,x),' and ') into filter_sql from unnest(pk) x;
    execute format('select to_jsonb(t) from %I.%I t where %s for update',p_schema,p_table,filter_sql) into old_row using p_key;
    if old_row is null then raise exception 'El registro ya no existe.';end if;
    if md5(old_row::text) is distinct from p_revision then raise exception 'Otro dirigente cambió el registro. Recarga la tabla antes de editar.';end if;
  end if;
  if p_schema='camp_private' and p_table='event' then
    if p_action<>'update' or p_row->>'id' is distinct from '1' then raise exception 'El evento único no se elimina ni se duplica; edita sus campos.';end if;
    perform camp_private.check_event_shape(p_row->'data');
  end if;
  if p_action<>'delete' then
    if jsonb_typeof(p_row) is distinct from 'object' then raise exception 'El registro debe ser un objeto JSON.';end if;
    for col in select jsonb_object_keys(p_row) loop
      if not exists(select 1 from pg_catalog.pg_attribute a where a.attrelid=oid_value and a.attname=col and a.attnum>0 and not a.attisdropped) then raise exception 'Campo desconocido %.',col;end if;
    end loop;
    select string_agg(format('%I = x.%I',a.attname,a.attname),','),string_agg(format('%I',a.attname),','),string_agg(format('x.%I',a.attname),',') into set_sql,col_sql,select_sql
    from pg_catalog.pg_attribute a where a.attrelid=oid_value and a.attnum>0 and not a.attisdropped and a.attgenerated='' and a.attidentity='' and p_row ? a.attname;
    if set_sql is null then raise exception 'No hay campos editables.';end if;
  end if;
  if p_action='update' then
    execute format('update %I.%I t set %s from jsonb_populate_record(null::%I.%I,$2) x where %s returning to_jsonb(t)',p_schema,p_table,set_sql,p_schema,p_table,filter_sql) into new_row using p_key,p_row;
  elsif p_action='insert' then
    execute format('insert into %I.%I (%s) select %s from jsonb_populate_record(null::%I.%I,$1) x returning to_jsonb(%I)',p_schema,p_table,col_sql,select_sql,p_schema,p_table,p_table) into new_row using p_row;
  else
    execute format('delete from %I.%I t where %s returning to_jsonb(t)',p_schema,p_table,filter_sql) into old_row using p_key;
  end if;
  insert into camp_private.admin_changes(actor,action,table_name,reason,before,after) values(s.name,p_action,format('%I.%I',p_schema,p_table),trim(p_reason),old_row,new_row) returning id into changed_id;
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,'admin_'||p_action,jsonb_build_object('table',p_schema||'.'||p_table,'reason',p_reason,'change_id',changed_id),old_row,new_row);
  return jsonb_build_object('ok',true,'row',new_row,'change_id',changed_id);
end $$;

revoke all on function public.camp_admin_catalog(text) from public;
revoke all on function public.camp_admin_rows(text,text,text,integer) from public;
revoke all on function public.camp_admin_write(text,text,text,text,jsonb,jsonb,text,text) from public;
grant execute on function public.camp_admin_catalog(text) to anon,authenticated;
grant execute on function public.camp_admin_rows(text,text,text,integer) to anon,authenticated;
grant execute on function public.camp_admin_write(text,text,text,text,jsonb,jsonb,text,text) to anon,authenticated;
commit;
