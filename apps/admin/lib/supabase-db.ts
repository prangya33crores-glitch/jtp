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
 const r=await fetch(e.JTP_SUPABASE_URL+'/functions/v1/jtp-database',{method:'POST',redirect:'manual',headers:{'Content-Type':'application/json','x-jtp-key':e.JTP_SUPABASE_SECRET},body:JSON.stringify({action,...payload}),signal:AbortSignal.timeout(60000)});
 if(!r.ok)throw Error('Database request failed. Please try again shortly.');
 return r.json() as Promise<any>;
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
