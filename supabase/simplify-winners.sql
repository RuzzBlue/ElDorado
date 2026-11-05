-- Actualización para una instalación que ya existe.
-- No borra patrullas ni resultados. Ejecutar una sola vez en SQL Editor.
begin;

create or replace function public.camp_record_winner(p_token text,p_game text,p_winner text,p_id text,p_version integer,p_reason text default '') returns jsonb
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

revoke all on function public.camp_record_winner(text,text,text,text,integer,text) from public;
grant execute on function public.camp_record_winner(text,text,text,text,integer,text) to anon,authenticated;
commit;
