-- Ajustes manuales auditables de puntaje para Super dios.
begin;

create or replace function public.camp_adjust_points(p_token text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; d jsonb; item jsonb; target_type text; target_id text; amount integer; label text;
begin
  s=camp_private.session_for(p_token);
  if s.role<>'admin' then raise exception 'Solo Super dios tiene este permiso.';end if;
  target_type=p_payload->>'target_type';target_id=p_payload->>'target';
  if target_type not in ('patrol','troop','alliance') or coalesce(length(trim(p_payload->>'reason')),0)<5 then raise exception 'Revisa el ajuste y su motivo.';end if;
  begin amount=(p_payload->>'amount')::integer;exception when others then raise exception 'El ajuste debe ser un número entero.';end;
  if amount=0 or abs(amount)>1000 then raise exception 'El ajuste debe estar entre -1000 y 1000, sin cero.';end if;
  select data into d from camp_private.event where id=1 for update;
  if coalesce((d->>'closed')::boolean,false) then raise exception 'El evento está cerrado.';end if;
  if target_type='patrol' then
    select value->>'name' into label from jsonb_array_elements(d->'patrols') where value->>'id'=target_id;
  elsif target_type='troop' then
    if target_id not in ('quezada','federmann','zaque','zipa') then raise exception 'Tropa inválida.';end if;
    label=target_id;
  else
    if target_id not in ('europeos','muiscas') then raise exception 'Alianza inválida.';end if;
    label=target_id;
  end if;
  if label is null then raise exception 'Destino del ajuste no existe.';end if;
  item=jsonb_build_object('id',encode(extensions.gen_random_bytes(16),'hex'),'game','adjustment-'||target_type,'phase','adjustment','label','Ajuste de '||case target_type when 'patrol' then 'patrulla' when 'troop' then 'tropa' else 'alianza' end,'entries','[]'::jsonb,'winner',null,'official_win',false,'status','validated','version',1,'kind','adjustment','adjustment_target_type',target_type,'adjustment_target',target_id,'adjustment_amount',amount,'created_by',s.name,'updated_at',now(),'notes',trim(p_payload->>'reason'));
  d=jsonb_set(d,'{results}',coalesce(d->'results','[]'::jsonb)||jsonb_build_array(item));
  d=jsonb_set(d,'{decisions}','{}');
  update camp_private.event set data=d where id=1;
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,'adjust_points',p_payload,null,item);
  return '{"ok":true}';
end $$;
revoke all on function public.camp_adjust_points(text,jsonb) from public;
grant execute on function public.camp_adjust_points(text,jsonb) to anon,authenticated;
commit;
