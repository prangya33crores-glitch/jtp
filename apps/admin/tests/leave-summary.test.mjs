import {test} from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
registerHooks({resolve(s,c,next){try{return next(s,c)}catch(e){if(e.code==='ERR_MODULE_NOT_FOUND'&&s.startsWith('.'))return next(s+'.ts',c);throw e}}});
const {employeeLeaveSummary}=await import('../lib/password-auth.ts');
const {initial}=await import('../lib/engine.ts');
test('leave summary isolates employees, splits periods and counts approval only against balance',()=>{
 const s=initial();s.policies=[{id:'annual',name:'Annual',frequency:'Annual',status:'Active',entitlement:12},{id:'monthly',name:'Monthly',frequency:'Monthly',status:'Active',entitlement:2},{id:'off',status:'Inactive',entitlement:100}];
 s.leaves=[{person:'self',policy:'annual',from:'2025-12-31',to:'2026-01-02',status:'Approved'},{person:'self',policy:'annual',from:'2026-11-01',to:'2026-11-01',half:true,status:'Approved'},{person:'self',policy:'annual',from:'2026-11-10',to:'2026-11-11',status:'Pending'},{person:'other',policy:'annual',from:'2026-11-01',to:'2026-11-12',status:'Approved'},{person:'self',policy:'monthly',from:'2026-10-31',to:'2026-11-01',status:'Approved'},{person:'self',policy:'annual',from:'2026-11-20',to:'2026-11-21',status:'Rejected'}];
 let r=employeeLeaveSummary(s,'self','2026-11-05');assert.equal(r.entitlement,14);assert.equal(r.approved,3.5);assert.equal(r.pending,2);assert.equal(r.remaining,10.5);
 s.leaves[2].status='Approved';r=employeeLeaveSummary(s,'self','2026-11-05');assert.equal(r.approved,5.5);assert.equal(r.pending,0);assert.equal(r.remaining,8.5);
 s.leaves[2].status='Cancelled';assert.equal(employeeLeaveSummary(s,'self','2026-11-05').remaining,10.5);
 assert.equal(employeeLeaveSummary(initial(),'self','2026-11-05').entitlement,0);
});
