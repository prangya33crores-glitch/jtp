import {db,adminId,readWorkspace,sameOrigin,privateJson} from '../../../lib/portal-db';
import {employeePortalData,hashAccessCode,validClaim,type Access} from '../../../lib/employee-access';
export const dynamic='force-dynamic';
const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Kolkata',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
export async function GET(req:Request){const user=req.headers.get('oai-authenticated-user-id');if(!user)return privateJson({error:'Sign in with ChatGPT to view your shifts.'},401);try{
 const account=await db().prepare('SELECT workspace,person,user_id,status FROM employee_access WHERE user_id=?').bind(user).first<Access>();
 if(!account)return privateJson({error:'Enter your one-time access code from Super Admin.',needsCode:true},403);
 const state=await readWorkspace(account.workspace);const month=new URL(req.url).searchParams.get('month')||today().slice(0,7);
 return privateJson(employeePortalData(account,user,state,month,today()));
 }catch(e){return privateJson({error:(e as Error).message},403);}}
export async function POST(req:Request){const user=req.headers.get('oai-authenticated-user-id');if(!user)return privateJson({error:'Sign in required.'},401);if(!sameOrigin(req))return privateJson({error:'Invalid origin.'},403);try{
 if(user===await adminId())throw Error('Use the employee’s own ChatGPT account. The Super Admin account cannot be linked as an employee.');
 const body:any=await req.json();if(typeof body.code!=='string'||!/^[a-f0-9]{32}$/.test(body.code.trim()))throw Error('Enter a valid access code.');
 const hash=await hashAccessCode(body.code);const account=await db().prepare('SELECT id,workspace,person,user_id,status,expires_at,code_hash FROM employee_access WHERE code_hash=?').bind(hash).first<Access&{id:string}>();
 const now=new Date().toISOString();if(!validClaim(account,now)||!account)throw Error('This code is invalid, expired or already used. Ask Super Admin for a new code.');
 const s=await readWorkspace(account.workspace);if(!s.personnel.some(p=>p.id===account.person&&p.status==='Active'))throw Error('Employee access is not active. Contact Super Admin.');
 const existing=await db().prepare('SELECT id FROM employee_access WHERE user_id=?').bind(user).first();if(existing)throw Error('This account is already linked to an employee. Contact Super Admin.');
 const result=await db().batch([
  db().prepare("UPDATE employee_access SET user_id=?,email=?,code_hash=NULL,expires_at=NULL WHERE id=? AND code_hash=? AND user_id IS NULL AND status='Active' AND expires_at>?").bind(user,req.headers.get('oai-authenticated-user-email')||'',account.id,hash,now),
  db().prepare('INSERT INTO audit(id,workspace,action,details,created_at) SELECT ?,?,?,?,? WHERE EXISTS (SELECT 1 FROM employee_access WHERE id=? AND user_id=?)').bind(crypto.randomUUID(),account.workspace,'employee_access_claim',JSON.stringify({person:account.person,actor:user}),now,account.id,user)
 ]);if(!result[0].meta.changes)throw Error('Code already used or access changed. Ask Super Admin for a new code.');return privateJson({ok:true});
 }catch(e){return privateJson({error:(e as Error).message},400);}}
