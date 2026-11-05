-- Ejecutar después de schema.sql. Se puede volver a ejecutar.
-- Evita descargar todo el evento cada 15 segundos cuando no hubo cambios.
create or replace function public.camp_snapshot(p_token text,p_since text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; revision text;
begin
  s=camp_private.session_for(p_token);
  select coalesce(max(id),0)::text into revision from camp_private.audit;
  if p_since=revision then return jsonb_build_object('unchanged',true,'_revision',revision);end if;
  return public.camp_snapshot(p_token)||jsonb_build_object('_revision',revision);
end $$;
revoke all on function public.camp_snapshot(text,text) from public;
grant execute on function public.camp_snapshot(text,text) to anon,authenticated;
