import {employeeLeaveRequest} from '../../../lib/engine';
import {env} from 'cloudflare:workers';
import {db,readWorkspace,privateJson} from '../../../lib/portal-db';
import {digest,randomToken,verifyPassword,passwordHash,dummyPasswordHash,secureEqual,normalizeLogin,ownEmployeeData,checkPassword} from '../../../lib/password-auth';
export const dynamic='force-dynamic';
const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Kolkata',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const now=()=>new Date().toISOString();
async function countAttempt(key:string){const time=now(),reset=new Date(Date.now()+15*60000).toISOString();await db().prepare('INSERT INTO password_attempts(key,count,reset_at) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=CASE WHEN reset_at<=? THEN 1 ELSE count+1 END,reset_at=CASE WHEN reset_at<=? THEN excluded.reset_at ELSE reset_at END').bind(key,reset,time,time).run();return (await db().prepare('SELECT count FROM password_attempts WHERE key=?').bind(key).first<{count:number}>())!.count;}
async function createSession(account:string,credentialHash:string){const token=randomToken(),expiresAt=new Date(Date.now()+12*3600000).toISOString();const result=await db().prepare("INSERT INTO password_sessions(token_hash,account,credential_hash,expires_at) SELECT ?,id,password_hash,? FROM password_accounts WHERE id=? AND password_hash=? AND status='Active'").bind(await digest(token),expiresAt,account,credentialHash).run();if(!result.meta.changes)throw Error('Credentials changed. Sign in again.');return {token,expiresAt};}
async function session(token:unknown){if(typeof token!=='string'||!/^[a-f0-9]{64}$/.test(token))throw Error('Session expired. Sign in again.');const row=await db().prepare('SELECT a.*,s.expires_at FROM password_sessions s JOIN password_accounts a ON a.id=s.account WHERE s.token_hash=? AND s.expires_at>? AND s.credential_hash=a.password_hash').bind(await digest(token),now()).first<any>();if(!row||row.status!=='Active')throw Error('Session expired or account disabled. Sign in again.');const state=await readWorkspace(row.workspace);if(!state.personnel.some(p=>p.id===row.person&&p.status==='Active'))throw Error('Employee account is not active. Contact Admin.');return {row,state};}
export async function POST(req:Request){const secret=(env as any).JTP_EMPLOYEE_BRIDGE;if(!secret||!secureEqual(req.headers.get('x-jtp-bridge')||'',secret))return privateJson({error:'Forbidden.'},403);
 try{const p:any=await req.json();
  if(p.action==='login'){
   const identifier=normalizeLogin(typeof p.identifier==='string'?p.identifier.slice(0,80):'');const key='login:'+await digest(identifier);const ipKey='ip:'+await digest(String(p.ip||'unknown').slice(0,100));const attempts=await countAttempt(key);const ipAttempts=await countAttempt(ipKey);if(attempts>5||ipAttempts>50)return privateJson({error:'Too many attempts. Try again in 15 minutes.'},429);
   const account=await db().prepare('SELECT * FROM password_accounts WHERE login_id=? OR mobile=? LIMIT 1').bind(identifier,identifier).first<any>();const valid=await verifyPassword(p.password,account?.password_hash||dummyPasswordHash);if(!account||!valid||account.status!=='Active')return privateJson({error:'Incorrect Employee ID/mobile or password.'},401);
   const state=await readWorkspace(account.workspace);if(!state.personnel.some(x=>x.id===account.person&&x.status==='Active'))return privateJson({error:'Incorrect Employee ID/mobile or password.'},401);
   await db().prepare('DELETE FROM password_attempts WHERE key=?').bind(key).run();return privateJson({...await createSession(account.id,account.password_hash),mustChange:!!account.must_change});
  }
  if(p.action==='logout'){if(typeof p.token==='string')await db().prepare('DELETE FROM password_sessions WHERE token_hash=?').bind(await digest(p.token)).run();return privateJson({ok:true});}
  const {row,state}=await session(p.token);
  if(p.action==='changePassword'){
   if(!await verifyPassword(p.currentPassword,row.password_hash))return privateJson({error:'Current password is incorrect.'},400);try{checkPassword(p.newPassword);}catch(e){return privateJson({error:(e as Error).message},400);}if(p.newPassword===p.currentPassword)return privateJson({error:'Choose a different new password.'},400);const hash=await passwordHash(p.newPassword);
   const changed=await db().batch([db().prepare('UPDATE password_accounts SET password_hash=?,must_change=0,updated_at=? WHERE id=? AND password_hash=?').bind(hash,now(),row.id,row.password_hash),db().prepare('DELETE FROM password_sessions WHERE account=? AND credential_hash=?').bind(row.id,row.password_hash)]);if(!changed[0].meta.changes)throw Error('Credentials changed. Sign in again.');
   return privateJson({...await createSession(row.id,hash),ok:true});
  }
  if(row.must_change)return privateJson({mustChange:true,employee:{name:state.personnel.find(x=>x.id===row.person)?.name}},200);
  if(p.action==='applyLeave'){
   try{
    const current=await db().prepare('SELECT revision, data FROM workspaces WHERE id = ?').bind(row.workspace).first<{revision:number,data:string}>();if(!current)throw Error('Workspace unavailable.');
    const next=employeeLeaveRequest(JSON.parse(current.data),row.person,{policy:p.policy,from:p.from,to:p.to,reason:p.reason});const data=JSON.stringify(next);if(data.length>1500000)throw Error('Workspace limit reached. Contact Admin.');
    const results=await db().batch([
     db().prepare('INSERT INTO workspaces(id,revision,data) VALUES(?,1,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data,revision=workspaces.revision+1 WHERE workspaces.revision=?').bind(row.workspace,data,current.revision),
     db().prepare('INSERT INTO audit(id,workspace,action,details,created_at) SELECT ?,?,?,?,? WHERE EXISTS (SELECT 1 FROM workspaces WHERE id=? AND revision=? AND data=?)').bind(crypto.randomUUID(),row.workspace,'employeeLeaveRequest',JSON.stringify({person:row.person,from:p.from,to:p.to}),now(),row.workspace,current.revision+1,data)
    ]);
    if(!results[0].meta.changes)return privateJson({error:'Another change was saved. Please submit again.'},409);
    return privateJson({ok:true});
   }catch(e){return privateJson({error:(e as Error).message},400)}
  }
  if(p.action==='data')return privateJson(ownEmployeeData(state,row.person,p.month||today().slice(0,7),today()));
  throw Error('Invalid action.');
 }catch(e){return privateJson({error:(e as Error).message},401);}}
