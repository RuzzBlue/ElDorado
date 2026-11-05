-- Cocina del sábado: ejecutar después de las migraciones anteriores.
begin;

create or replace function public.camp_kitchen_mutate(p_token text,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s camp_private.sessions; d jsonb; old jsonb; row jsonb; ix integer; p text; values jsonb; k text; n numeric; scores jsonb; best numeric; leaders text[]; winner text; result jsonb;
begin
  s=camp_private.session_for(p_token);
  select data into d from camp_private.event where id=1 for update;
  if coalesce((d->>'closed')::boolean,false) then raise exception 'El evento está cerrado.';end if;
  if p_action='kitchen_score' then
    p=p_payload->>'patrol'; values=p_payload->'values';
    if not exists(select 1 from jsonb_array_elements(d->'patrols') x where x->>'id'=p) or jsonb_typeof(values)<>'object' or exists(select 1 from unnest(array['presentation','complexity','flavor','teamwork','cleanliness']) k where not (values ? k)) then raise exception 'Calificación inválida.';end if;
    foreach k in array array['presentation','complexity','flavor','teamwork','cleanliness'] loop n=(values->>k)::numeric;if n<1 or n>5 or n*2<>trunc(n*2) then raise exception 'Cada criterio debe estar entre 1 y 5, en medias estrellas.';end if;end loop;
    select value,ordinality::integer-1 into old,ix from jsonb_array_elements(coalesce(d->'kitchen_scores','[]')) with ordinality where value->>'patrol'=p;
    row=jsonb_build_object('patrol',p,'values',values,'created_by',s.name,'updated_at',now());
    if old is null then d=jsonb_set(d,'{kitchen_scores}',coalesce(d->'kitchen_scores','[]')||jsonb_build_array(row));else d=jsonb_set(d,array['kitchen_scores',ix::text],row);end if;
  elsif p_action='kitchen_finalize' then
    if s.role<>'admin' then raise exception 'Solo Super dios tiene este permiso.';end if;
    if exists(select 1 from jsonb_array_elements(d->'results') r where r->>'game'='cocina-sabado' and r->>'status'<>'void') then raise exception 'Cocina ya tiene ganador.';end if;
    scores=coalesce(d->'kitchen_scores','[]');if jsonb_array_length(scores)<>(select count(*) from jsonb_array_elements(d->'patrols')) then raise exception 'Falta calificar patrullas.';end if;
    select max((value->'values'->>'presentation')::numeric+(value->'values'->>'complexity')::numeric+(value->'values'->>'flavor')::numeric+(value->'values'->>'teamwork')::numeric+(value->'values'->>'cleanliness')::numeric) into best from jsonb_array_elements(scores);
    select array_agg(value->>'patrol') into leaders from jsonb_array_elements(scores) where (value->'values'->>'presentation')::numeric+(value->'values'->>'complexity')::numeric+(value->'values'->>'flavor')::numeric+(value->'values'->>'teamwork')::numeric+(value->'values'->>'cleanliness')::numeric=best;
    winner=coalesce(p_payload->>'winner',leaders[1]);if not winner=any(leaders) or (array_length(leaders,1)>1 and coalesce(length(trim(p_payload->>'reason')),0)<5) then raise exception 'Resuelve el empate y registra el motivo.';end if;
    result=jsonb_build_object('id',encode(extensions.gen_random_bytes(16),'hex'),'game','cocina-sabado','phase','sabado','label','Reto de cocina · sábado','entries',jsonb_build_array(jsonb_build_object('patrol',winner,'points',1)),'winner',winner,'official_win',true,'status','provisional','version',1,'kind','activity','created_by',s.name,'updated_at',now(),'notes',coalesce(p_payload->>'reason',''));
    d=jsonb_set(d,'{results}',(d->'results')||jsonb_build_array(result));row=result;
  else raise exception 'Acción de cocina inválida.';end if;
  update camp_private.event set data=d where id=1;
  insert into camp_private.audit(actor,role,action,payload,before,after) values(s.name,s.role,p_action,p_payload,old,row);
  return '{"ok":true}';
end $$;
revoke all on function public.camp_kitchen_mutate(text,text,jsonb) from public;
grant execute on function public.camp_kitchen_mutate(text,text,jsonb) to anon,authenticated;
commit;

