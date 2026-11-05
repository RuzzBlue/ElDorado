-- Actualización para una instalación que ya existe.
-- Permite que Super dios reabra un resultado validado o anulado,
-- lo corrija y lo vuelva a validar. Ejecutar una vez en SQL Editor.
begin;

create or replace function public.camp_reopen_result(p_token text,p_id text,p_version integer,p_reason text) returns jsonb
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

revoke all on function public.camp_reopen_result(text,text,integer,text) from public;
grant execute on function public.camp_reopen_result(text,text,integer,text) to anon,authenticated;

commit;
