import {employeeSchedule,type State,type Row} from './engine';
export type Access = {workspace:string;person:string;user_id:string|null;status:string;expires_at?:string|null;code_hash?:string|null};
export function isAdmin(userId:string|null,adminId:string|null){return !!userId&&!!adminId&&userId===adminId;}
export function authorizeEmployee(access:Access|null,userId:string|null,s:State){
 if(!userId||!access||access.user_id!==userId||access.status!=='Active')throw Error('Employee access is not active. Contact Super Admin.');
 const p=s.personnel.find(p=>p.id===access.person);if(!p||p.status!=='Active')throw Error('Employee access is not active. Contact Super Admin.');return p;
}
export function employeePortalData(access:Access|null,userId:string|null,s:State,month:string,today:string){
 const p=authorizeEmployee(access,userId,s);
 const current=employeeSchedule(s,p.id,today.slice(0,7));
 return {employee:{id:p.id,code:p.code,name:p.name},month,today:current.filter(r=>r.date===today),schedule:employeeSchedule(s,p.id,month)};
}
export function validClaim(access:Access|null,now:string){return !!access&&access.status==='Active'&&!access.user_id&&!!access.expires_at&&access.expires_at>now;}
export async function hashAccessCode(code:string){const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(code.trim()));return Array.from(new Uint8Array(bytes),x=>x.toString(16).padStart(2,'0')).join('');}
