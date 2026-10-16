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
export async function mutate(action,payload){
  if(!demo)return rpc('camp_mutate',{p_token:session.token,p_action:action,p_payload:payload});
  const s=await snapshot();const before=structuredClone(s);const admin=session.role==='admin';
  if(s.closed&&!['set_closed'].includes(action))throw Error('El evento está cerrado.');
  if(action==='set_decision'){s.decisions={...(s.decisions||{}),[payload.type]:{winner:payload.winner,reason:payload.reason}};}
  else if(action==='cancel_tournament'){const t=s.tournaments.find(t=>t.id===payload.id);t.cancelled=true;t.version++;const r=s.results.find(r=>r.id===t.id);if(r){r.status='void';r.version++;}}
  else if(action==='upsert_patrol'){const i=s.patrols.findIndex(p=>p.id===payload.id);const old=s.patrols[i];if(old&&old.troop!==payload.troop&&(s.results.some(r=>r.entries.some(e=>e.patrol===old.id))||s.tournaments.some(t=>t.participants.includes(old.id))))throw Error('No puedes cambiar la tropa de una patrulla con resultados o torneo.');if(s.patrols.some(p=>p.id!==payload.id&&p.name.toLowerCase()===payload.name.toLowerCase()))throw Error('El nombre ya existe.');if(i<0)s.patrols.push(payload);else s.patrols[i]=payload;}
  else if(action==='save_game'){s.games[s.games.findIndex(g=>g.id===payload.id)]=payload;}
  else if(action==='set_closed'){const x=summary(s);if(payload.closed&&(!s.results.some(r=>r.status==='validated')||s.results.some(r=>r.status==='provisional')||s.tournaments.some(t=>!t.cancelled&&!t.rounds.at(-1)[0].winner)||!x.bestTroop||!x.patrolWinner))throw Error('Resuelve pendientes, torneos y desempates antes de cerrar.');s.closed=payload.closed;}
  else if(action==='create_tournament'){
    if(new Set(payload.participants).size!==payload.participants.length)throw Error('Patrullas repetidas.');
    if(s.tournaments.some(t=>t.game===payload.game&&!t.cancelled))throw Error('Ya existe un torneo para este juego.');
    const g=s.games.find(g=>g.id===payload.game);if(g.bonus)throw Error('Bandas no usa eliminación directa.');
    if(s.results.some(r=>r.game===g.id&&r.status!=='void'&&r.entries.some(e=>payload.participants.includes(e.patrol))))throw Error('Una patrulla ya tiene resultado en este juego.');
    s.tournaments.push({...payload,rounds:makeBracket(payload.participants),version:1});
  }else if(action==='score_match'){
    const t=s.tournaments.find(t=>t.id===payload.id);if(t.cancelled||t.version!==payload.version)throw Error('Otro dirigente actualizó este torneo. Actualiza.');
    const g=s.games.find(g=>g.id===t.game);scoreBracket(t,payload.round,payload.index,payload.a,payload.b,g.metric);t.version++;
    const final=t.rounds.at(-1)[0];if(final.winner){const entries=t.participants.map(p=>({patrol:p,score:0,points:p===final.winner?3:[final.a,final.b].includes(p)?2:1}));s.results.push({id:t.id,game:g.id,phase:g.phase,label:t.name,entries,winner:final.winner,official_win:!g.bonus,status:'provisional',version:1,kind:'tournament',created_by:session.name,updated_at:new Date().toISOString()});}
  }else if(action==='save_result'){
    const g=s.games.find(g=>g.id===payload.game);const old=s.results.find(r=>r.id===payload.id);
    if(old&&old.version!==payload.version)throw Error('El resultado cambió. Actualiza antes de editar.');
    if(old?.status==='validated'&&!admin)throw Error('Solo el administrador corrige resultados validados.');
    if(s.results.some(r=>r.id!==payload.id&&r.game===g.id&&r.status!=='void'&&r.entries.some(e=>payload.entries.some(x=>x.patrol===e.patrol)))||s.tournaments.some(t=>t.game===g.id&&!t.cancelled&&payload.entries.some(e=>t.participants.includes(e.patrol))))throw Error('Una patrulla ya tiene resultado o torneo en este juego.');
    if(payload.entries.some(e=>!Number.isFinite(e.score)||e.score<0||(g.metric==='jury'&&e.score>100)))throw Error('Marcador fuera de rango.');
    const ranking=rankEntries(payload.entries,g);if(ranking.tied&&!payload.winner)throw Error('Hay empate: registra un desempate.');
    const winner=payload.winner||ranking.winner;
    const r={...payload,entries:allocate(payload.entries,winner,g.bonus),winner,phase:g.phase,official_win:!g.bonus,status:old?.status==='validated'?'validated':'provisional',version:(old?.version||0)+1,created_by:old?.created_by||session.name,updated_at:new Date().toISOString()};
    if(old)s.results[s.results.indexOf(old)]=r;else s.results.push(r);
  }else if(action==='result_status'){
    const r=s.results.find(r=>r.id===payload.id);if(r.version!==payload.version)throw Error('El resultado cambió. Actualiza.');r.status=payload.status;r.version++;r.updated_at=new Date().toISOString();
  }else throw Error('Acción desconocida.');
  // Toda modificación competitiva invalida decisiones de desempate anteriores.
  if(!['set_decision','set_closed'].includes(action))s.decisions={};
  s.logs.unshift({id:crypto.randomUUID(),action,actor:session.name,role:session.role,at:new Date().toISOString(),payload,before:action==='save_result'?before.results.find(r=>r.id===payload.id)||null:action==='score_match'||action==='cancel_tournament'?before.tournaments.find(t=>t.id===payload.id):null});
  localStorage.setItem(demoKey,JSON.stringify(s));return {ok:true};
}
