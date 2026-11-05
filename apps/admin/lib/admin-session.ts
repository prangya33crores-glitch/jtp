import {env} from 'cloudflare:workers';
import {secureEqual} from './password-auth';
export const adminCookie='__Host-jtp_admin';
const encoder=new TextEncoder();
const hex=(data:ArrayBuffer)=>Array.from(new Uint8Array(data),b=>b.toString(16).padStart(2,'0')).join('');
function configuration(){return env as unknown as Record<string,string>}
async function signature(payload:string){const e=configuration();if(!e.JTP_ADMIN_SESSION_SECRET||!e.JTP_ADMIN_PASSWORD_HASH)throw Error('Admin sign-in is not configured.');const key=await crypto.subtle.importKey('raw',encoder.encode(e.JTP_ADMIN_SESSION_SECRET),{name:'HMAC',hash:'SHA-256'},false,['sign']);return hex(await crypto.subtle.sign('HMAC',key,encoder.encode(payload+'|'+e.JTP_ADMIN_PASSWORD_HASH)));}
export async function createAdminSession(){const payload=String(Date.now()+8*3600000)+'.'+crypto.randomUUID();return payload+'.'+await signature(payload)}
export async function validAdminSession(headers:Headers){try{const cookies=(headers.get('cookie')||'').split(';').map(x=>x.trim()).filter(x=>x.startsWith(adminCookie+'='));if(cookies.length!==1)return false;const value=cookies[0].slice(adminCookie.length+1);if(!/^\d{13}\.[a-f0-9-]{36}\.[a-f0-9]{64}$/.test(value))return false;const [expires,nonce,sig]=value.split('.');if(Number(expires)<=Date.now()||Number(expires)>Date.now()+8*3600000)return false;return secureEqual(sig,await signature(expires+'.'+nonce))}catch{return false}}
export function sessionCookie(value:string){return `${adminCookie}=${value}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=${value?28800:0}`}
