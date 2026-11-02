import {db,requireAdmin,readWorkspace,sameOrigin,privateJson} from '../../../lib/portal-db';
import {hashAccessCode} from '../../../lib/employee-access';
export const dynamic='force-dynamic';
export async function GET(req:Request){try{const owner=await requireAdmin(req);const rows=await db().prepare('SELECT person,status,email,expires_at,user_id IS NOT NULL AS linked FROM employee_access WHERE workspace=?').bind(owner).all();return privateJson({accounts:rows.results});}catch(e){return privateJson({error:(e as Error).message},403);}}
export async function POST(req:Request){try{
 const owner=await requireAdmin(req);if(!sameOrigin(req))return privateJson({error:'Invalid origin.'},403);
 const body:any=await req.json();const s=await readWorkspace(owner);const person=s.personnel.find(p=>p.id===body.person);if(!person)throw Error('Choose a valid JTP employee.');
 const id=owner+':'+person.id;const now=new Date().toISOString();let code:string|undefined;
 if(body.action==='issue'){
  if(person.status!=='Active')throw Error('Activate the JTP employee first.');
  code=crypto.randomUUID().replaceAll('-','');const hash=await hashAccessCode(code);const expiry=new Date(Date.now()+7*86400000).toISOString();
  await db().batch([
   db().prepare("INSERT INTO employee_access(id,workspace,person,code_hash,expires_at,user_id,email,status,created_at) VALUES(?,?,?,?,?,NULL,NULL,'Active',?) ON CONFLICT(id) DO UPDATE SET code_hash=excluded.code_hash,expires_at=excluded.expires_at,user_id=NULL,email=NULL,status='Active'").bind(id,owner,person.id,hash,expiry,now),
   db().prepare('INSERT INTO audit(id,workspace,action,details,created_at) VALUES(?,?,?,?,?)').bind(crypto.randomUUID(),owner,'employee_access_issue',JSON.stringify({person:person.id,actor:owner}),now)
  ]);return privateJson({code,expiresAt:expiry,employee:{name:person.name,code:person.code}});
 }
 if(body.action==='disable'||body.action==='enable'){
  const status=body.action==='disable'?'Disabled':'Active';
  const r=await db().prepare('UPDATE employee_access SET status=? WHERE id=?').bind(status,id).run();if(!r.meta.changes)throw Error('Create employee access first.');
  await db().prepare('INSERT INTO audit(id,workspace,action,details,created_at) VALUES(?,?,?,?,?)').bind(crypto.randomUUID(),owner,'employee_access_'+body.action,JSON.stringify({person:person.id,actor:owner}),now).run();return privateJson({ok:true});
 }
 throw Error('Invalid employee access action.');
 }catch(e){return privateJson({error:(e as Error).message},400);}}
