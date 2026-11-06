/// <reference types="vite/client" />
import {env} from 'cloudflare:workers';
export type StatementInput={sql:string,params:unknown[]};
type QueryResult<T=Record<string,unknown>>={results:T[],meta:{changes:number},success:boolean};
export async function gateway(action:'batch',payload:Record<string,unknown>={}){
 const e=env as unknown as Record<string,string>;
 if(!e.JTP_SUPABASE_URL)throw Error('Supabase database is not configured.');
 const localDevelopment=typeof import.meta.env!=='undefined' && import.meta.env.DEV;
 if(localDevelopment && e.JTP_SUPABASE_LOCAL_SERVICE_KEY){
  const key=e.JTP_SUPABASE_LOCAL_SERVICE_KEY;
  const r=await fetch(e.JTP_SUPABASE_URL+'/rest/v1/rpc/jtp_batch',{method:'POST',redirect:'manual',headers:{'Content-Type':'application/json',apikey:key,...(key.startsWith('eyJ')?{Authorization:'Bearer '+key}:{})},body:JSON.stringify({statements:payload.statements}),signal:AbortSignal.timeout(60000)});
  if(!r.ok)throw Error('Local Supabase connection failed. Check your server key in .dev.vars.');
  return r.json() as Promise<any>;
 }
 if(!e.JTP_SUPABASE_SECRET)throw Error('Supabase server configuration is missing.');
 const statements=payload.statements as StatementInput[]|undefined;
 // Only replay reads and attendance, which has a database uniqueness guard.
 const retryable=!!statements?.length&&statements.every(s=>
  s.sql==='SELECT mark_attendance(?,?,?,?,?,?) AS record'||
  (/^SELECT /i.test(s.sql)&&!s.sql.includes('write_workspace(')));
 for(let attempt=0;attempt<3;attempt++){
  const r=await fetch(e.JTP_SUPABASE_URL+'/functions/v1/jtp-database',{method:'POST',redirect:'manual',headers:{'Content-Type':'application/json','x-jtp-key':e.JTP_SUPABASE_SECRET},body:JSON.stringify({action,...payload}),signal:AbortSignal.timeout(60000)});
  if(r.ok)return r.json() as Promise<any>;
  const temporary=[502,503,504].includes(r.status);
  console.error('Supabase gateway request failed',{status:r.status,attempt:attempt+1});
  if(!temporary||!retryable||attempt===2)throw Error(temporary?'The database is temporarily unavailable. Please try again in a moment.':'Database request failed. Please try again shortly.');
  await r.body?.cancel();
  await new Promise(resolve=>setTimeout(resolve,500*(attempt+1)));
 }
 throw Error('Database request failed. Please try again shortly.');
}
export class SupabaseStatement{
 readonly sql:string; readonly params:unknown[];
 constructor(sql:string,params:unknown[]=[]){this.sql=sql;this.params=params;}
 bind(...params:unknown[]){return new SupabaseStatement(this.sql,params);}
 async all<T=Record<string,unknown>>():Promise<QueryResult<T>>{return (await gateway('batch',{statements:[this]}))[0];}
 async first<T=Record<string,unknown>>():Promise<T|null>{return (await this.all<T>()).results[0]||null;}
 async run(){return this.all();}
}
export class SupabaseDatabase{
 prepare(sql:string){return new SupabaseStatement(sql);}
 async batch(statements:SupabaseStatement[]):Promise<QueryResult[]>{return gateway('batch',{statements});}
}
