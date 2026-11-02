import {SupabaseDatabase} from './supabase-db';
import {isAdmin} from './employee-access';
import type {State} from './engine';
export const db=()=>new SupabaseDatabase();
export async function adminId():Promise<string>{
 const configured=await db().prepare("SELECT value FROM portal_settings WHERE key='admin_user_id'").first<{value:string}>();if(configured)return configured.value;
 // Upgrade the existing owner-only app without allowing the first new visitor to become admin.
 const old=await db().prepare('SELECT id FROM workspaces LIMIT 2').all<{id:string}>();
 if(old.results.length!==1)throw Error('Super Admin setup requires exactly one existing owner workspace.');
 await db().prepare("INSERT OR IGNORE INTO portal_settings(key,value) VALUES('admin_user_id',?)").bind(old.results[0].id).run();
 const saved=await db().prepare("SELECT value FROM portal_settings WHERE key='admin_user_id'").first<{value:string}>();if(!saved)throw Error('Super Admin setup unavailable.');return saved.value;
}
export async function requireAdmin(req:Request){const user=req.headers.get('oai-authenticated-user-id');if(!user)throw Error('Sign in required.');const owner=await adminId();if(!isAdmin(user,owner))throw Error('Super Admin access required.');return owner;}
export async function readWorkspace(owner:string):Promise<State>{const row=await db().prepare('SELECT data FROM workspaces WHERE id=?').bind(owner).first<{data:string}>();if(!row)throw Error('Workspace unavailable.');return JSON.parse(row.data);}
export function sameOrigin(req:Request){return !req.headers.get('origin')||req.headers.get('origin')===new URL(req.url).origin;}
export const privateJson=(data:unknown,status=200)=>Response.json(data,{status,headers:{'Cache-Control':'private, no-store'}});
