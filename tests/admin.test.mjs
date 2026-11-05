import test from 'node:test';
import assert from 'node:assert/strict';
const storage=()=>{const m=new Map();return {getItem:k=>m.get(k)||null,setItem:(k,v)=>m.set(k,String(v)),removeItem:k=>m.delete(k),clear:()=>m.clear()};};
globalThis.window={CADIPAS_CONFIG:{}};globalThis.sessionStorage=storage();globalThis.localStorage=storage();
const api=await import('../api.js');
test('editor conserva todos los campos, detecta conflictos y registra antes y después',async()=>{
  api.startDemo();const catalog=await api.adminCatalog();assert.ok(catalog.some(t=>t.name==='event'&&t.editable));
  const data=await api.adminRows('camp_private','event');const record=data.rows[0],row=structuredClone(record.value);row.data.patrols[0].name='Patrulla corregida';row.data.ajuste_personalizado={valor:42};
  await api.adminWrite({schema:'camp_private',table:'event',action:'update',key:{id:1},row,revision:record.revision,reason:'Corrección de prueba'});
  const s=await api.snapshot();assert.equal(s.patrols[0].name,'Patrulla corregida');assert.equal(s.ajuste_personalizado.valor,42);assert.equal(s.logs[0].action,'admin_update');assert.ok(s.logs[0].before&&s.logs[0].after);
  await assert.rejects(api.adminWrite({schema:'camp_private',table:'event',action:'update',key:{id:1},row,revision:record.revision,reason:'Versión antigua'}),/cambió/);
  const history=await api.adminRows('camp_private','admin_changes');assert.equal(history.total,1);
});
test('el editor no elimina el evento único ni modifica el historial protegido',async()=>{
  localStorage.clear();api.startDemo();const row=(await api.adminRows('camp_private','event')).rows[0];
  await assert.rejects(api.adminWrite({schema:'camp_private',table:'event',action:'delete',key:{id:1},revision:row.revision,reason:'Prueba'}),/no se elimina/);
  await assert.rejects(api.adminWrite({schema:'camp_private',table:'admin_changes',action:'insert',key:{},row:{id:'falso'},reason:'Prueba'}),/protegido/);
});
