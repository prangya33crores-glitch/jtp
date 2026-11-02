import {db,requireAdmin,readWorkspace,sameOrigin,privateJson} from '../../../lib/portal-db';
import {passwordHash,normalizeLogin,checkPassword} from '../../../lib/password-auth';
export const dynamic='force-dynamic';
export async function GET(req:Request){try{const owner=await requireAdmin(req);const r=await db().prepare('SELECT person,login_id,mobile,status,must_change,updated_at FROM password_accounts WHERE workspace=?').bind(owner).all();return privateJson({accounts:r.results});}catch(e){return privateJson({error:(e as Error).message},403);}}
export async function POST(req:Request){try{const owner=await requireAdmin(req);if(!sameOrigin(req))return privateJson({error:'Invalid origin.'},403);const p:any=await req.json();const s=await readWorkspace(owner);const person=s.personnel.find(x=>x.id===p.person);if(!person)throw Error('Select an employee.');const id=owner+':'+person.id;const now=new Date().toISOString();
 if(p.action==='save'){
  if(person.status!=='Active')throw Error('Activate the JTP record first.');checkPassword(p.password);const login=normalizeLogin(person.code);const mobile=/^\d{10}$/.test(person.mobile)?person.mobile:null;
  if(!login)throw Error('Employee ID is required.');
  const clash=await db().prepare('SELECT id FROM password_accounts WHERE id<>? AND (login_id=? OR mobile=? OR login_id=? OR mobile=?) LIMIT 1').bind(id,login,mobile,mobile,login).first();if(clash)throw Error('This Employee ID or mobile is linked to another login. Update the JTP record first.');
  const hash=await passwordHash(p.password);await db().batch([
   db().prepare("INSERT INTO password_accounts(id,workspace,person,login_id,mobile,password_hash,status,must_change,updated_at) VALUES(?,?,?,?,?,?,'Active',1,?) ON CONFLICT(id) DO UPDATE SET login_id=excluded.login_id,mobile=excluded.mobile,password_hash=excluded.password_hash,status='Active',must_change=1,updated_at=excluded.updated_at").bind(id,owner,person.id,login,mobile,hash,now),
   db().prepare('DELETE FROM password_sessions WHERE account=?').bind(id),
   db().prepare('INSERT INTO audit(id,workspace,action,details,created_at) VALUES(?,?,?,?,?)').bind(crypto.randomUUID(),owner,'employee_password_reset',JSON.stringify({person:person.id,actor:owner}),now)
  ]);return privateJson({ok:true,loginId:login,mobile});
 }
 if(p.action==='disable'||p.action==='enable'){const existing=await db().prepare('SELECT id FROM password_accounts WHERE id=?').bind(id).first();if(!existing)throw Error('Create the employee login first.');await db().batch([db().prepare('UPDATE password_accounts SET status=?,updated_at=? WHERE id=?').bind(p.action==='disable'?'Disabled':'Active',now,id),db().prepare('DELETE FROM password_sessions WHERE account=?').bind(id),db().prepare('INSERT INTO audit(id,workspace,action,details,created_at) VALUES(?,?,?,?,?)').bind(crypto.randomUUID(),owner,'employee_login_'+p.action,JSON.stringify({person:person.id,actor:owner}),now)]);return privateJson({ok:true});}
 throw Error('Invalid action.');
 }catch(e){return privateJson({error:(e as Error).message},400);}}
