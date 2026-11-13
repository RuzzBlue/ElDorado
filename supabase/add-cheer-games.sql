-- Añade los tres retos extra «¿Quién canta más?» inmediatamente después de
-- cada Batalla de las Bandas. Es seguro ejecutarlo más de una vez.
begin;

do $$
declare d jsonb; updated_games jsonb;
begin
  select data into d from camp_private.event where id=1 for update;

  with source as (
    select value, ordinality::integer as position
    from jsonb_array_elements(coalesce(d->'games','[]'::jsonb)) with ordinality
  ), additions(after_id, item) as (
    values
      ('bandas3', jsonb_build_object('id','barras3','name','¿Quién canta más?','phase','sabado','block','Módulo 3','time','22:20','scope','europeos','metric','higher','rules','Reto extra de Batalla de las Bandas. Elegir una única patrulla ganadora por sus barras.','bonus',false,'enabled',true)),
      ('bandas4', jsonb_build_object('id','barras4','name','¿Quién canta más?','phase','sabado','block','Módulo 4','time','22:20','scope','muiscas','metric','higher','rules','Reto extra de Batalla de las Bandas. Elegir una única patrulla ganadora por sus barras.','bonus',false,'enabled',true)),
      ('bandas6', jsonb_build_object('id','barras6','name','¿Quién canta más?','phase','domingo','block','Módulo 6','time','14:25','scope','all','metric','higher','rules','Reto extra de Batalla de las Bandas. Elegir una única patrulla ganadora por sus barras.','bonus',false,'enabled',true))
  ), all_items as (
    select position*10 as sort_order, value as item from source
    union all
    select source.position*10+1, additions.item
    from additions join source on source.value->>'id'=additions.after_id
    where not exists (select 1 from source already_added where already_added.value->>'id'=additions.item->>'id')
  )
  select jsonb_agg(item order by sort_order) into updated_games from all_items;

  update camp_private.event set data=jsonb_set(d,'{games}',coalesce(updated_games,'[]'::jsonb)) where id=1;
end $$;

commit;
