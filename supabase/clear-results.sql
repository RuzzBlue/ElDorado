-- Actualización para una instalación que ya existe.
-- Habilita el botón "Borrar puntajes" para Super dios.
-- No borra patrullas, grupos, juegos ni bitácora. Ejecutar una vez en SQL Editor.
begin;

create or replace function public.camp_clear_results(p_token text,p_confirm text,p_reason text) returns jsonb
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

revoke all on function public.camp_clear_results(text,text,text) from public;
grant execute on function public.camp_clear_results(text,text,text) to anon,authenticated;

commit;
