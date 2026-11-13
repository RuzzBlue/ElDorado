import test from 'node:test';
import assert from 'node:assert/strict';
import {standings,summary} from '../domain.js';
const storage=()=>{const values=new Map();return {getItem:k=>values.get(k)||null,setItem:(k,v)=>values.set(k,String(v)),removeItem:k=>values.delete(k),clear:()=>values.clear()};};
globalThis.window={CADIPAS_CONFIG:{}};globalThis.sessionStorage=storage();globalThis.localStorage=storage();
const api=await import('../api.js');
test('flujo de demo: registrar, validar, conflicto, corregir y anular',async()=>{
  localStorage.clear();api.startDemo();let s=await api.snapshot();const a=s.patrols[0].id,b=s.patrols[1].id;
  await api.mutate('save_winner',{id:'r',game:'retos',winner:a,version:0});
  s=await api.snapshot();assert.equal(standings(s)[0].wins,0);assert.equal(s.results[0].entries[0].points,1);
  await api.mutate('result_status',{id:'r',version:1,status:'validated',reason:'Revisado QA'});
  s=await api.snapshot();assert.equal(standings(s)[0].wins,1);
  await assert.rejects(api.mutate('save_winner',{id:'r',game:'retos',winner:b,version:1}),/cambió/);
  await assert.rejects(api.mutate('save_winner',{id:'dup',game:'retos',winner:b,version:0}),/ya tiene/);
  api.startDemo();await api.mutate('save_winner',{id:'r',game:'retos',winner:b,version:2,reason:'Corrección verificada'});
  s=await api.snapshot();assert.equal(standings(s)[0].id,b);assert.equal(s.results[0].status,'validated');
  await api.mutate('result_status',{id:'r',version:3,status:'void',reason:'Anulación verificada'});
  s=await api.snapshot();assert.equal(standings(s).reduce((n,p)=>n+p.wins,0),0);assert.equal(s.logs.length,4);
});
test('torneo, pase libre, puntos de campeón y anulación conservan auditoría',async()=>{
  localStorage.clear();api.startDemo();const s=await api.snapshot(),ids=s.patrols.slice(0,3).map(p=>p.id);
  await api.mutate('create_tournament',{id:'t',game:'imprenta',name:'QA',participants:ids});
  await api.mutate('score_match',{id:'t',round:0,index:1,a:4,b:2,version:1});
  await api.mutate('score_match',{id:'t',round:1,index:0,a:1,b:2,version:2});
  let next=await api.snapshot();assert.equal(next.results.length,1);assert.equal(next.results[0].winner,ids[1]);assert.deepEqual(next.results[0].entries.map(e=>e.points),[2,3,1]);
  await api.mutate('cancel_tournament',{id:'t',version:3,reason:'Rehacer por error QA'});
  next=await api.snapshot();assert.equal(next.results[0].status,'void');assert.equal(next.tournaments[0].cancelled,true);assert.equal(next.logs.length,4);
  await assert.rejects(api.mutate('reopen_result',{id:'t',version:2,reason:'Reabrir torneo QA'}),/torneo/);
  await api.mutate('create_tournament',{id:'t2',game:'imprenta',name:'QA corregido',participants:ids});
  await assert.rejects(api.mutate('save_result',{id:'direct',game:'imprenta',entries:[{patrol:ids[0],score:1},{patrol:ids[1],score:2}]}),/ya tiene/);
});
test('borrar puntajes exige DELETE y conserva patrullas, juegos y bitácora',async()=>{
  localStorage.clear();api.startDemo();let s=await api.snapshot();const a=s.patrols[0].id;
  await api.mutate('save_winner',{id:'reset-r',game:'retos',winner:a,version:0});
  await api.mutate('create_tournament',{id:'reset-t',game:'imprenta',name:'QA reset',participants:s.patrols.slice(0,3).map(p=>p.id)});
  await assert.rejects(api.mutate('clear_results',{confirm:'delete',reason:'Reinicio de pruebas'}),/DELETE/);
  await api.mutate('clear_results',{confirm:'DELETE',reason:'Reinicio de pruebas'});
  s=await api.snapshot();
  assert.equal(s.results.length,0);assert.equal(s.tournaments.length,0);assert.deepEqual(s.decisions,{});
  assert.equal(s.closed,false);assert.equal(s.patrols.length,20);assert.equal(s.games.length,39);
  assert.equal(s.logs[0].action,'clear_results');assert.deepEqual(s.logs[0].before,{results:1,tournaments:1,kitchen_scores:0,closed:false});
});
test('cocina guarda evaluaciones separadas por comida y el reinicio borra sus estrellas',async()=>{
  localStorage.clear();api.startDemo();let s=await api.snapshot(),a=s.patrols[0].id,b=s.patrols[1].id;
  const values={presentation:5,complexity:4.5,flavor:5,teamwork:4,cleanliness:5};
  await api.mutate('kitchen_score',{patrol:a,meal:'almuerzo',values});
  await api.mutate('kitchen_score',{patrol:a,meal:'cena',values});
  await api.mutate('kitchen_score',{patrol:b,meal:'almuerzo',values});
  s=await api.snapshot();assert.equal(s.kitchen_scores.length,3);assert.equal(s.kitchen_scores.filter(x=>x.meal==='almuerzo').length,2);
  await api.mutate('clear_results',{confirm:'DELETE',reason:'Reinicio de cocina'});
  s=await api.snapshot();assert.deepEqual(s.kitchen_scores,[]);
});
test('ajustes manuales cambian solo la clasificación indicada y quedan como resultado',async()=>{
  localStorage.clear();api.startDemo();let s=await api.snapshot(),p=s.patrols[0];
  await api.mutate('adjust_points',{target_type:'patrol',target:p.id,amount:2,reason:'Desempate de patrulla'});
  s=await api.snapshot();assert.equal(standings(s).find(x=>x.id===p.id).points,2);assert.equal(s.results[0].kind,'adjustment');
  await api.mutate('adjust_points',{target_type:'troop',target:p.troop,amount:3,reason:'Desempate de tropa'});
  s=await api.snapshot();assert.equal(summary(s).troops.find(x=>x.id===p.troop).points,3);
  await api.mutate('adjust_points',{target_type:'alliance',target:'europeos',amount:-1,reason:'Penalización aplicada'});
  s=await api.snapshot();assert.equal(summary(s).alliances.find(x=>x.id==='europeos').points,-1);
});
test('Super dios reabre resultados validados y anulados para corregirlos',async()=>{
  localStorage.clear();api.startDemo();let s=await api.snapshot();const a=s.patrols[0].id,b=s.patrols[1].id;
  await api.mutate('save_winner',{id:'reopen-r',game:'retos',winner:a,version:0});
  await api.mutate('result_status',{id:'reopen-r',version:1,status:'validated',reason:'Revisado QA'});

  await assert.rejects(api.mutate('reopen_result',{id:'reopen-r',version:2,reason:'x'}),/motivo/);
  await assert.rejects(api.mutate('reopen_result',{id:'reopen-r',version:1,reason:'Corrección QA'}),/cambió/);
  await api.mutate('reopen_result',{id:'reopen-r',version:2,reason:'Corrección QA'});
  s=await api.snapshot();
  assert.equal(s.results[0].status,'provisional');assert.equal(s.results[0].version,3);
  assert.equal(s.results[0].reason,'Corrección QA');assert.equal(standings(s).reduce((n,p)=>n+p.wins,0),0);
  assert.equal(s.logs[0].action,'reopen_result');assert.equal(s.logs[0].before.status,'validated');

  await assert.rejects(api.mutate('reopen_result',{id:'reopen-r',version:3,reason:'Otra revisión'}),/validados o anulados/);
  await api.mutate('save_winner',{id:'reopen-r',game:'retos',winner:b,version:3,reason:'Ganador corregido'});
  await api.mutate('result_status',{id:'reopen-r',version:4,status:'validated',reason:'Validación corregida'});
  s=await api.snapshot();assert.equal(s.results[0].winner,b);assert.equal(standings(s)[0].id,b);

  await api.mutate('result_status',{id:'reopen-r',version:5,status:'void',reason:'Anulación QA'});
  await api.mutate('reopen_result',{id:'reopen-r',version:6,reason:'Revisión de anulación'});
  s=await api.snapshot();assert.equal(s.results[0].status,'provisional');assert.equal(s.logs[0].before.status,'void');
  await api.mutate('save_winner',{id:'reopen-r',game:'retos',winner:a,version:7,reason:'Restituir ganador'});
  await api.mutate('result_status',{id:'reopen-r',version:8,status:'validated',reason:'Validación final'});
  s=await api.snapshot();assert.equal(s.results[0].winner,a);assert.equal(standings(s)[0].id,a);
});
test('Super dios valida varios resultados a la vez con comentario',async()=>{
  localStorage.clear();api.startDemo();const s=await api.snapshot();const a=s.patrols[0].id,b=s.patrols[1].id;
  await api.mutate('save_winner',{id:'bulk-1',game:'retos',winner:a,version:0});
  await api.mutate('save_winner',{id:'bulk-2',game:'jet',winner:b,version:0});
  await assert.rejects(api.mutate('validate_results',{items:[],actor:'Bryan Ruz'}),/Selecciona/);
  await assert.rejects(api.mutate('validate_results',{items:[{id:'bulk-1',version:0},{id:'bulk-2',version:1}],actor:'Bryan Ruz'}),/cambió/);
  let after=await api.snapshot();assert.ok(after.results.every(r=>r.status==='provisional'));
  await api.mutate('validate_results',{items:[{id:'bulk-1',version:1},{id:'bulk-2',version:1}],actor:'Bryan Ruz'});
  after=await api.snapshot();
  assert.ok(after.results.every(r=>r.status==='validated'&&r.reason==='Validado por Bryan Ruz'&&r.version===2));
  assert.equal(after.logs[0].action,'validate_results');assert.equal(after.logs[0].before.length,2);
  assert.equal(standings(after).find(p=>p.id===a).wins,1);assert.equal(standings(after).find(p=>p.id===b).wins,1);
  await assert.rejects(api.mutate('validate_results',{items:[{id:'bulk-1',version:2}],actor:'Bryan Ruz'}),/pendiente/);
});
test('Super dios puede crear y deshabilitar juegos sin borrarlos',async()=>{
  localStorage.clear();api.startDemo();
  await api.mutate('save_game',{id:'especial',name:'Juego especial',phase:'domingo',block:'Módulo 6',time:'14:00',scope:'all',rules:'Elegir un ganador',enabled:true});
  let s=await api.snapshot();assert.equal(s.games.find(g=>g.id==='especial').enabled,true);
  await api.mutate('save_game',{...s.games.find(g=>g.id==='especial'),enabled:false});
  s=await api.snapshot();assert.equal(s.games.find(g=>g.id==='especial').enabled,false);
});
