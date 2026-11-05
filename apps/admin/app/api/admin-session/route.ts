import {env} from 'cloudflare:workers';
import {db,privateJson} from '../../../lib/portal-db';
import {digest,verifyPassword,dummyPasswordHash,secureEqual} from '../../../lib/password-auth';
import {createAdminSession,sessionCookie} from '../../../lib/admin-session';
export const dynamic='force-dynamic';
export async function POST(req:Request){
 if(req.headers.get('origin')!==new URL(req.url).origin)return privateJson({error:'Invalid request origin.'},403);
 try{
  if(Number(req.headers.get('content-length')||0)>2048)return privateJson({error:'Request too large.'},413);
  const text=await req.text();if(text.length>2048)return privateJson({error:'Request too large.'},413);const p=JSON.parse(text);
  if(p.action==='logout')return Response.json({ok:true},{headers:{'Set-Cookie':sessionCookie(''),'Cache-Control':'no-store'}});
  const e=env as unknown as Record<string,string>;if(!e.JTP_ADMIN_PASSWORD_HASH||!e.JTP_ADMIN_SESSION_SECRET||!e.JTP_ADMIN_EMAIL)return privateJson({error:'Admin sign-in is not configured.'},503);
  const email=typeof p.email==='string'?p.email.trim().toLowerCase():'';
  const now=new Date().toISOString(),reset=new Date(Date.now()+15*60000).toISOString();
  for(const scope of ['admin:account','admin:ip:'+await digest(req.headers.get('cf-connecting-ip')||'unknown')]){
   await db().prepare('INSERT INTO password_attempts(key,count,reset_at) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=CASE WHEN reset_at<=? THEN 1 ELSE count+1 END,reset_at=CASE WHEN reset_at<=? THEN excluded.reset_at ELSE reset_at END').bind(scope,reset,now,now).run();
   const attempt=await db().prepare('SELECT count FROM password_attempts WHERE key=?').bind(scope).first<{count:number}>();if((attempt?.count||0)>(scope==='admin:account'?10:20))return privateJson({error:'Too many attempts. Try again in 15 minutes.'},429);
  }
  const valid=await verifyPassword(p.password,e.JTP_ADMIN_PASSWORD_HASH||dummyPasswordHash);
  if(!secureEqual(email,e.JTP_ADMIN_EMAIL.toLowerCase())||!valid)return privateJson({error:'Incorrect email or password.'},401);
  await db().prepare('DELETE FROM password_attempts WHERE key=?').bind('admin:account').run();
  return Response.json({ok:true},{headers:{'Set-Cookie':sessionCookie(await createAdminSession()),'Cache-Control':'no-store'}});
 }catch{return privateJson({error:'Unable to sign in. Please try again.'},400)}
}
