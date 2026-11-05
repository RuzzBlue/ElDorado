-- Actualización para una instalación que ya existe.
-- Permite que Super dios valide varios resultados pendientes a la vez.
-- El nombre de quien valida queda como comentario en cada resultado.
-- Ejecutar una vez en SQL Editor.
begin;

create or replace function public.camp_validate_results(p_token text,p_items jsonb,p_actor text) returns jsonb
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

revoke all on function public.camp_validate_results(text,jsonb,text) from public;
grant execute on function public.camp_validate_results(text,jsonb,text) to anon,authenticated;

commit;
