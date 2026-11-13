import {demoState,rankEntries,allocate,makeBracket,scoreBracket,eligible,summary} from './domain.js';
const config=window.CADIPAS_CONFIG||{};
export const configured=!!(config.supabaseUrl&&config.supabaseKey);
let session=JSON.parse(sessionStorage.getItem('cadipas-session')||'null');
let demo=false;
let remoteCache=null,incremental=true;
const demoKey='cadipas-demo-v1';
export const getSession=()=>session;
export const isDemo=()=>demo;
export const forget=()=>{session=null;demo=false;remoteCache=null;incremental=true;sessionStorage.removeItem('cadipas-session');};
async function rpc(name,args){
  const controller=new AbortController();const timeout=setTimeout(()=>controller.abort(),18000);
  try{const response=await fetch(`${config.supabaseUrl.replace(/\/$/,'')}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:config.supabaseKey,'Content-Type':'application/json'},body:JSON.stringify(args),signal:controller.signal});
    const body=await response.json();if(!response.ok||body?.error)throw Error(body.error||body.message||'No se pudo completar la operación.');return body;
  }catch(e){if(e.name==='AbortError')throw Error('Sin respuesta. Actualiza antes de reintentar para comprobar si se guardó.');throw e;}finally{clearTimeout(timeout);}
}
export async function login(name,password){
  if(!configured)throw Error('Primero conecta Supabase en config.js o entra a la demostración.');
  session=await rpc('camp_login',{p_name:name,p_password:password});sessionStorage.setItem('cadipas-session',JSON.stringify(session));return session;
}
export async function checkConnection(){
  if(!configured)throw Error('Falta completar config.js.');
  try{await rpc('camp_snapshot',{p_token:'connection-check-no-session'});}catch(e){
    if(e.message.includes('Sesión vencida'))return true;
    if(e.message.includes('camp_snapshot')||e.message.includes('schema cache'))throw Error('Supabase responde, pero falta instalar la base. Ejecuta schema.sql y seed.sql en SQL Editor.');
    throw e;
  }
  return true;
}
export function startDemo(){demo=true;session={role:'admin',name:'Explorador de prueba',token:'demo'};if(!localStorage.getItem(demoKey))localStorage.setItem(demoKey,JSON.stringify(demoState()));}
export async function snapshot(){
  if(demo)return JSON.parse(localStorage.getItem(demoKey));
  let data;
  if(incremental){try{data=await rpc('camp_snapshot',{p_token:session.token,p_since:remoteCache?._revision||''});}
    catch(e){if(e.message.includes('schema cache')||e.message.includes('Could not find the function'))incremental=false;else throw e;}}
  if(!incremental)data=await rpc('camp_snapshot',{p_token:session.token});
  if(data.unchanged&&remoteCache)return remoteCache;
  remoteCache=data;return data;
}
export async function logout(){if(!demo&&session)await rpc('camp_logout',{p_token:session.token});forget();}
export async function adminCatalog(){
  if(!demo)return rpc('camp_admin_catalog',{p_token:session.token});
  return ['event','credentials','sessions','audit','admin_changes'].map(name=>({schema:'camp_private',name,editable:name!=='admin_changes',managed:false,columns:[]}));
}
const demoTables=()=>JSON.parse(localStorage.getItem('cadipas-demo-tables')||'{"credentials":[],"sessions":[],"admin_changes":[]}');
export async function adminRows(schema,table,offset=0){
  if(!demo)return rpc('camp_admin_rows',{p_token:session.token,p_schema:schema,p_table:table,p_offset:offset});
  const s=await snapshot();const tables=demoTables();const values=table==='event'?[{id:1,data:Object.fromEntries(Object.entries(s).filter(([key])=>key!=='logs'))}]:table==='audit'?s.logs:tables[table]||[];
  return {rows:values.slice(offset,offset+50).map(value=>({value,revision:JSON.stringify(value)})),total:values.length,primary:[table==='credentials'?'role':table==='sessions'?'token_hash':'id']};
}
export async function adminWrite({schema,table,action,key,row,revision,reason}){
  if(!demo){const result=await rpc('camp_admin_write',{p_token:session.token,p_schema:schema,p_table:table,p_action:action,p_key:key,p_row:row,p_revision:revision,p_reason:reason});remoteCache=null;return result;}
  if(getSession()?.role!=='admin')throw Error('Solo Super dios.');
  const s=await snapshot(),tables=demoTables();let values=table==='event'?[{id:1,data:Object.fromEntries(Object.entries(s).filter(([k])=>k!=='logs'))}]:table==='audit'?s.logs:tables[table]||[];
  const index=values.findIndex(v=>Object.entries(key||{}).every(([k,value])=>v[k]===value));
  const old=action==='insert'?null:values[index];
  if(action!=='insert'&&(!old||JSON.stringify(old)!==revision))throw Error('El registro cambió. Recarga antes de editar.');
  if(table==='admin_changes')throw Error('Historial protegido.');
  if(table==='event'&&(action!=='update'||row.id!==1))throw Error('El evento no se elimina ni duplica.');
  if(action==='delete')values.splice(index,1);else if(action==='insert')values.push(row);else values[index]=row;
  const log={id:crypto.randomUUID(),actor:getSession().name,role:'admin',action:'admin_'+action,at:new Date().toISOString(),payload:{table:schema+'.'+table,reason},before:old,after:action==='delete'?null:row};
  if(table==='event')localStorage.setItem(demoKey,JSON.stringify({...row.data,logs:[log,...s.logs]}));else{if(table==='audit')s.logs=values;else tables[table]=values;s.logs.unshift(log);localStorage.setItem(demoKey,JSON.stringify(s));}
  tables.admin_changes.unshift(log);localStorage.setItem('cadipas-demo-tables',JSON.stringify(tables));return {ok:true};
}
async function recordWinner(payload){
  if(!demo)return rpc('camp_record_winner',{p_token:session.token,p_game:payload.game,p_winner:payload.winner,p_id:payload.id,p_version:payload.version||0,p_reason:payload.reason||''});
  return mutate('save_winner',payload);
}
async function manageGame(payload){
  if(!demo)return rpc('camp_manage_game',{p_token:session.token,p_game:payload});
  return mutate('save_game',payload);
}
async function kitchenMutate(action,payload){
  if(!demo)return rpc('camp_kitchen_mutate',{p_token:session.token,p_action:action,p_payload:payload});
  return mutate(action,payload);
}
export async function mutate(action,payload){
  if(action==='clear_results'&&!demo)return rpc('camp_clear_results',{p_token:session.token,p_confirm:payload.confirm,p_reason:payload.reason});
  if(action==='validate_results'&&!demo)return rpc('camp_validate_results',{p_token:session.token,p_items:payload.items,p_actor:payload.actor});
  if(action==='reopen_result'&&!demo)return rpc('camp_reopen_result',{p_token:session.token,p_id:payload.id,p_version:payload.version,p_reason:payload.reason});
  if(action==='save_winner'&&!demo)return recordWinner(payload);
  if(action==='save_game'&&!demo)return manageGame(payload);
  if(action.startsWith('kitchen_')&&!demo)return kitchenMutate(action,payload);
  if(!demo)return rpc('camp_mutate',{p_token:session.token,p_action:action,p_payload:payload});
  const s=await snapshot();const before=structuredClone(s);const admin=session.role==='admin';
  if(s.closed&&!['set_closed','clear_results'].includes(action))throw Error('El evento está cerrado.');
  if(action==='set_decision'){s.decisions={...(s.decisions||{}),[payload.type]:{winner:payload.winner,reason:payload.reason}};}
  else if(action==='cancel_tournament'){const t=s.tournaments.find(t=>t.id===payload.id);t.cancelled=true;t.version++;const r=s.results.find(r=>r.id===t.id);if(r){r.status='void';r.version++;}}
  else if(action==='upsert_patrol'){const i=s.patrols.findIndex(p=>p.id===payload.id);const old=s.patrols[i];if(old&&old.troop!==payload.troop&&(s.results.some(r=>r.entries.some(e=>e.patrol===old.id))||s.tournaments.some(t=>t.participants.includes(old.id))))throw Error('No puedes cambiar la tropa de una patrulla con resultados o torneo.');if(s.patrols.some(p=>p.id!==payload.id&&p.name.toLowerCase()===payload.name.toLowerCase()))throw Error('El nombre ya existe.');if(i<0)s.patrols.push(payload);else s.patrols[i]=payload;}
  else if(action==='save_game'){const i=s.games.findIndex(g=>g.id===payload.id);if(i<0)s.games.push({...payload,metric:'higher',bonus:false});else s.games[i]={...s.games[i],...payload,metric:s.games[i].metric||'higher',bonus:false};}
  else if(action==='kitchen_score'){const values=payload.values||{},meal=payload.meal;if(!['almuerzo','cena','desayuno'].includes(meal))throw Error('Elige la comida a calificar.');if(['presentation','complexity','flavor','teamwork','cleanliness'].some(k=>!Number.isFinite(values[k])||values[k]<1||values[k]>5||Math.round(values[k]*2)!==values[k]*2))throw Error('Cada criterio debe estar entre 1 y 5, en medias estrellas.');const row={patrol:payload.patrol,meal,values,created_by:session.name,updated_at:new Date().toISOString()};const i=(s.kitchen_scores||[]).findIndex(x=>x.patrol===row.patrol&&(x.meal||'almuerzo')===meal);if(i<0)(s.kitchen_scores||=[]).push(row);else s.kitchen_scores[i]=row;}
  else if(action==='kitchen_finalize'){if(!admin)throw Error('Solo Super dios.');const meal=payload.meal;if(!['almuerzo','cena','desayuno'].includes(meal))throw Error('Elige la comida a declarar.');const scores=(s.kitchen_scores||[]).filter(x=>(x.meal||'almuerzo')===meal);if(scores.length<s.patrols.length)throw Error('Falta calificar patrullas.');const total=x=>Object.values(x.values).reduce((n,v)=>n+v,0),best=Math.max(...scores.map(total)),leaders=scores.filter(x=>total(x)===best);if(leaders.length>1&&!payload.winner)throw Error('Hay empate: resuélvelo en campo y selecciona al ganador.');const winner=payload.winner||leaders[0].patrol;if(!leaders.some(x=>x.patrol===winner)&&leaders.length>1)throw Error('El ganador debe ser una patrulla empatada.');if(s.results.some(r=>r.game===`cocina-${meal}`&&r.status!=='void'))throw Error('Esta comida ya tiene ganador.');const label={almuerzo:'Almuerzo',cena:'Cena',desayuno:'Desayuno'}[meal];s.results.push({id:crypto.randomUUID(),game:`cocina-${meal}`,phase:'sabado',label:`Reto de cocina · ${label}`,entries:[{patrol:winner,points:1}],winner,official_win:true,status:'provisional',version:1,kind:'activity',created_by:session.name,updated_at:new Date().toISOString(),notes:payload.reason||''});}
  else if(action==='set_closed'){const x=summary(s);if(payload.closed&&(!s.results.some(r=>r.status==='validated')||s.results.some(r=>r.status==='provisional')||s.tournaments.some(t=>!t.cancelled&&!t.rounds.at(-1)[0].winner)||!x.bestTroop||!x.patrolWinner))throw Error('Resuelve pendientes, torneos y desempates antes de cerrar.');s.closed=payload.closed;}
  else if(action==='clear_results'){
    if(session.role!=='admin')throw Error('Solo Super dios tiene este permiso.');
    if(payload.confirm!=='DELETE'||String(payload.reason||'').trim().length<5)throw Error('Escribe DELETE e indica el motivo para confirmar.');
    s.results=[];s.tournaments=[];s.kitchen_scores=[];s.decisions={};s.closed=false;
  }else if(action==='create_tournament'){
    if(new Set(payload.participants).size!==payload.participants.length)throw Error('Patrullas repetidas.');
    if(s.tournaments.some(t=>t.game===payload.game&&!t.cancelled))throw Error('Ya existe un torneo para este juego.');
    const g=s.games.find(g=>g.id===payload.game);if(g.bonus)throw Error('Bandas no usa eliminación directa.');
    if(s.results.some(r=>r.game===g.id&&r.status!=='void'&&r.entries.some(e=>payload.participants.includes(e.patrol))))throw Error('Una patrulla ya tiene resultado en este juego.');
    s.tournaments.push({...payload,rounds:makeBracket(payload.participants),version:1});
  }else if(action==='score_match'){
    const t=s.tournaments.find(t=>t.id===payload.id);if(t.cancelled||t.version!==payload.version)throw Error('Otro dirigente actualizó este torneo. Actualiza.');
    const g=s.games.find(g=>g.id===t.game);scoreBracket(t,payload.round,payload.index,payload.a,payload.b,g.metric);t.version++;
    const final=t.rounds.at(-1)[0];if(final.winner){const entries=t.participants.map(p=>({patrol:p,score:0,points:p===final.winner?3:[final.a,final.b].includes(p)?2:1}));s.results.push({id:t.id,game:g.id,phase:g.phase,label:t.name,entries,winner:final.winner,official_win:!g.bonus,status:'provisional',version:1,kind:'tournament',created_by:session.name,updated_at:new Date().toISOString()});}
  }else if(action==='validate_results'){
    if(session.role!=='admin')throw Error('Solo Super dios tiene este permiso.');
    const actor=String(payload.actor||'').trim();
    if(actor.length<2||actor.length>60)throw Error('Escribe el nombre de quien valida.');
    if(!Array.isArray(payload.items)||payload.items.length<1||payload.items.length>200)throw Error('Selecciona entre 1 y 200 resultados.');
    const targets=payload.items.map(item=>{
      const r=s.results.find(r=>r.id===item.id);
      if(!r)throw Error('El resultado no existe.');
      if(r.status!=='provisional')throw Error('El resultado ya no está pendiente de validación.');
      if(r.version!==item.version)throw Error('El resultado cambió. Actualiza antes de validar.');
      return r;
    });
    for(const r of targets){r.status='validated';r.version++;r.reason=`Validado por ${actor}`;r.updated_at=new Date().toISOString();}
  }else if(action==='reopen_result'){
    if(session.role!=='admin')throw Error('Solo Super dios tiene este permiso.');
    const r=s.results.find(r=>r.id===payload.id);
    if(!r)throw Error('El resultado no existe.');
    if(r.kind==='tournament')throw Error('Los torneos se corrigen desde la vista del torneo.');
    if(r.status!=='validated'&&r.status!=='void')throw Error('Solo se pueden reabrir resultados validados o anulados.');
    if(r.version!==payload.version)throw Error('El resultado cambió. Actualiza antes de reabrir.');
    if(String(payload.reason||'').trim().length<5)throw Error('Indica el motivo para reabrir.');
    r.status='provisional';r.version++;r.reason=payload.reason;r.updated_at=new Date().toISOString();
  }else if(action==='save_winner'){
    const g=s.games.find(g=>g.id===payload.game);const old=s.results.find(r=>r.id===payload.id);
    if(!g)throw Error('Juego no disponible.');
    if(old&&old.version!==payload.version)throw Error('El resultado cambió. Actualiza.');
    if(old&&session.role!=='admin')throw Error('Solo Super dios puede corregir un ganador registrado.');
    if(s.results.some(r=>r.id!==payload.id&&r.game===g.id&&r.status!=='void'))throw Error('Este juego ya tiene un ganador registrado.');
    const winner=s.patrols.find(p=>p.id===payload.winner);
    if(!winner||!eligible(winner,g))throw Error('La patrulla no corresponde a este juego.');
    const r={id:payload.id,game:g.id,phase:g.phase,label:g.name,entries:[{patrol:winner.id,points:1}],winner:winner.id,official_win:true,status:old?.status==='validated'?'validated':'provisional',version:(old?.version||0)+1,kind:'activity',created_by:old?.created_by||session.name,updated_at:new Date().toISOString(),notes:'',reason:payload.reason||''};
    if(old)s.results[s.results.indexOf(old)]=r;else s.results.push(r);
  }else if(action==='save_result'){
    const g=s.games.find(g=>g.id===payload.game);const old=s.results.find(r=>r.id===payload.id);
    if(old&&old.version!==payload.version)throw Error('El resultado cambió. Actualiza antes de editar.');
    if(old?.status==='validated'&&!admin)throw Error('Solo el administrador corrige resultados validados.');
    if(s.results.some(r=>r.id!==payload.id&&r.game===g.id&&r.status!=='void'&&r.entries.some(e=>payload.entries.some(x=>x.patrol===e.patrol)))||s.tournaments.some(t=>t.game===g.id&&!t.cancelled&&payload.entries.some(e=>t.participants.includes(e.patrol))))throw Error('Una patrulla ya tiene resultado o torneo en este juego.');
    if(payload.entries.some(e=>!Number.isFinite(e.score)||e.score<0||(g.metric==='jury'&&e.score>100)))throw Error('Marcador fuera de rango.');
    const ranking=rankEntries(payload.entries,g);if(ranking.tied&&!payload.winner)throw Error('Hay empate: registra un desempate.');
    const winner=payload.winner||ranking.winner;
    const r={...payload,entries:allocate(payload.entries,winner),winner,phase:g.phase,official_win:true,status:old?.status==='validated'?'validated':'provisional',version:(old?.version||0)+1,created_by:old?.created_by||session.name,updated_at:new Date().toISOString()};
    if(old)s.results[s.results.indexOf(old)]=r;else s.results.push(r);
  }else if(action==='result_status'){
    const r=s.results.find(r=>r.id===payload.id);if(r.version!==payload.version)throw Error('El resultado cambió. Actualiza.');r.status=payload.status;r.version++;r.updated_at=new Date().toISOString();
  }else throw Error('Acción desconocida.');
  // Toda modificación competitiva invalida decisiones de desempate anteriores.
  if(!['set_decision','set_closed'].includes(action))s.decisions={};
  s.logs.unshift({id:crypto.randomUUID(),action,actor:session.name,role:session.role,at:new Date().toISOString(),payload,before:action==='save_result'||action==='reopen_result'?before.results.find(r=>r.id===payload.id)||null:action==='validate_results'?before.results.filter(r=>(payload.items||[]).some(i=>i.id===r.id)):action==='score_match'||action==='cancel_tournament'?before.tournaments.find(t=>t.id===payload.id):action==='clear_results'?{results:before.results.length,tournaments:before.tournaments.length,kitchen_scores:(before.kitchen_scores||[]).length,closed:before.closed}:null});
  localStorage.setItem(demoKey,JSON.stringify(s));return {ok:true};
}



