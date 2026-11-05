-- Actualización: gestión de juegos para Super dios.
-- Ejecutar después de simplify-winners.sql. No borra datos.
begin;

create or replace function public.camp_manage_game(p_token text,p_game jsonb) returns jsonb
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

revoke all on function public.camp_manage_game(text,jsonb) from public;
grant execute on function public.camp_manage_game(text,jsonb) to anon,authenticated;
commit;

