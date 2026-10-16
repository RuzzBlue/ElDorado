export const TROOPS = [
  {id:'quezada',name:'Expedición de Quezada',short:'Quezada',alliance:'europeos',icon:'⚑'},
  {id:'federmann',name:'Expedición de Federmann',short:'Federmann',alliance:'europeos',icon:'✦'},
  {id:'zaque',name:'Zaque Quemuenchatocha',short:'Quemuenchatocha',alliance:'muiscas',icon:'☀'},
  {id:'zipa',name:'Zipa Tisquesusa',short:'Tisquesusa',alliance:'muiscas',icon:'◆'},
];
export const PHASES = {viernes:'Viernes',sabado:'Sábado',domingo:'Domingo'};
export const BLOCKS = ['Masivos','Módulo 1','Módulo 2','Módulo 3','Módulo 4','Módulo 5','Módulo 6'];
// Definiciones propuestas. El administrador puede ajustar alcance y reglamento.
const raw = [
['retos','Lista de retos','viernes','Masivos','21:15','all','higher','Retos validados. Usar listas con dificultad equivalente.'],
['imprenta','Imprenta perfecta','sabado','Módulo 1','16:30','europeos','higher','Rondas ganadas con cuadrícula correcta.'],
['vampirinos','Vampiriños','sabado','Módulo 1','16:54','europeos','higher','Cantidad consumida con igual cantidad inicial. Acordar unidad.'],
['maquina','La máquina perfecta','sabado','Módulo 1','17:18','europeos','jury','Funcionamiento 40, verticalidad 20, creatividad 20 y complejidad 20.'],
['password','Password','sabado','Módulo 1','17:42','europeos','higher','Aciertos válidos durante el tiempo fijado.'],
['sisifo','Sísifo','sabado','Módulo 1','18:06','europeos','lower','Segundos para completar. Si nadie termina, usar avance y cambiar criterio antes de registrar.'],
['arana3','ArañaCross 3','sabado','Módulo 2','16:30','muiscas','higher','Llegadas válidas con igual tiempo y participantes activos.'],
['camellos','Camellos tácticos','sabado','Módulo 2','16:54','muiscas','higher','Puntaje de blancos. Igual cantidad de intentos.'],
['conecta','Conecta 4 extremo','sabado','Módulo 2','17:18','muiscas','higher','Rondas ganadas.'],
['coronacion','Coronación','sabado','Módulo 2','17:42','muiscas','jury','Elementos cumplidos 60, creatividad 20 y presentación 20.'],
['fortines','Fortines inverso','sabado','Módulo 2','18:06','muiscas','higher','Propuesta: rondas ganadas. Formalizar condición de victoria.'],
['jet','Jet Lag','sabado','Masivos','18:45','all','lower','Segundos del recorrido válido. Se juega en paralelo a Fiebre del oro.'],
['oro','Fiebre del oro','sabado','Masivos','18:45','all','higher','Monedas válidas al cierre. Asignar patrullas sin duplicar oportunidades.'],
['conejos3','Conejos, Naipes y UNO','sabado','Módulo 3','21:20','europeos','higher','Nudos obtenidos. Capacidad prevista: 6 patrullas.'],
['arana1-3','ArañaCross 1','sabado','Módulo 3','21:20','europeos','higher','Participantes que pasan válidamente. Igual cantidad de intentos.'],
['lineas3','Líneas superpuestas','sabado','Módulo 3','21:50','europeos','lower','Segundos para completar correctamente.'],
['acecho3','Acecho','sabado','Módulo 3','21:50','europeos','higher','Llegadas válidas en tiempo fijo.'],
['bandas3','Batalla de las bandas','sabado','Módulo 3','22:20','europeos','jury','Coordinación 40, participación 40, consigna 20. Bonificación, sin victoria oficial.'],
['lineas4','Líneas superpuestas','sabado','Módulo 4','21:20','muiscas','lower','Segundos para completar correctamente.'],
['acecho4','Acecho','sabado','Módulo 4','21:20','muiscas','higher','Llegadas válidas en tiempo fijo.'],
['conejos4','Conejos, Naipes y UNO','sabado','Módulo 4','21:50','muiscas','higher','Nudos obtenidos.'],
['arana1-4','ArañaCross 1','sabado','Módulo 4','21:50','muiscas','higher','Participantes que pasan válidamente. Igual cantidad de intentos.'],
['bandas4','Batalla de las bandas','sabado','Módulo 4','22:20','muiscas','jury','Coordinación 40, participación 40, consigna 20. Bonificación, sin victoria oficial.'],
['pesca','Pesca2','domingo','Módulo 5','10:10','all','higher','Suma de peces de las tres rondas. Mercado.'],
['pictionary','Ultrapictionary','domingo','Módulo 5','10:34','all','higher','Dibujos adivinados. Mercado.'],
['escudeiros','Escudeiros','domingo','Módulo 5','10:58','all','lower','Segundos totales incluyendo penalizaciones reglamentadas. Portón.'],
['tiro','Polígono de tiro','domingo','Módulo 5','11:22','all','higher','Suma de disparos con igual cantidad de intentos. Portón.'],
['quemados','Quemados cuarta pared','domingo','Módulo 5','11:46','all','higher','Rondas ganadas. Acordar límite y desempate. Plaza.'],
['futbol','Fútbol maya','domingo','Módulo 5','10:10','all','higher','Goles válidos. Cementerio.'],
['contacto','Con-tacto','domingo','Módulo 5','10:34','all','higher','Cartas trasladadas correctamente. Templo.'],
['reloj','Reloj Suizo','domingo','Módulo 5','10:58','all','higher','Rondas ganadas. Templo.'],
['body','Body Moves','domingo','Módulo 5','11:22','all','higher','Propuesta: cruces completos de los cuatro circuitos. Palacio.'],
['gladiadores','Encuentro de gladiadores','domingo','Módulo 5','11:46','all','higher','Supervivientes al cierre. Igual cantidad de jugadores. Palacio.'],
['borrachos','Borrachos mojados','domingo','Módulo 6','13:25 / 13:55','all','higher','Agua acumulada en mililitros. Registrar cada patrulla por separado.'],
['alunizaje','Alunizaje forzado','domingo','Módulo 6','13:25 / 13:55','all','higher','Pelotas recogidas válidamente.'],
['bandas6','Batalla de las bandas final','domingo','Módulo 6','14:25','all','jury','Coordinación 40, participación 40, consigna 20. Bonificación, sin victoria oficial.'],
];
export const GAMES=raw.map(([id,name,phase,block,time,scope,metric,rules])=>({id,name,phase,block,time,scope,metric,rules,bonus:id.startsWith('bandas'),enabled:true}));
export const troop = id => TROOPS.find(t=>t.id===id);
export function eligible(p,g){return g.scope==='all'||troop(p.troop)?.alliance===g.scope;}
export function rankEntries(entries,game){
  const xs=entries.map(e=>({...e,score:Number(e.score)}));
  xs.sort((a,b)=>game.metric==='lower'?a.score-b.score:b.score-a.score);
  const tied=xs.length>1 && xs[0].score===xs[1].score;
  return {entries:xs,tied,winner:!tied?xs[0]?.patrol:null};
}
export function standings(state){
  const rows=state.patrols.map(p=>({...p,wins:0,points:0,played:0,provisional:0,saturday:0,sunday:0}));
  const byId=Object.fromEntries(rows.map(p=>[p.id,p]));
  for(const r of state.results){
    if(r.status==='void')continue;
    for(const e of r.entries){const p=byId[e.patrol];if(!p)continue;if(r.status!=='validated'){p.provisional++;continue;}
      p.played++;p.points+=Number(e.points||0);if(r.official_win&&r.winner===p.id)p.wins++;
      if(r.phase==='domingo')p.sunday+=Number(e.points||0);else p.saturday+=Number(e.points||0);
    }
  }
  return rows.sort((a,b)=>b.wins-a.wins||b.points-a.points||a.name.localeCompare(b.name));
}
export function summary(state){
  const rows=standings(state);
  const troops=TROOPS.map(t=>({...t,points:rows.filter(p=>p.troop===t.id).reduce((n,p)=>n+p.saturday,0)}));
  const alliances=['europeos','muiscas'].map(id=>({id,name:id==='europeos'?'Europeos':'Muiscas',points:rows.filter(p=>troop(p.troop)?.alliance===id).reduce((n,p)=>n+p.sunday,0)}));
  const sorted=[...alliances].sort((a,b)=>b.points-a.points);
  const decisions=state.decisions||{};
  const winning=sorted[0].points>sorted[1].points?sorted[0]:alliances.find(a=>a.id===decisions.alliance?.winner)||null;
  const leaders=Object.fromEntries(alliances.map(a=>{const ts=troops.filter(t=>t.alliance===a.id).sort((x,y)=>y.points-x.points);return[a.id,ts[0].points>ts[1].points?ts[0]:ts.find(t=>t.id===decisions[a.id]?.winner)||null];}));
  const tiedPatrols=rows.filter(p=>p.wins===rows[0]?.wins&&p.points===rows[0]?.points);
  const patrolWinner=tiedPatrols.length===1?tiedPatrols[0]:tiedPatrols.find(p=>p.id===decisions.patrol?.winner)||null;
  return {rows,troops,alliances,leaders,winning,bestTroop:winning?leaders[winning.id]:null,patrolTie:tiedPatrols.length>1&&!patrolWinner,patrolWinner,tiedPatrols};
}
export function demoState(){return {patrols:TROOPS.flatMap((t,i)=>['Cóndores','Lobos','Pumas','Halcones','Jaguares'].map((n,j)=>({id:`${t.id}-${j+1}`,name:`${n} ${i+1}`,troop:t.id,group:'Grupo de ejemplo',members:6}))),games:structuredClone(GAMES),results:[],tournaments:[],logs:[],closed:false};}
export function makeBracket(ids){
  let size=2;while(size<ids.length)size*=2;
  const rounds=[];let pairs=[];
  for(let i=0;i<size/2;i++)pairs.push({a:ids[i]||null,b:ids[size-1-i]||null,winner:null,scoreA:null,scoreB:null,bye:false});
  rounds.push(pairs);for(let n=size/4;n>=1;n/=2)rounds.push(Array.from({length:n},()=>({a:null,b:null,winner:null,scoreA:null,scoreB:null,bye:false})));
  for(let i=0;i<pairs.length;i++)if(!pairs[i].b){pairs[i].winner=pairs[i].a;pairs[i].bye=true;if(rounds[1])rounds[1][Math.floor(i/2)][i%2?'b':'a']=pairs[i].a;}
  return rounds;
}
export function scoreBracket(t,round,index,a,b,metric){
  const m=t.rounds[round]?.[index];if(!m||!m.a||!m.b||m.winner)throw Error('El encuentro no está disponible.');
  if(a===b)throw Error('Eliminación directa requiere desempate.');
  m.scoreA=a;m.scoreB=b;m.winner=(metric==='lower'?a<b:a>b)?m.a:m.b;
  if(t.rounds[round+1])t.rounds[round+1][Math.floor(index/2)][index%2?'b':'a']=m.winner;
  return t;
}
export function allocate(entries,winner,bonus=false){return entries.map(e=>({...e,points:e.patrol===winner?(bonus?1:3):(bonus?0:1)}));}
