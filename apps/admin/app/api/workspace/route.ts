import {db,requireAdmin} from '../../../lib/portal-db';
import {initial,apply,currentRosterPeriod} from '../../../lib/engine';
export const dynamic='force-dynamic';
async function load(id:string){const row=await db().prepare('SELECT revision, data FROM workspaces WHERE id = ?').bind(id).first<{revision:number,data:string}>();return row?{revision:row.revision,state:JSON.parse(row.data)}:{revision:0,state:initial()};}
export async function GET(req:Request){try{const id=await requireAdmin(req);return Response.json({...await load(id),currentPeriod:currentRosterPeriod()},{headers:{'Cache-Control':'private, no-store'}});}catch(e){return Response.json({error:(e as Error).message},{status:(e as Error).message==='Sign in required.'?401:403});}}
export async function POST(req:Request){
 if(req.headers.get('origin')&&req.headers.get('origin')!==new URL(req.url).origin)return Response.json({error:'Invalid origin.'},{status:403});
 try{
  const id=await requireAdmin(req);
  const p:any=await req.json();if(!p||typeof p.action!=='string'||!Number.isInteger(p.revision))throw Error('Invalid request.');
  if(['assign','publish'].includes(p.action))throw Error('Manual assignment and month publishing are disabled. Use automatic current-period allocation.');
  const current=await load(id);if(p.revision!==current.revision)return Response.json({error:'Workspace changed. Refresh and try again.'},{status:409});
  const state=apply(current.state,p.action,p.payload||{});const data=JSON.stringify(state);if(data.length>1500000)throw Error('Workspace limit reached. Contact your administrator.');
  const results=await db().batch([
   db().prepare('INSERT INTO workspaces(id,revision,data) VALUES(?,1,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data,revision=workspaces.revision+1 WHERE workspaces.revision=?').bind(id,data,p.revision),
   db().prepare('INSERT INTO audit(id,workspace,action,details,created_at) SELECT ?,?,?,?,? WHERE EXISTS (SELECT 1 FROM workspaces WHERE id=? AND revision=? AND data=?)').bind(crypto.randomUUID(),id,p.action,JSON.stringify({before:current.state,after:state}),new Date().toISOString(),id,current.revision+1,data)
  ]);
  if(!results[0].meta.changes)return Response.json({error:'Another change was saved. Refresh and retry.'},{status:409});
  return Response.json({state,revision:current.revision+1,currentPeriod:currentRosterPeriod()});
 }catch(e){return Response.json({error:e instanceof Error?e.message:'Unable to save.'},{status:400});}
}
