-- Ejecutar UNA VEZ en el SQL Editor de un proyecto Supabase nuevo.
-- Después ejecutar seed.sql y configurar las dos claves siguiendo README.md.
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists camp_private;
revoke all on schema camp_private from public, anon, authenticated;

create table camp_private.credentials (
  role text primary key check(role in ('admin','referee')),
  password_hash text not null
);
create table camp_private.sessions (
  token_hash text primary key,
  name text not null,
  role text not null check(role in ('admin','referee')),
  expires_at timestamptz not null default now()+interval '3 days'
);
create table camp_private.event (
  id integer primary key check(id=1),
  data jsonb not null
);
insert into camp_private.event values(1,'{"patrols":[],"games":[],"results":[],"tournaments":[],"closed":false}');
create table camp_private.audit (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor text not null,
  role text not null,
  action text not null,
  payload jsonb,
  before jsonb,
  after jsonb
);
alter table camp_private.credentials enable row level security;
alter table camp_private.sessions enable row level security;
alter table camp_private.event enable row level security;
alter table camp_private.audit enable row level security;
revoke all on all tables in schema camp_private from public, anon, authenticated;

create function camp_private.session_for(p_token text) returns camp_private.sessions
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions;
begin
  select * into s from camp_private.sessions where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and expires_at>now();
  if s.token_hash is null then raise exception 'Sesión vencida. Sal y vuelve a entrar.';end if;
  return s;
end $$;

-- Registro simplificado: cada juego entrega una única victoria y un punto.
create function public.camp_record_winner(p_token text,p_game text,p_winner text,p_id text,p_version integer,p_reason text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; d jsonb; g jsonb; patrol jsonb; old jsonb; item jsonb; ix integer;
begin
  s=camp_private.session_for(p_token);
  select data into d from camp_private.event where id=1 for update;
  if coalesce((d->>'closed')::boolean,false) then raise exception 'El evento está cerrado.';end if;
  select value into g from jsonb_array_elements(d->'games') where value->>'id'=p_game and coalesce((value->>'enabled')::boolean,true);
  if g is null or coalesce(p_id,'')='' then raise exception 'Juego o registro inválido.';end if;
  select value into patrol from jsonb_array_elements(d->'patrols') where value->>'id'=p_winner;
  if patrol is null or (g->>'scope'='europeos' and patrol->>'troop' not in ('quezada','federmann')) or (g->>'scope'='muiscas' and patrol->>'troop' not in ('zaque','zipa')) then raise exception 'La patrulla no corresponde a este juego.';end if;
  select value,ordinality::int-1 into old,ix from jsonb_array_elements(d->'results') with ordinality where value->>'id'=p_id;
  if old is null then
    if exists(select 1 from jsonb_array_elements(d->'results') x where x->>'game'=p_game and x->>'status'<>'void') then raise exception 'Este juego ya tiene un ganador registrado.';end if;
  else
    if s.role<>'admin' or old->>'kind'='tournament' or old->>'status'='void' or old->>'game'<>p_game then raise exception 'Solo Super dios puede corregir este ganador.';end if;
    if (old->>'version')::integer is distinct from p_version or coalesce(length(trim(p_reason)),0)<5 then raise exception 'El resultado cambió o falta el motivo de corrección.';end if;
  end if;
  item=jsonb_build_object('id',p_id,'game',p_game,'phase',g->>'phase','label',g->>'name','entries',jsonb_build_array(jsonb_build_object('patrol',p_winner,'points',1)),'winner',p_winner,'official_win',true,'status',coalesce(old->>'status','provisional'),'version',coalesce((old->>'version')::integer,0)+1,'kind','activity','created_by',coalesce(old->>'created_by',s.name),'updated_at',now(),'notes','','reason',left(coalesce(p_reason,''),500));
  if old is null then d=jsonb_set(d,'{results}',(d->'results')||jsonb_build_array(item));else d=jsonb_set(d,array['results',ix::text],item);end if;
  d=jsonb_set(d,'{decisions}','{}');
  update camp_private.event set data=d where id=1;
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,'record_winner',jsonb_build_object('game',p_game,'winner',p_winner,'id',p_id),old,item);
  return '{"ok":true}';
end $$;

create function public.camp_manage_game(p_token text,p_game jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; d jsonb; old jsonb; item jsonb; ix integer;
begin
  s=camp_private.session_for(p_token);
  if s.role<>'admin' then raise exception 'Solo Super dios tiene este permiso.';end if;
  if jsonb_typeof(p_game)<>'object' or coalesce(length(trim(p_game->>'id')),0)=0 or coalesce(length(trim(p_game->>'name')),0) not between 2 and 100 or coalesce(p_game->>'phase','') not in ('viernes','sabado','domingo') or coalesce(p_game->>'block','') not in ('Masivos','Módulo 1','Módulo 2','Módulo 3','Módulo 4','Módulo 5','Módulo 6') or coalesce(p_game->>'scope','') not in ('all','europeos','muiscas') or coalesce(length(p_game->>'time'),0)>40 or coalesce(length(p_game->>'rules'),0)>2000 or jsonb_typeof(p_game->'enabled') is distinct from 'boolean' then raise exception 'Revisa los datos del juego.';end if;
  select data into d from camp_private.event where id=1 for update;
  if coalesce((d->>'closed')::boolean,false) then raise exception 'El evento está cerrado.';end if;
  select value,ordinality::integer-1 into old,ix from jsonb_array_elements(d->'games') with ordinality where value->>'id'=p_game->>'id';
  if old is not null and old->>'scope'<>p_game->>'scope' and exists(select 1 from jsonb_array_elements(d->'results') r where r->>'game'=old->>'id' and r->>'status'<>'void') then raise exception 'No puedes cambiar participantes de un juego con resultados activos.';end if;
  item=jsonb_build_object('id',p_game->>'id','name',trim(p_game->>'name'),'phase',p_game->>'phase','block',p_game->>'block','time',trim(p_game->>'time'),'scope',p_game->>'scope','metric',coalesce(old->>'metric','higher'),'rules',coalesce(p_game->>'rules',''),'bonus',false,'enabled',(p_game->>'enabled')::boolean);
  if old is null then d=jsonb_set(d,'{games}',(d->'games')||jsonb_build_array(item));else d=jsonb_set(d,array['games',ix::text],item);end if;
  d=jsonb_set(d,'{decisions}','{}');
  update camp_private.event set data=d where id=1;
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,'manage_game',p_game,old,item);
  return '{"ok":true}';
end $$;

-- Reinicio rápido para pruebas: borra resultados, torneos y desempates.
-- Conserva patrullas, grupos, juegos, configuración y bitácora.
create function public.camp_clear_results(p_token text,p_confirm text,p_reason text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; d jsonb; before_data jsonb; after_data jsonb;
begin
  s=camp_private.session_for(p_token);
  if s.role<>'admin' then raise exception 'Solo Super dios tiene este permiso.';end if;
  if coalesce(p_confirm,'')<>'DELETE' then raise exception 'Escribe DELETE para confirmar.';end if;
  if coalesce(length(trim(p_reason)),0)<5 then raise exception 'Indica el motivo del reinicio.';end if;
  select data into d from camp_private.event where id=1 for update;
  before_data=jsonb_build_object('results',coalesce(jsonb_array_length(d->'results'),0),'tournaments',coalesce(jsonb_array_length(d->'tournaments'),0),'closed',coalesce((d->>'closed')::boolean,false));
  d=d||jsonb_build_object('results','[]'::jsonb,'tournaments','[]'::jsonb,'decisions','{}'::jsonb,'closed',false);
  update camp_private.event set data=d where id=1;
  after_data=jsonb_build_object('results',0,'tournaments',0,'closed',false);
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,'clear_results',jsonb_build_object('reason',trim(p_reason)),before_data,after_data);
  return jsonb_build_object('ok',true,'cleared',before_data);
end $$;

-- Super dios puede reabrir un resultado validado o anulado para corregirlo.
-- Deja el resultado en provisional; después se corrige el ganador y se valida.
create function public.camp_reopen_result(p_token text,p_id text,p_version integer,p_reason text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; d jsonb; old jsonb; item jsonb; ix integer;
begin
  s=camp_private.session_for(p_token);
  if s.role<>'admin' then raise exception 'Solo Super dios tiene este permiso.';end if;
  if coalesce(length(trim(p_reason)),0)<5 then raise exception 'Indica el motivo para reabrir.';end if;
  select data into d from camp_private.event where id=1 for update;
  if coalesce((d->>'closed')::boolean,false) then raise exception 'El evento está cerrado. Reábrelo antes de corregir resultados.';end if;
  select value,ordinality::int-1 into old,ix from jsonb_array_elements(d->'results') with ordinality where value->>'id'=p_id;
  if old is null then raise exception 'El resultado no existe.';end if;
  if old->>'kind'='tournament' then raise exception 'Los torneos se corrigen desde la vista del torneo.';end if;
  if coalesce(old->>'status','') not in ('validated','void') then raise exception 'Solo se pueden reabrir resultados validados o anulados.';end if;
  if (old->>'version')::integer is distinct from p_version then raise exception 'El resultado cambió. Actualiza antes de reabrir.';end if;
  item=old||jsonb_build_object('status','provisional','version',(old->>'version')::integer+1,'reason',left(trim(p_reason),500),'updated_at',now());
  d=jsonb_set(d,array['results',ix::text],item);
  d=jsonb_set(d,'{decisions}','{}');
  update camp_private.event set data=d where id=1;
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,'reopen_result',jsonb_build_object('id',p_id,'reason',trim(p_reason)),old,item);
  return '{"ok":true}';
end $$;

-- Super dios valida varios resultados pendientes en una sola operación.
-- El comentario "Validado por ..." queda en cada resultado y en la bitácora.
create function public.camp_validate_results(p_token text,p_items jsonb,p_actor text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; d jsonb; old jsonb; item jsonb; it jsonb; ix integer; n integer;
  actor text; ids jsonb='[]'; before_items jsonb='[]'; after_items jsonb='[]';
begin
  s=camp_private.session_for(p_token);
  if s.role<>'admin' then raise exception 'Solo Super dios tiene este permiso.';end if;
  actor=trim(coalesce(p_actor,''));
  if length(actor) not between 2 and 60 then raise exception 'Escribe el nombre de quien valida.';end if;
  if jsonb_typeof(p_items) is distinct from 'array' then raise exception 'Selecciona al menos un resultado.';end if;
  n=jsonb_array_length(p_items);
  if n<1 or n>200 then raise exception 'Selecciona entre 1 y 200 resultados.';end if;
  select data into d from camp_private.event where id=1 for update;
  if coalesce((d->>'closed')::boolean,false) then raise exception 'El evento está cerrado.';end if;
  for it in select value from jsonb_array_elements(p_items) loop
    select value,ordinality::int-1 into old,ix from jsonb_array_elements(d->'results') with ordinality where value->>'id'=it->>'id';
    if old is null then raise exception 'El resultado no existe.';end if;
    if old->>'status'<>'provisional' then raise exception 'El resultado % ya no está pendiente de validación.',old->>'id';end if;
    if (old->>'version')::integer is distinct from (it->>'version')::integer then raise exception 'El resultado % cambió. Actualiza antes de validar.',old->>'id';end if;
    item=old||jsonb_build_object('status','validated','version',(old->>'version')::integer+1,'reason',left('Validado por '||actor,500),'updated_at',now());
    d=jsonb_set(d,array['results',ix::text],item);
    ids=ids||jsonb_build_array(old->>'id');
    before_items=before_items||jsonb_build_array(old);
    after_items=after_items||jsonb_build_array(item);
  end loop;
  d=jsonb_set(d,'{decisions}','{}');
  update camp_private.event set data=d where id=1;
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,'validate_results',jsonb_build_object('actor',actor,'ids',ids,'count',n),before_items,after_items);
  return jsonb_build_object('ok',true,'validated',n);
end $$;
revoke all on function camp_private.session_for(text) from public,anon,authenticated;

create function public.camp_login(p_name text,p_password text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r text; token text;
begin
  if length(trim(p_name)) not between 2 and 60 or length(p_password)>200 then raise exception 'Nombre o contraseña inválidos.';end if;
  select role into r from camp_private.credentials where password_hash=extensions.crypt(p_password,password_hash) order by role limit 1;
  if r is null then
    insert into camp_private.audit(actor,role,action) values(left(trim(p_name),60),'denied','login_failed');
    return jsonb_build_object('error','Contraseña incorrecta.');
  end if;
  token=encode(extensions.gen_random_bytes(32),'hex');
  delete from camp_private.sessions where expires_at<now();
  insert into camp_private.sessions(token_hash,name,role) values(encode(extensions.digest(token,'sha256'),'hex'),trim(p_name),r);
  insert into camp_private.audit(actor,role,action) values(trim(p_name),r,'login');
  return jsonb_build_object('token',token,'name',trim(p_name),'role',r);
end $$;

create function public.camp_logout(p_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions;
begin
  s=camp_private.session_for(p_token);
  insert into camp_private.audit(actor,role,action) values(s.name,s.role,'logout');
  delete from camp_private.sessions where token_hash=s.token_hash;
  return '{"ok":true}';
end $$;

create function public.camp_snapshot(p_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; d jsonb; logs jsonb;
begin
  s=camp_private.session_for(p_token);
  select data into d from camp_private.event where id=1;
  if s.role='admin' then
    select coalesce(jsonb_agg(to_jsonb(a) order by a.id desc),'[]') into logs from camp_private.audit a;
  else logs='[]';end if;
  return d||jsonb_build_object('logs',logs);
end $$;

create function public.camp_mutate(p_token text,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  s camp_private.sessions; d jsonb; g jsonb; old jsonb; item jsonb; r jsonb; t jsonb; m jsonb;
  entry jsonb; entries jsonb='[]'; ids text[]='{}'; winner text; pid text; tid text;
  best numeric; val numeric; ties integer=0; points integer; ix integer; ri integer; mi integer;
  size integer=2; n integer; j integer; rounds jsonb='[]'; round_data jsonb; participants jsonb;
  before_item jsonb; after_item jsonb; idx integer; existing boolean; final jsonb;
begin
  s=camp_private.session_for(p_token);
  if p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'Datos inválidos.';end if;
  if octet_length(p_payload::text)>100000 then raise exception 'Solicitud demasiado grande.';end if;
  select data into d from camp_private.event where id=1 for update;
  if (d->>'closed')::boolean and p_action<>'set_closed' then raise exception 'El evento está cerrado.';end if;
  if p_action in ('upsert_patrol','save_game','set_closed','result_status','set_decision','cancel_tournament') and s.role<>'admin' then raise exception 'Solo Super dios tiene este permiso.';end if;

  if p_action='upsert_patrol' then
    if coalesce(length(trim(p_payload->>'name')),0) not between 2 and 60 or coalesce(length(trim(p_payload->>'group')),0) not between 1 and 100
      or coalesce(p_payload->>'troop','') not in ('quezada','federmann','zaque','zipa') or coalesce((p_payload->>'members')::int,0) not between 1 and 30
      or coalesce(p_payload->>'id','')='' then raise exception 'Revisa los datos de la patrulla.';end if;
    select value,ordinality::int-1 into old,ix from jsonb_array_elements(d->'patrols') with ordinality where value->>'id'=p_payload->>'id';
    if old is not null and old->>'troop'<>p_payload->>'troop' and (
      exists(select 1 from jsonb_array_elements(d->'results') x,jsonb_array_elements(x->'entries') e where e->>'patrol'=old->>'id') or
      exists(select 1 from jsonb_array_elements(d->'tournaments') x where (x->'participants') ? (old->>'id'))
    ) then raise exception 'No puedes cambiar de tropa una patrulla con resultados o torneo.';end if;
    if exists(select 1 from jsonb_array_elements(d->'patrols') x where lower(x->>'name')=lower(trim(p_payload->>'name')) and x->>'id'<>p_payload->>'id') then raise exception 'Ya existe una patrulla con ese nombre.';end if;
    item=jsonb_build_object('id',p_payload->>'id','name',trim(p_payload->>'name'),'group',trim(p_payload->>'group'),'troop',p_payload->>'troop','members',(p_payload->>'members')::int);
    before_item=old;after_item=item;
    if old is null then d=jsonb_set(d,'{patrols}',(d->'patrols')||jsonb_build_array(item));else d=jsonb_set(d,array['patrols',ix::text],item);end if;

  elsif p_action='save_game' then
    select value,ordinality::int-1 into old,ix from jsonb_array_elements(d->'games') with ordinality where value->>'id'=p_payload->>'id';
    if old is null or (p_payload->>'metric') not in ('higher','lower','jury') or (p_payload->>'scope') not in ('all','europeos','muiscas') or length(p_payload->>'rules') not between 1 and 2000 then raise exception 'Configuración de juego inválida.';end if;
    if (old->>'metric'<>p_payload->>'metric' or old->>'scope'<>p_payload->>'scope') and (
      exists(select 1 from jsonb_array_elements(d->'results') x where x->>'game'=old->>'id') or exists(select 1 from jsonb_array_elements(d->'tournaments') x where x->>'game'=old->>'id')
    ) then raise exception 'El juego ya tiene resultados o un torneo. No puedes cambiar el criterio o alcance.';end if;
    item=old||jsonb_build_object('metric',p_payload->>'metric','scope',p_payload->>'scope','rules',p_payload->>'rules','enabled',coalesce((p_payload->>'enabled')::boolean,true));
    before_item=old;after_item=item;d=jsonb_set(d,array['games',ix::text],item);

  elsif p_action='save_result' then
    select value into g from jsonb_array_elements(d->'games') where value->>'id'=p_payload->>'game' and (value->>'enabled')::boolean;
    if g is null then raise exception 'Juego no disponible.';end if;
    select value,ordinality::int-1 into old,ix from jsonb_array_elements(d->'results') with ordinality where value->>'id'=p_payload->>'id';
    if old is not null then
      if old->>'kind'='tournament' or old->>'status'='void' or old->>'game'<>g->>'id' then raise exception 'Este resultado no puede editarse.';end if;
      if (old->>'version')::int is distinct from (p_payload->>'version')::int then raise exception 'Otro dirigente actualizó el resultado. Actualiza antes de editar.';end if;
      if old->>'status'='validated' and s.role<>'admin' then raise exception 'Solo Super dios corrige resultados validados.';end if;
      if coalesce(length(trim(p_payload->>'reason')),0)<5 then raise exception 'Indica el motivo de corrección.';end if;
    end if;
    if coalesce(p_payload->>'id','')='' or coalesce(length(trim(p_payload->>'label')),0) not between 1 and 80 or jsonb_typeof(p_payload->'entries') is distinct from 'array' or jsonb_array_length(p_payload->'entries') not between 2 and 32 then raise exception 'Revisa las patrullas y la serie.';end if;
    for entry in select value from jsonb_array_elements(p_payload->'entries') loop
      pid=entry->>'patrol'; val=(entry->>'score')::numeric;
      if val is null or val<0 or val>1000000 or (g->>'metric'='jury' and val>100) or pid=any(ids) then raise exception 'Marcador inválido o patrulla repetida.';end if;
      select value into item from jsonb_array_elements(d->'patrols') where value->>'id'=pid;
      if item is null or (g->>'scope'='europeos' and item->>'troop' not in ('quezada','federmann')) or (g->>'scope'='muiscas' and item->>'troop' not in ('zaque','zipa')) then raise exception 'Patrulla fuera del alcance de este juego.';end if;
      if exists(select 1 from jsonb_array_elements(d->'results') x,jsonb_array_elements(x->'entries') e where x->>'id'<>p_payload->>'id' and x->>'game'=g->>'id' and x->>'status'<>'void' and e->>'patrol'=pid)
        or exists(select 1 from jsonb_array_elements(d->'tournaments') x where x->>'game'=g->>'id' and not coalesce((x->>'cancelled')::boolean,false) and (x->'participants') ? pid)
      then raise exception 'La patrulla ya tiene un resultado o torneo en esta actividad.';end if;
      ids=array_append(ids,pid);
      if best is null or (g->>'metric'='lower' and val<best) or (g->>'metric'<>'lower' and val>best) then best=val;winner=pid;ties=1;elsif val=best then ties=ties+1;end if;
    end loop;
    if ties>1 then
      winner=p_payload->>'winner';
      if coalesce(winner,'')='' or coalesce(length(trim(p_payload->>'notes')),0)<5 or not exists(select 1 from jsonb_array_elements(p_payload->'entries') e where e->>'patrol'=winner and (e->>'score')::numeric=best) then raise exception 'Registra ganador y explicación del desempate.';end if;
    elsif coalesce(p_payload->>'winner','')<>'' and p_payload->>'winner'<>winner then raise exception 'El ganador no coincide con el marcador.';end if;
    for entry in select value from jsonb_array_elements(p_payload->'entries') loop
      points=case when (g->>'bonus')::boolean then case when entry->>'patrol'=winner then 1 else 0 end else case when entry->>'patrol'=winner then 3 else 1 end end;
      entries=entries||jsonb_build_array(jsonb_build_object('patrol',entry->>'patrol','score',(entry->>'score')::numeric,'points',points));
    end loop;
    r=jsonb_build_object('id',p_payload->>'id','game',g->>'id','phase',g->>'phase','label',trim(p_payload->>'label'),'entries',entries,'winner',winner,'official_win',not (g->>'bonus')::boolean,'status',coalesce(old->>'status','provisional'),'version',coalesce((old->>'version')::int,0)+1,'kind','activity','created_by',coalesce(old->>'created_by',s.name),'updated_at',now(),'notes',left(coalesce(p_payload->>'notes',''),1000),'reason',left(coalesce(p_payload->>'reason',''),500));
    before_item=old;after_item=r;
    if old is null then d=jsonb_set(d,'{results}',(d->'results')||jsonb_build_array(r));else d=jsonb_set(d,array['results',ix::text],r);end if;

  elsif p_action='result_status' then
    select value,ordinality::int-1 into old,ix from jsonb_array_elements(d->'results') with ordinality where value->>'id'=p_payload->>'id';
    if old is null or old->>'status'='void' or (p_payload->>'status') not in ('validated','void') or coalesce(length(trim(p_payload->>'reason')),0)<5 then raise exception 'Cambio de estado inválido.';end if;
    if (old->>'version')::int is distinct from (p_payload->>'version')::int then raise exception 'El resultado cambió. Actualiza antes de validar.';end if;
    item=old||jsonb_build_object('status',p_payload->>'status','version',(old->>'version')::int+1,'reason',p_payload->>'reason','updated_at',now());
    before_item=old;after_item=item;d=jsonb_set(d,array['results',ix::text],item);

  elsif p_action='create_tournament' then
    select value into g from jsonb_array_elements(d->'games') where value->>'id'=p_payload->>'game' and (value->>'enabled')::boolean;
    participants=p_payload->'participants';
    if g is null or (g->>'bonus')::boolean or jsonb_typeof(participants) is distinct from 'array' or jsonb_array_length(participants) not between 2 and 32 or coalesce(length(p_payload->>'name'),0) not between 1 and 80 or coalesce(p_payload->>'id','')='' then raise exception 'Torneo inválido; bandas no usa eliminación directa.';end if;
    if exists(select 1 from jsonb_array_elements(d->'tournaments') x where x->>'id'=p_payload->>'id' or (x->>'game'=g->>'id' and not coalesce((x->>'cancelled')::boolean,false))) then raise exception 'Ya existe un torneo para este juego.';end if;
    for pid in select jsonb_array_elements_text(participants) loop
      select value into item from jsonb_array_elements(d->'patrols') where value->>'id'=pid;
      if item is null or pid=any(ids) or (g->>'scope'='europeos' and item->>'troop' not in ('quezada','federmann')) or (g->>'scope'='muiscas' and item->>'troop' not in ('zaque','zipa')) then raise exception 'Patrulla inválida o repetida.';end if;
      if exists(select 1 from jsonb_array_elements(d->'results') x,jsonb_array_elements(x->'entries') e where x->>'game'=g->>'id' and x->>'status'<>'void' and e->>'patrol'=pid) then raise exception 'Una patrulla ya tiene resultado en este juego.';end if;
      ids=array_append(ids,pid);
    end loop;
    n=jsonb_array_length(participants);while size<n loop size=size*2;end loop;
    round_data='[]';
    for j in 0..(size/2-1) loop
      pid=participants->>j;tid=participants->>(size-1-j);
      round_data=round_data||jsonb_build_array(jsonb_build_object('a',pid,'b',tid,'winner',case when tid is null then pid else null end,'scoreA',null,'scoreB',null,'bye',tid is null));
    end loop;
    rounds=rounds||jsonb_build_array(round_data);n=size/4;
    while n>=1 loop
      round_data='[]';for j in 1..n loop round_data=round_data||jsonb_build_array(jsonb_build_object('a',null,'b',null,'winner',null,'scoreA',null,'scoreB',null,'bye',false));end loop;
      rounds=rounds||jsonb_build_array(round_data);n=n/2;
    end loop;
    if size>2 then
      for j in 0..(size/2-1) loop
        m=rounds->0->j;
        if (m->>'bye')::boolean then rounds=jsonb_set(rounds,array['1',(j/2)::text,case when j%2=0 then 'a' else 'b' end],m->'winner');end if;
      end loop;
    end if;
    t=jsonb_build_object('id',p_payload->>'id','game',g->>'id','name',p_payload->>'name','participants',participants,'rounds',rounds,'version',1);
    after_item=t;d=jsonb_set(d,'{tournaments}',(d->'tournaments')||jsonb_build_array(t));

  elsif p_action='score_match' then
    select value,ordinality::int-1 into t,ix from jsonb_array_elements(d->'tournaments') with ordinality where value->>'id'=p_payload->>'id';
    if t is null or coalesce((t->>'cancelled')::boolean,false) or (t->>'version')::int is distinct from (p_payload->>'version')::int then raise exception 'El torneo cambió. Actualiza antes de anotar.';end if;
    before_item=t;ri=(p_payload->>'round')::int;mi=(p_payload->>'index')::int;
    if ri is null or mi is null or ri<0 or mi<0 then raise exception 'Encuentro inválido.';end if;
    m=t->'rounds'->ri->mi;
    if m is null or m->>'a' is null or m->>'b' is null or m->>'winner' is not null then raise exception 'El encuentro no está disponible.';end if;
    select value into g from jsonb_array_elements(d->'games') where value->>'id'=t->>'game';
    val=(p_payload->>'a')::numeric;best=(p_payload->>'b')::numeric;
    if val is null or best is null or val<0 or best<0 or val>1000000 or best>1000000 or val=best or (g->>'metric'='jury' and (val>100 or best>100)) then raise exception 'Marcador inválido o empate. Resuelve el desempate.';end if;
    winner=case when (g->>'metric'='lower' and val<best) or (g->>'metric'<>'lower' and val>best) then m->>'a' else m->>'b' end;
    m=m||jsonb_build_object('scoreA',val,'scoreB',best,'winner',winner);
    t=jsonb_set(t,array['rounds',ri::text,mi::text],m);
    if ri+1<jsonb_array_length(t->'rounds') then t=jsonb_set(t,array['rounds',(ri+1)::text,(mi/2)::text,case when mi%2=0 then 'a' else 'b' end],to_jsonb(winner));end if;
    t=t||jsonb_build_object('version',(t->>'version')::int+1);
    final=t->'rounds'->(jsonb_array_length(t->'rounds')-1)->0;
    if final->>'winner' is not null then
      entries='[]';for pid in select jsonb_array_elements_text(t->'participants') loop
        points=case when pid=final->>'winner' then 3 when pid in (final->>'a',final->>'b') then 2 else 1 end;
        entries=entries||jsonb_build_array(jsonb_build_object('patrol',pid,'score',0,'points',points));
      end loop;
      r=jsonb_build_object('id',t->>'id','game',g->>'id','phase',g->>'phase','label',t->>'name','entries',entries,'winner',final->>'winner','official_win',true,'status','provisional','version',1,'kind','tournament','created_by',s.name,'updated_at',now());
      d=jsonb_set(d,'{results}',(d->'results')||jsonb_build_array(r));
    end if;
    after_item=t;d=jsonb_set(d,array['tournaments',ix::text],t);

  elsif p_action='cancel_tournament' then
    select value,ordinality::int-1 into t,ix from jsonb_array_elements(d->'tournaments') with ordinality where value->>'id'=p_payload->>'id';
    if t is null or coalesce((t->>'cancelled')::boolean,false) or (t->>'version')::int is distinct from (p_payload->>'version')::int or coalesce(length(trim(p_payload->>'reason')),0)<10 then raise exception 'Torneo inválido, actualizado o sin motivo.';end if;
    before_item=t;t=t||jsonb_build_object('cancelled',true,'version',(t->>'version')::int+1);after_item=t;
    d=jsonb_set(d,array['tournaments',ix::text],t);
    select value,ordinality::int-1 into r,idx from jsonb_array_elements(d->'results') with ordinality where value->>'id'=t->>'id';
    if r is not null then d=jsonb_set(d,array['results',idx::text],r||jsonb_build_object('status','void','reason',p_payload->>'reason','version',(r->>'version')::int+1,'updated_at',now()));end if;

  elsif p_action='set_decision' then
    tid=p_payload->>'type';pid=p_payload->>'winner';
    if tid not in ('patrol','alliance','europeos','muiscas') or coalesce(length(trim(p_payload->>'reason')),0)<10 then raise exception 'Desempate inválido.';end if;
    -- Calcula candidatos con los mismos puntos y victorias que el primer puesto.
    if tid='patrol' then
      with totals as (
        select p->>'id' id,
          count(*) filter(where rr->>'winner'=p->>'id' and (rr->>'official_win')::boolean) wins,
          coalesce(sum((e->>'points')::numeric),0) pts
        from jsonb_array_elements(d->'patrols') p
        left join jsonb_array_elements(d->'results') rr on rr->>'status'='validated'
        left join jsonb_array_elements(rr->'entries') e on e->>'patrol'=p->>'id'
        group by p->>'id'
      ), ranked as (select *,dense_rank() over(order by wins desc,pts desc) place from totals)
      select array_agg(id) into ids from ranked where place=1;
    else
      with totals as (
        select p->>'troop' troop_id,
        case when p->>'troop' in ('quezada','federmann') then 'europeos' else 'muiscas' end alliance_id,
        coalesce(sum((e->>'points')::numeric) filter(where rr->>'phase'='domingo'),0) sunday,
        coalesce(sum((e->>'points')::numeric) filter(where rr->>'phase'<>'domingo'),0) saturday
        from jsonb_array_elements(d->'patrols') p
        left join jsonb_array_elements(d->'results') rr on rr->>'status'='validated'
        left join jsonb_array_elements(rr->'entries') e on e->>'patrol'=p->>'id'
        group by p->>'troop'
      ), combined as (
        select case when tid='alliance' then alliance_id else troop_id end id,
        sum(case when tid='alliance' then sunday else saturday end) pts
        from totals where tid='alliance' or alliance_id=tid group by 1
      ), ranked as (select *,dense_rank() over(order by pts desc) place from combined)
      select array_agg(id) into ids from ranked where place=1;
    end if;
    if coalesce(array_length(ids,1),0)<2 or not coalesce(pid=any(ids),false) then raise exception 'No existe ese empate en el primer puesto.';end if;
    before_item=d->'decisions'->tid;after_item=jsonb_build_object('winner',pid,'reason',p_payload->>'reason');
    d=jsonb_set(d,'{decisions}',coalesce(d->'decisions','{}')||jsonb_build_object(tid,after_item));

  elsif p_action='set_closed' then
    if coalesce(length(trim(p_payload->>'reason')),0)<5 or jsonb_typeof(p_payload->'closed') is distinct from 'boolean' then raise exception 'Indica un motivo.';end if;
    if (p_payload->>'closed')::boolean then
      if not exists(select 1 from jsonb_array_elements(d->'results') x where x->>'status'='validated') then raise exception 'No hay resultados validados.';end if;
      if exists(select 1 from jsonb_array_elements(d->'results') x where x->>'status'='provisional') or exists(select 1 from jsonb_array_elements(d->'tournaments') x where not coalesce((x->>'cancelled')::boolean,false) and x->'rounds'->(jsonb_array_length(x->'rounds')-1)->0->>'winner' is null) then raise exception 'Resuelve resultados pendientes y torneos antes de cerrar.';end if;
    end if;
    before_item=d->'closed';after_item=p_payload->'closed';d=jsonb_set(d,'{closed}',after_item);
  else raise exception 'Acción desconocida.';
  end if;
  if p_action not in ('set_decision','set_closed') then d=jsonb_set(d,'{decisions}','{}');end if;
  update camp_private.event set data=d where id=1;
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,p_action,p_payload,before_item,after_item);
  return '{"ok":true}';
end $$;

revoke all on function public.camp_login(text,text) from public;
revoke all on function public.camp_logout(text) from public;
revoke all on function public.camp_snapshot(text) from public;
revoke all on function public.camp_mutate(text,text,jsonb) from public;
revoke all on function public.camp_record_winner(text,text,text,text,integer,text) from public;
revoke all on function public.camp_manage_game(text,jsonb) from public;
revoke all on function public.camp_clear_results(text,text,text) from public;
revoke all on function public.camp_reopen_result(text,text,integer,text) from public;
revoke all on function public.camp_validate_results(text,jsonb,text) from public;
grant execute on function public.camp_login(text,text) to anon,authenticated;
grant execute on function public.camp_logout(text) to anon,authenticated;
grant execute on function public.camp_snapshot(text) to anon,authenticated;
grant execute on function public.camp_mutate(text,text,jsonb) to anon,authenticated;
grant execute on function public.camp_record_winner(text,text,text,text,integer,text) to anon,authenticated;
grant execute on function public.camp_manage_game(text,jsonb) to anon,authenticated;
grant execute on function public.camp_clear_results(text,text,text) to anon,authenticated;
grant execute on function public.camp_reopen_result(text,text,integer,text) to anon,authenticated;
grant execute on function public.camp_validate_results(text,jsonb,text) to anon,authenticated;
commit;
